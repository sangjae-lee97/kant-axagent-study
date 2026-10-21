"""Chapter 14: PostgreSQL 분석 VIEW를 읽기 전용 연결로 pandas에 적재합니다."""

from __future__ import annotations

import argparse
from pathlib import Path

from validation_utils import (
    DEFAULT_MANIFEST_PATH,
    create_read_only_engine,
    load_postgresql_dataset,
    validate_connection,
    write_manifest,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="PostgreSQL의 Chapter 14 분석 VIEW를 읽고 선택적으로 CSV·manifest를 저장합니다."
    )
    parser.add_argument(
        "--export-csv",
        type=Path,
        default=None,
        help="읽은 DataFrame을 저장할 CSV 경로. 생략하면 저장하지 않습니다.",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_MANIFEST_PATH,
        help=f"CSV와 함께 저장할 manifest 경로. 기본값: {DEFAULT_MANIFEST_PATH}",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    engine = create_read_only_engine()

    try:
        with engine.connect() as connection:
            connection_info = validate_connection(connection)
            df = load_postgresql_dataset(connection)
    finally:
        engine.dispose()

    print("\n[연결 확인]")
    for key, value in connection_info.items():
        print(f"{key}: {value}")

    print("\n[앞 5행]")
    print(df.head().to_string(index=False))

    print("\n[검증 결과]")
    print(f"행 수: {len(df)}")
    print(f"고유 enrollment_id: {df['enrollment_id'].nunique()}")
    print(f"신청 시점 기록 금액 합계: {int(df['recorded_amount'].sum()):,}")

    if args.export_csv is not None:
        export_path = args.export_csv.resolve()
        export_path.parent.mkdir(parents=True, exist_ok=True)
        df.to_csv(export_path, index=False, encoding="utf-8-sig")
        manifest = write_manifest(
            args.manifest.resolve(),
            export_path,
            connection_info,
            len(df),
        )
        print(f"CSV 저장: {export_path}")
        print(f"manifest 저장: {args.manifest.resolve()}")
        print(f"CSV SHA-256: {manifest['sha256']}")
    else:
        print("CSV·manifest 저장은 생략했습니다.")

    print("PostgreSQL 읽기 전용 기본 검증을 통과했습니다.")


if __name__ == "__main__":
    main()