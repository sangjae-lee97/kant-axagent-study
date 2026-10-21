"""Shared loading, connection, manifest, and DataFrame validation for Chapter 14."""

from __future__ import annotations

import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import URL, create_engine, text
from sqlalchemy.engine import Connection, Engine

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CSV_PATH = SCRIPT_DIR.parent / "data" / "enrollment_analysis_dataset.csv"
DEFAULT_MANIFEST_PATH = (
    SCRIPT_DIR.parent / "data" / "enrollment_analysis_dataset.manifest.json"
)
DEFAULT_REFERENCE_PATH = SCRIPT_DIR / "reference_metrics.json"

EXPECTED_DATABASE = "ai_database_book"
SOURCE_VIEW = "analysis_lab.enrollment_analysis_dataset"
ANALYSIS_START_DATE = pd.Timestamp("2026-01-01")
ANALYSIS_END_DATE_EXCLUSIVE = pd.Timestamp("2026-07-01")
EXPECTED_ROWS = 24
EXPECTED_RECORDED_AMOUNT_SUM = 3210000
AMOUNT_SEMANTICS = (
    "recorded_amount = enrollment-time recorded amount; cancellation does not zero it"
)

EXPECTED_COLUMNS = [
    "enrollment_id",
    "student_id",
    "student_name",
    "region",
    "course_id",
    "course_title",
    "category",
    "level",
    "instructor_id",
    "instructor_name",
    "enrolled_at",
    "enrollment_month",
    "status",
    "recorded_amount",
    "completed_at",
    "completion_days",
    "is_completed",
]
DATE_COLUMNS = ["enrolled_at", "enrollment_month", "completed_at"]
ID_COLUMNS = ["enrollment_id", "student_id", "course_id", "instructor_id"]
ALLOWED_STATUSES = {"신청", "수강중", "완료", "취소"}


def create_read_only_engine() -> Engine:
    """Create a PostgreSQL engine from libpq-style environment variables."""
    load_dotenv(SCRIPT_DIR / ".env")

    host = os.getenv("PGHOST", "localhost")
    port_text = os.getenv("PGPORT", "5432")
    database = os.getenv("PGDATABASE")
    user = os.getenv("PGUSER")
    passfile = os.getenv("PGPASSFILE")

    if not database or not user:
        raise RuntimeError(
            "PGDATABASE와 PGUSER가 필요합니다. python/.env.example을 참고해 "
            "개발·테스트 DB 정보를 설정하세요."
        )
    if database != EXPECTED_DATABASE:
        raise RuntimeError(
            f"Chapter 14 연결 DB는 {EXPECTED_DATABASE!r}여야 합니다. "
            f"현재 설정은 {database!r}입니다."
        )

    try:
        port = int(port_text)
    except ValueError as exc:
        raise RuntimeError(f"PGPORT는 정수여야 합니다: {port_text!r}") from exc

    if passfile:
        passfile_path = Path(passfile).expanduser().resolve()
        if not passfile_path.exists():
            raise RuntimeError(f"PGPASSFILE을 찾을 수 없습니다: {passfile_path}")
        os.environ["PGPASSFILE"] = str(passfile_path)

    url = URL.create(
        "postgresql+psycopg",
        username=user,
        host=host,
        port=port,
        database=database,
    )

    return create_engine(
        url,
        pool_pre_ping=True,
        connect_args={"options": "-c default_transaction_read_only=on"},
    )


def validate_connection(connection: Connection) -> dict[str, str]:
    """Validate database identity, read-only mode, and source VIEW existence."""
    row = connection.execute(
        text(
            """
            SELECT
                current_database() AS database_name,
                current_user AS user_name,
                current_setting('transaction_read_only') AS read_only,
                to_regclass('analysis_lab.enrollment_analysis_dataset')::text
                    AS source_view
            """
        )
    ).mappings().one()

    if row["database_name"] != EXPECTED_DATABASE:
        raise RuntimeError(
            f"잘못된 DB에 연결했습니다: {row['database_name']!r}"
        )
    if row["read_only"] != "on":
        raise RuntimeError("분석 연결이 읽기 전용이 아닙니다.")
    if row["source_view"] != SOURCE_VIEW:
        raise RuntimeError(f"분석 VIEW가 없습니다: {SOURCE_VIEW}")

    return {
        "source_database": row["database_name"],
        "source_user": row["user_name"],
        "source_view": row["source_view"],
        "transaction_read_only": row["read_only"],
    }


