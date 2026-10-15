
import json
import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parents[1]
REPORTS_DIR = BASE_DIR / "reports"

load_dotenv(BASE_DIR / ".env")



def build_prompt(summary):
    data_dir = BASE_DIR / "data" / "processed"

    naver = pd.read_csv(data_dir / "naver_trend.csv")
    stay = pd.read_csv(data_dir / "tourism_stay.csv")
    consumption = pd.read_csv(
        data_dir / "tourism_consumption.csv"
    )

    naver_periods = pd.to_datetime(naver["period"])

    context = {
        "naver_start_month": naver_periods.min().strftime("%Y-%m"),
        "naver_end_month": naver_periods.max().strftime("%Y-%m"),
        "tourism_stay_months": sorted(
            stay["baseYm"].astype(str).unique().tolist()
        ),
        "tourism_consumption_months": sorted(
            consumption["baseYm"].astype(str).unique().tolist()
        ),
        "stay_district_count": int(stay["signguCd"].nunique()),
        "consumption_district_count": int(
            consumption["signguCd"].nunique()
        ),
        "ranking_display_count": 10,
    }

    # 진행 중인 월이 포함되었는지 검증
    current_month = pd.Timestamp.today().strftime("%Y-%m")

    if context["naver_end_month"] >= current_month:
        raise ValueError(
            "NAVER 데이터에 진행 중인 월이 포함되어 있습니다."
        )

    return f"""
당신은 관광 데이터 분석 보고서 작성 보조자입니다.

아래 데이터는 Python에서 계산하고 검증한 분석 결과입니다.

[전체 데이터 분석 범위]
{json.dumps(context, ensure_ascii=False, indent=2)}

[분석 결과]
{json.dumps(summary, ensure_ascii=False, indent=2)}

다음 형식으로 한국어 Markdown 보고서를 작성하세요.

1. 분석 기준일 및 데이터 기간
2. NAVER 검색 관심도 주요 변화
3. 지역 관광 수요 주요 특징
4. 관찰 가능한 패턴
5. 현재 데이터로 말할 수 없는 것
6. 추가 확인이 필요한 사항

[필수 해석 규칙]

1. NAVER ratio는 실제 검색 건수가 아닌 상대지수입니다.
2. change_points는 백분율이 아니라 상대지수의 차이입니다.
3. NAVER 데이터는 완료된 월까지만 분석했습니다.
4. 관광 데이터는 서울 25개 자치구 전체를 분석했습니다.
5. 보고서에는 각 관광 지표의 상위 10개 지역만 표시합니다.
6. 상위 10개 지역 중 10위를 서울 전체 최하위로 해석하지 마세요.
7. 이미 확보한 서울 25개 자치구 데이터를 추가로 수집해야
   한다고 제안하지 마세요.
8. NAVER와 관광 데이터의 기준 기간 차이를 명시하세요.
9. 서로 다른 기간의 데이터를 이용해 상관관계나
   인과관계를 단정하지 마세요.
10. 관광 지표값을 실제 소비 금액이나 방문객 수로
    임의 변환하지 마세요.
11. 지표 단위와 산정 방식을 추측하지 마세요.
12. 입력 데이터에 없는 숫자나 사실을 만들지 마세요.
13. 관찰된 사실과 해석 및 분석 한계를 구분하세요.
14. 추가 확인 사항에는 아직 해결되지 않은 문제만 제시하세요.
15. Markdown 표를 사용하지 마세요.
    모든 분석 결과는 제목과 목록 형태로 작성하세요.

위 조건을 지키면서 간결하고 정확한 보고서를 작성하세요.
"""



def call_gemini(prompt):
    from google import genai

    api_key = os.getenv("LLM_API_KEY")
    model = os.getenv("LLM_MODEL")

    if not api_key or not model:
        raise RuntimeError("Gemini API 설정이 없습니다.")

    
    from google.genai import types

    client = genai.Client(
        api_key=api_key,
        http_options=types.HttpOptions(
            timeout=60000,
            retry_options=types.HttpRetryOptions(attempts=1),
        ),
    )


    response = client.models.generate_content(
        model=model,
        contents=prompt,
    )

    if not response.text:
        raise RuntimeError("Gemini 응답이 비어 있습니다.")

    return response.text


def generate_report(summary):
    provider = os.getenv("LLM_PROVIDER", "").lower()

    if provider != "gemini":
        raise RuntimeError("현재 실습은 Gemini 기준입니다.")

    prompt = build_prompt(summary)
    report_text = call_gemini(prompt)

    output_path = REPORTS_DIR / "llm_summary.md"
    output_path.write_text(
        report_text,
        encoding="utf-8",
    )

    print("[PASS] Gemini Report Generated")
    print("Saved:", output_path)

    return report_text


def main():
    summary_path = REPORTS_DIR / "analysis_summary.csv"

    if not summary_path.exists():
        raise FileNotFoundError(
            "analysis_summary.csv 파일이 없습니다."
        )

    df = pd.read_csv(summary_path, dtype={"period": str})

    required = ["source", "metric", "period", "item", "value"]

    if df.empty or df[required].isna().any().any():
        raise ValueError("분석 요약 데이터가 비어 있거나 결측값이 있습니다.")

    if len(df) != 28:
        raise ValueError("분석 요약 행 수가 예상과 다릅니다.")

    df["value"] = pd.to_numeric(
        df["value"], errors="raise"
    )

    summary = df.to_dict(orient="records")

    generate_report(summary)


if __name__ == "__main__":
    main()
