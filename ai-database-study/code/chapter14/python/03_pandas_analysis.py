"""Chapter 14: SQL 분석 데이터셋을 pandas로 집계하고 시각화합니다."""

from __future__ import annotations

import argparse
import warnings
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.font_manager as font_manager
import matplotlib.pyplot as plt
import pandas as pd

from validation_utils import (
    ANALYSIS_END_DATE_EXCLUSIVE,
    ANALYSIS_START_DATE,
    DEFAULT_CSV_PATH,
    create_read_only_engine,
    load_csv_dataset,
    load_postgresql_dataset,
    validate_connection,
)

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CHART_PATH = SCRIPT_DIR.parent / "output" / "monthly_enrollment_count.png"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Chapter 14 분석 데이터셋을 pandas로 분석합니다."
    )
    parser.add_argument(
        "--source",
        choices=("csv", "postgresql"),
        default="csv",
        help="데이터 원본. 기본값: csv",
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=DEFAULT_CSV_PATH,
        help=f"CSV 경로. 기본값: {DEFAULT_CSV_PATH}",
    )
    parser.add_argument(
        "--chart",
        type=Path,
        default=DEFAULT_CHART_PATH,
        help=f"그래프 저장 경로. 기본값: {DEFAULT_CHART_PATH}",
    )
    return parser.parse_args()


def load_dataframe(source: str, csv_path: Path) -> pd.DataFrame:
    if source == "csv":
        return load_csv_dataset(csv_path)

    engine = create_read_only_engine()
    try:
        with engine.connect() as connection:
            validate_connection(connection)
            return load_postgresql_dataset(connection)
    finally:
        engine.dispose()


def build_status_summary(df: pd.DataFrame) -> pd.DataFrame:
    return (
        df.groupby("status", dropna=False)
        .agg(enrollment_count=("enrollment_id", "count"))
        .sort_values(["enrollment_count", "status"], ascending=[False, True])
        .reset_index()
    )


def build_monthly_summary(df: pd.DataFrame) -> pd.DataFrame:
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


def build_course_summary(df: pd.DataFrame) -> pd.DataFrame:
    return (
        df.groupby(["course_id", "course_title"], as_index=False)
        .agg(
            enrollment_count=("enrollment_id", "count"),
            recorded_amount_sum=("recorded_amount", "sum"),
        )
        .sort_values(["enrollment_count", "course_id"], ascending=[False, True])
    )


def build_course_status_pivot(df: pd.DataFrame) -> pd.DataFrame:
    return pd.pivot_table(
        df,
        index="course_title",
        columns="status",
        values="enrollment_id",
        aggfunc="count",
        fill_value=0,
        margins=True,
    )


def configure_korean_font() -> None:
    preferred_fonts = [
        "Malgun Gothic",
        "AppleGothic",
        "Noto Sans CJK KR",
        "Noto Sans KR",
        "NanumGothic",
    ]
    installed = {font.name for font in font_manager.fontManager.ttflist}
    selected = next((font for font in preferred_fonts if font in installed), None)

    if selected:
        plt.rcParams["font.family"] = selected
        plt.rcParams["axes.unicode_minus"] = False
    else:
        warnings.warn(
            "사용 가능한 한글 글꼴을 찾지 못했습니다. 그래프의 한글이 깨질 수 있습니다.",
            RuntimeWarning,
            stacklevel=2,
        )


def save_monthly_chart(monthly_summary: pd.DataFrame, chart_path: Path) -> None:
    chart_path = chart_path.resolve()
    chart_path.parent.mkdir(parents=True, exist_ok=True)
    configure_korean_font()

    chart_data = monthly_summary.copy()
    chart_data["month_label"] = chart_data["enrollment_month"].dt.strftime(
        "%Y-%m"
    )

    ax = chart_data.plot(
        x="month_label",
        y="enrollment_count",
        kind="line",
        marker="o",
        legend=False,
    )
    ax.set_title("월별 수강신청 건수")
    ax.set_xlabel("월")
    ax.set_ylabel("신청 건수")
    ax.set_ylim(bottom=0)
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(chart_path, dpi=150)
    plt.close()


def main() -> None:
    args = parse_args()
    df = load_dataframe(args.source, args.csv)

    status_summary = build_status_summary(df)
    monthly_summary = build_monthly_summary(df)
    course_summary = build_course_summary(df)
    course_status_pivot = build_course_status_pivot(df)

    print("\n[상태별 신청 건수]")
    print(status_summary.to_string(index=False))

    print("\n[월별 신청 건수와 신청 시점 기록 금액]")
    print(monthly_summary.to_string(index=False))

    print("\n[강의별 신청 건수와 신청 시점 기록 금액]")
    print(course_summary.to_string(index=False))

    print("\n[강의별 상태 피벗]")
    print(course_status_pivot.to_string())

    completed = df.loc[df["status"] == "완료", "completion_days"]
    print("\n[완료된 신청의 완료 기간]")
    print(completed.describe())

    save_monthly_chart(monthly_summary, args.chart)
    print(f"\n그래프 저장: {args.chart.resolve()}")


if __name__ == "__main__":
    main()