def _normalize_boolean(series: pd.Series) -> pd.Series:
    if pd.api.types.is_bool_dtype(series):
        return series.astype(bool)

    normalized = series.astype("string").str.strip().str.lower()
    allowed = {"true", "false"}
    invalid = sorted(set(normalized.dropna()) - allowed)
    if invalid:
        raise ValueError(f"is_completed에 boolean이 아닌 값이 있습니다: {invalid}")
    if normalized.isna().any():
        raise ValueError("is_completed에는 NULL을 허용하지 않습니다.")
    return normalized.map({"true": True, "false": False}).astype(bool)


def validate_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """Validate exact columns, grain, types, period, and business consistency."""
    actual_columns = list(df.columns)
    if set(actual_columns) != set(EXPECTED_COLUMNS):
        missing = sorted(set(EXPECTED_COLUMNS) - set(actual_columns))
        unexpected = sorted(set(actual_columns) - set(EXPECTED_COLUMNS))
        raise ValueError(
            "분석 데이터셋 컬럼이 일치하지 않습니다. "
            f"missing={missing}, unexpected={unexpected}"
        )

    normalized = df.loc[:, EXPECTED_COLUMNS].copy()

    if len(normalized) != EXPECTED_ROWS:
        raise ValueError(
            f"기대 행 수는 {EXPECTED_ROWS}이지만 실제는 {len(normalized)}입니다."
        )

    if normalized["enrollment_id"].isna().any():
        raise ValueError("enrollment_id에 NULL이 있습니다.")
    duplicated_ids = normalized.loc[
        normalized["enrollment_id"].duplicated(keep=False),
        "enrollment_id",
    ].tolist()
    if duplicated_ids:
        raise ValueError(f"중복 enrollment_id가 있습니다: {duplicated_ids}")

    for column in ID_COLUMNS:
        values = pd.to_numeric(normalized[column], errors="raise")
        if values.isna().any() or ((values % 1) != 0).any():
            raise ValueError(f"{column}은 NULL 없는 정수여야 합니다.")
        normalized[column] = values.astype("int64")

    for column in DATE_COLUMNS:
        normalized[column] = pd.to_datetime(
            normalized[column],
            errors="raise",
        )

    normalized["recorded_amount"] = pd.to_numeric(
        normalized["recorded_amount"],
        errors="raise",
    )
    if normalized["recorded_amount"].isna().any():
        raise ValueError("recorded_amount에 NULL이 있습니다.")
    if ((normalized["recorded_amount"] % 1) != 0).any():
        raise ValueError("recorded_amount는 정수 단위 금액이어야 합니다.")
    normalized["recorded_amount"] = normalized["recorded_amount"].astype("int64")
    normalized["completion_days"] = pd.to_numeric(
        normalized["completion_days"],
        errors="raise",
    )
    normalized["is_completed"] = _normalize_boolean(
        normalized["is_completed"]
    )

    if (normalized["recorded_amount"] < 0).any():
        raise ValueError("recorded_amount에 음수가 있습니다.")

    statuses = set(normalized["status"].dropna())
    if normalized["status"].isna().any() or not statuses <= ALLOWED_STATUSES:
        raise ValueError(f"허용되지 않은 status가 있습니다: {sorted(statuses)}")

    expected_completed = normalized["status"].eq("완료")
    if not normalized["is_completed"].equals(expected_completed):
        raise ValueError("status와 is_completed가 일치하지 않습니다.")

    if normalized.loc[expected_completed, "completed_at"].isna().any():
        raise ValueError("완료 상태인데 completed_at이 NULL인 행이 있습니다.")
    if normalized.loc[~expected_completed, "completed_at"].notna().any():
        raise ValueError("완료가 아닌데 completed_at이 존재하는 행이 있습니다.")
    if normalized.loc[expected_completed, "completion_days"].isna().any():
        raise ValueError("완료 상태인데 completion_days가 NULL인 행이 있습니다.")
    if normalized.loc[~expected_completed, "completion_days"].notna().any():
        raise ValueError("완료가 아닌데 completion_days가 존재하는 행이 있습니다.")
    if (normalized.loc[expected_completed, "completion_days"] < 0).any():
        raise ValueError("completion_days에 음수가 있습니다.")

    actual_completion_days = (normalized.loc[expected_completed, "completed_at"] - normalized.loc[expected_completed, "enrolled_at"]).dt.days.astype(float)
    stored_completion_days = normalized.loc[expected_completed, "completion_days"].astype(float)
    if not stored_completion_days.equals(actual_completion_days):
        raise ValueError("completion_days가 completed_at - enrolled_at과 일치하지 않습니다.")

    outside_period = (
        (normalized["enrolled_at"] < ANALYSIS_START_DATE)
        | (normalized["enrolled_at"] >= ANALYSIS_END_DATE_EXCLUSIVE)
    )
    if outside_period.any():
        ids = normalized.loc[outside_period, "enrollment_id"].tolist()
        raise ValueError(f"분석 기간 밖 enrollment_id가 있습니다: {ids}")

    expected_month = normalized["enrolled_at"].dt.to_period("M").dt.to_timestamp()
    if not normalized["enrollment_month"].equals(expected_month):
        raise ValueError("enrollment_month가 enrolled_at에서 파생된 월과 다릅니다.")

    return normalized


