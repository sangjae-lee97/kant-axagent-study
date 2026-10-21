"""Chapter 14: 실제 SQL 집계와 pandas 집계를 구조적으로 교차 검증합니다."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import pandas as pd
from pandas.testing import assert_frame_equal
from sqlalchemy import text

from validation_utils import (
    ANALYSIS_END_DATE_EXCLUSIVE,
    ANALYSIS_START_DATE,
    DEFAULT_CSV_PATH,
    DEFAULT_MANIFEST_PATH,
    DEFAULT_REFERENCE_PATH,
    create_read_only_engine,
    load_and_validate_manifest,
    load_csv_dataset,
    load_postgresql_dataset,
    load_reference_metrics,
    validate_connection,
)

STATUS_ORDER = ["신청", "수강중", "완료", "취소"]

SQL_STATUS_QUERY = text(
    """
    SELECT status, COUNT(*)::bigint AS enrollment_count
    FROM analysis_lab.enrollment_analysis_dataset
    GROUP BY status
    ORDER BY CASE status
        WHEN '신청' THEN 1
        WHEN '수강중' THEN 2
        WHEN '완료' THEN 3
        WHEN '취소' THEN 4
        ELSE 99
    END
    """
)

SQL_MONTHLY_QUERY = text(
    """
    WITH parameters AS (
        SELECT start_date, end_date_exclusive
        FROM analysis_lab.analysis_parameters
    ),
    months AS (
        SELECT generate_series(
            p.start_date,
            p.end_date_exclusive - INTERVAL '1 month',
            INTERVAL '1 month'
        )::date AS enrollment_month
        FROM parameters AS p
    ),
    actual AS (
        SELECT
            enrollment_month,
            COUNT(*)::bigint AS enrollment_count,
            SUM(recorded_amount)::bigint AS recorded_amount_sum
        FROM analysis_lab.enrollment_analysis_dataset
        GROUP BY enrollment_month
    )
    SELECT
        m.enrollment_month,
        COALESCE(a.enrollment_count, 0)::bigint AS enrollment_count,
        COALESCE(a.recorded_amount_sum, 0)::bigint AS recorded_amount_sum
    FROM months AS m
    LEFT JOIN actual AS a
        ON a.enrollment_month = m.enrollment_month
    ORDER BY m.enrollment_month
    """
)

SQL_COMPLETION_QUERY = text(
    """
    SELECT
        COUNT(*)::bigint AS completed_count,
        ROUND(AVG(completion_days), 2) AS avg_completion_days,
        MIN(completion_days)::bigint AS min_completion_days,
        MAX(completion_days)::bigint AS max_completion_days
    FROM analysis_lab.enrollment_analysis_dataset
    WHERE is_completed
    """
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Chapter 14의 실제 SQL 집계와 pandas 결과를 비교합니다."
    )
    parser.add_argument(
        "--source",
        choices=("csv", "postgresql"),
        default="csv",
        help="데이터 원본. PostgreSQL은 같은 스냅샷의 SQL과 pandas를 직접 비교합니다.",
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=DEFAULT_CSV_PATH,
        help=f"CSV 경로. 기본값: {DEFAULT_CSV_PATH}",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_MANIFEST_PATH,
        help=f"CSV manifest 경로. 기본값: {DEFAULT_MANIFEST_PATH}",
    )
    parser.add_argument(
        "--reference",
        type=Path,
        default=DEFAULT_REFERENCE_PATH,
        help=f"CSV 경로용 SQL 기준값 JSON. 기본값: {DEFAULT_REFERENCE_PATH}",
    )
    return parser.parse_args()


def build_pandas_status(df: pd.DataFrame) -> pd.DataFrame:
    result = (
        df.groupby("status", as_index=False)
        .agg(enrollment_count=("enrollment_id", "count"))
    )
    result["status"] = pd.Categorical(
        result["status"],
        categories=STATUS_ORDER,
        ordered=True,
    )
    return (
        result.sort_values("status")
        .assign(status=lambda frame: frame["status"].astype("string"))
        .reset_index(drop=True)
    )


def build_pandas_monthly(df: pd.DataFrame) -> pd.DataFrame:
    months = pd.DataFrame(
        {
            "enrollment_month": pd.date_range(
                ANALYSIS_START_DATE,
                ANALYSIS_END_DATE_EXCLUSIVE,
                freq="MS",
                inclusive="left",
            )
        }
    )
    actual = (
        df.groupby("enrollment_month", as_index=False)
        .agg(
            enrollment_count=("enrollment_id", "count"),
            recorded_amount_sum=("recorded_amount", "sum"),
        )
    )
    return (
        months.merge(actual, on="enrollment_month", how="left")
        .fillna({"enrollment_count": 0, "recorded_amount_sum": 0})
        .astype(
            {
                "enrollment_count": "int64",
                "recorded_amount_sum": "int64",
            }
        )
        .sort_values("enrollment_month")
        .reset_index(drop=True)
    )


def build_pandas_completion(df: pd.DataFrame) -> pd.DataFrame:
    completed = df.loc[df["is_completed"], "completion_days"]
    return pd.DataFrame(
        [
            {
                "completed_count": int(completed.count()),
                "avg_completion_days": round(float(completed.mean()), 2),
                "min_completion_days": int(completed.min()),
                "max_completion_days": int(completed.max()),
            }
        ]
    )


def reference_frames(metrics: dict[str, Any]) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    status = pd.DataFrame(
        [
            {"status": status_name, "enrollment_count": metrics["status_counts"][status_name]}
            for status_name in STATUS_ORDER
        ]
    )
    monthly = pd.DataFrame(metrics["monthly"])
    monthly["enrollment_month"] = pd.to_datetime(monthly["enrollment_month"])
    completion = pd.DataFrame([metrics["completion"]])
    return status, monthly, completion


def normalize_sql_frames(
    status: pd.DataFrame,
    monthly: pd.DataFrame,
    completion: pd.DataFrame,
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    status["status"] = status["status"].astype("string")
    status["enrollment_count"] = status["enrollment_count"].astype("int64")
    monthly["enrollment_month"] = pd.to_datetime(monthly["enrollment_month"])
    monthly[["enrollment_count", "recorded_amount_sum"]] = monthly[
        ["enrollment_count", "recorded_amount_sum"]
    ].astype("int64")
    completion[
        ["completed_count", "min_completion_days", "max_completion_days"]
    ] = completion[
        ["completed_count", "min_completion_days", "max_completion_days"]
    ].astype("int64")
    completion["avg_completion_days"] = completion[
        "avg_completion_days"
    ].astype(float)
    return status, monthly, completion


def compare_frames(
    pandas_status: pd.DataFrame,
    pandas_monthly: pd.DataFrame,
    pandas_completion: pd.DataFrame,
    reference_status: pd.DataFrame,
    reference_monthly: pd.DataFrame,
    reference_completion: pd.DataFrame,
) -> None:
    assert_frame_equal(
        pandas_status,
        reference_status,
        check_dtype=False,
        obj="상태별 SQL·pandas 결과",
    )
    print("[통과] 상태별 SQL·pandas 결과")

    assert_frame_equal(
        pandas_monthly,
        reference_monthly,
        check_dtype=False,
        obj="월별 SQL·pandas 결과",
    )
    print("[통과] 월별 SQL·pandas 결과")

    assert_frame_equal(
        pandas_completion,
        reference_completion,
        check_dtype=False,
        obj="완료 기간 SQL·pandas 결과",
    )
    print("[통과] 완료 기간 SQL·pandas 결과")


def main() -> None:
    args = parse_args()

    if args.source == "postgresql":
        engine = create_read_only_engine()
        try:
            with engine.connect() as connection:
                with connection.begin():
                    connection.exec_driver_sql(
                        "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY"
                    )
                    validate_connection(connection)
                    df = load_postgresql_dataset(connection)
                    sql_status = pd.read_sql_query(SQL_STATUS_QUERY, connection)
                    sql_monthly = pd.read_sql_query(SQL_MONTHLY_QUERY, connection)
                    sql_completion = pd.read_sql_query(
                        SQL_COMPLETION_QUERY,
                        connection,
                    )
        finally:
            engine.dispose()

        reference_status, reference_monthly, reference_completion = (
            normalize_sql_frames(sql_status, sql_monthly, sql_completion)
        )
        reference_label = "같은 읽기 전용 REPEATABLE READ 스냅샷의 실제 SQL"
    else:
        df = load_csv_dataset(args.csv)
        load_and_validate_manifest(args.manifest, args.csv)
        metrics = load_reference_metrics(args.reference)
        reference_status, reference_monthly, reference_completion = (
            reference_frames(metrics)
        )
        reference_label = "버전 관리된 SQL 기준값 JSON과 검증된 CSV manifest"

    pandas_status = build_pandas_status(df)
    pandas_monthly = build_pandas_monthly(df)
    pandas_completion = build_pandas_completion(df)

    compare_frames(
        pandas_status,
        pandas_monthly,
        pandas_completion,
        reference_status,
        reference_monthly,
        reference_completion,
    )

    print(f"\n비교 기준: {reference_label}")
    print("Chapter 14 SQL·Python 교차 검증을 통과했습니다.")


if __name__ == "__main__":
    main()