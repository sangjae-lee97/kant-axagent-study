"""Chapter 14: DBeaver 또는 DB export CSV를 엄격하게 읽고 검증합니다."""

from __future__ import annotations

import argparse
from pathlib import Path

from validation_utils import (
    DEFAULT_CSV_PATH,
    DEFAULT_MANIFEST_PATH,
    load_and_validate_manifest,
    load_csv_dataset,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Chapter 14 분석 CSV의 컬럼, 행 단위, 자료형과 manifest를 확인합니다."
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
        help=f"manifest 경로. 기본값: {DEFAULT_MANIFEST_PATH}",
    )
    parser.add_argument(
        "--require-manifest",
        action="store_true",
        help="manifest가 없으면 경고가 아니라 오류로 중단합니다.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    df = load_csv_dataset(args.csv)

    print("\n[앞 5행]")
    print(df.head().to_string(index=False))

    print("\n[자료형]")
    print(df.dtypes)

    print("\n[기본 검증]")
    print(f"행 수: {len(df)}")
    print(f"고유 enrollment_id: {df['enrollment_id'].nunique()}")
    print(f"신청 시점 기록 금액 합계: {int(df['recorded_amount'].sum()):,}")

    if args.manifest.exists():
        manifest = load_and_validate_manifest(args.manifest, args.csv)
        print("\n[manifest]")
        print(f"source_database: {manifest['source_database']}")
        print(f"source_view: {manifest['source_view']}")
        print(f"generated_at_utc: {manifest.get('generated_at_utc')}")
        print(f"sha256: {manifest['sha256']}")
        print("CSV와 manifest 검증을 통과했습니다.")
    elif args.require_manifest:
        raise FileNotFoundError(
            f"최종 검증에 필요한 manifest가 없습니다: {args.manifest.resolve()}"
        )
    else:
        print(
            "\n[경고] manifest가 없어 출처·생성 시점·SHA-256은 확인하지 않았습니다. "
            "최종 검증에서는 --require-manifest를 사용하세요."
        )

    print("CSV 데이터셋 구조 검증을 통과했습니다.")


if __name__ == "__main__":
    main()