def load_csv_dataset(csv_path: Path) -> pd.DataFrame:
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV 파일을 찾을 수 없습니다: {csv_path.resolve()}")
    return validate_dataframe(pd.read_csv(csv_path))


def load_postgresql_dataset(connection: Connection) -> pd.DataFrame:
    query = text(
        """
        SELECT *
        FROM analysis_lab.enrollment_analysis_dataset
        ORDER BY enrollment_id
        """
    )
    return validate_dataframe(pd.read_sql_query(query, connection))


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file_obj:
        for chunk in iter(lambda: file_obj.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_manifest(
    manifest_path: Path,
    csv_path: Path,
    connection_info: dict[str, str],
    row_count: int,
) -> dict[str, Any]:
    manifest = {
        **connection_info,
        "analysis_start_date": ANALYSIS_START_DATE.date().isoformat(),
        "analysis_end_date_exclusive": (
            ANALYSIS_END_DATE_EXCLUSIVE.date().isoformat()
        ),
        "row_count": row_count,
        "expected_recorded_amount_sum": EXPECTED_RECORDED_AMOUNT_SUM,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "csv_path": str(csv_path.resolve()),
        "sha256": file_sha256(csv_path),
        "amount_semantics": AMOUNT_SEMANTICS,
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return manifest


def load_and_validate_manifest(
    manifest_path: Path,
    csv_path: Path,
) -> dict[str, Any]:
    if not manifest_path.exists():
        raise FileNotFoundError(
            "CSV 최종 검증에는 manifest가 필요합니다: "
            f"{manifest_path.resolve()}"
        )
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    expected_pairs = {
        "source_database": EXPECTED_DATABASE,
        "source_view": SOURCE_VIEW,
        "analysis_start_date": ANALYSIS_START_DATE.date().isoformat(),
        "analysis_end_date_exclusive": (
            ANALYSIS_END_DATE_EXCLUSIVE.date().isoformat()
        ),
        "row_count": EXPECTED_ROWS,
        "expected_recorded_amount_sum": EXPECTED_RECORDED_AMOUNT_SUM,
        "amount_semantics": AMOUNT_SEMANTICS,
    }
    for key, expected in expected_pairs.items():
        if manifest.get(key) != expected:
            raise ValueError(
                f"manifest {key} 불일치: "
                f"expected={expected!r}, actual={manifest.get(key)!r}"
            )

    actual_hash = file_sha256(csv_path)
    if manifest.get("sha256") != actual_hash:
        raise ValueError(
            "CSV SHA-256이 manifest와 다릅니다. "
            f"expected={manifest.get('sha256')}, actual={actual_hash}"
        )
    return manifest


def load_reference_metrics(path: Path = DEFAULT_REFERENCE_PATH) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(f"SQL 기준값 파일이 없습니다: {path.resolve()}")
    return json.loads(path.read_text(encoding="utf-8"))