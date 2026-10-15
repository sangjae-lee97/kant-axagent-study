
import json
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

BASE_DIR = Path(__file__).resolve().parents[1]
RAW_DIR = BASE_DIR / "data" / "raw"
PROCESSED_DIR = BASE_DIR / "data" / "processed"
REPORTS_DIR = BASE_DIR / "reports"

REPORTS_DIR.mkdir(parents=True, exist_ok=True)

# Windows 한글 폰트
plt.rcParams["font.family"] = "Malgun Gothic"
plt.rcParams["axes.unicode_minus"] = False

summary = []

# 1. NAVER 검색 관심도 분석
naver = pd.read_csv(
    PROCESSED_DIR / "naver_trend.csv",
    parse_dates=["period"],
)

naver["ratio"] = pd.to_numeric(
    naver["ratio"], errors="raise"
)

if naver[["period", "keyword", "ratio"]].isna().any().any():
    raise ValueError("NAVER 데이터에 결측값이 있습니다.")

plt.figure(figsize=(10, 5))

for keyword, group in naver.groupby("keyword"):
    group = group.sort_values("period")

    if len(group) < 2:
        raise ValueError(f"{keyword}: 기간 데이터 부족")

    latest = group.iloc[-1]
    previous = group.iloc[-2]

    change = latest["ratio"] - previous["ratio"]

    summary.extend([
        {
            "source": "NAVER",
            "metric": "latest_ratio",
            "period": latest["period"].strftime("%Y-%m"),
            "item": keyword,
            "value": latest["ratio"],
        },
        {
            "source": "NAVER",
            "metric": "change_points",
            "period": latest["period"].strftime("%Y-%m"),
            "item": keyword,
            "value": change,
        },
    ])

    plt.plot(
        group["period"],
        group["ratio"],
        marker="o",
        label=keyword,
    )

plt.title("NAVER 검색 관심도 추이")
plt.xlabel("기간")
plt.ylabel("상대 검색 관심도")
plt.legend()
plt.tight_layout()
plt.savefig(REPORTS_DIR / "naver_trend.png", dpi=150)
plt.close()

print("[PASS] NAVER Analysis")


# 2. 관광 API 원본 읽기
def load_tourism(kind, value_column):
    files = sorted(RAW_DIR.glob(f"tourism_{kind}_*.json"))

    if not files:
        raise FileNotFoundError(f"{kind} JSON 파일 없음")

    with files[-1].open(encoding="utf-8") as f:
        data = json.load(f)

    response = data["response"]

    if response["header"]["resultCode"] != "0000":
        raise ValueError(f"{kind} API 응답 오류")

    body = response["body"]
    items = body["items"]["item"]

    if len(items) != body["totalCount"]:
        raise ValueError(f"{kind} 일부 데이터만 수집됨")

    df = pd.DataFrame(items)

    # 서울시 전체 집계 행 제외
    df = df[
        (df["signguCd"].astype(str) != "0")
        & (df["signguNm"] != "_")
    ].copy()

    df["value"] = pd.to_numeric(
        df[value_column], errors="raise"
    )

    if df["value"].isna().any():
        raise ValueError(f"{kind} 지표값 결측")

    if len(df) != 25 or df["signguCd"].duplicated().any():
        raise ValueError(f"{kind} 서울 25개 자치구 검증 실패")

    df.to_csv(
        PROCESSED_DIR / f"tourism_{kind}.csv",
        index=False,
        encoding="utf-8-sig",
    )

    return df


stay = load_tourism("stay", "tarSjrnDsIxVal")
consumption = load_tourism(
    "consumption", "tarExpDsIxVal"
)

print("[PASS] Tourism Data Validation")
print("Stay regions:", len(stay))
print("Consumption regions:", len(consumption))


# 3. 관광 지표 상위 10개 지역
for data, metric in [
    (stay, "타권역 방문자 비중"),
    (consumption, "외지인 소비액"),
]:
    top10 = data.nlargest(10, "value")

    for _, row in top10.iterrows():
        summary.append({
            "source": "TOURISM",
            "metric": metric,
            "period": row["baseYm"],
            "item": row["signguNm"],
            "value": row["value"],
        })

# 소비 지표 그래프
top10 = consumption.nlargest(10, "value")
top10 = top10.sort_values("value")

plt.figure(figsize=(10, 6))
plt.barh(top10["signguNm"], top10["value"])
plt.title("서울 자치구 외지인 소비액 지표 TOP 10")
plt.xlabel("관광공사 제공 지표값")
plt.tight_layout()

plt.savefig(
    REPORTS_DIR / "tourism_consumption_top10.png",
    dpi=150,
)
plt.close()

print("[PASS] Tourism Chart")


# 4. 핵심 분석 결과 저장
summary_df = pd.DataFrame(summary)

summary_path = REPORTS_DIR / "analysis_summary.csv"
summary_df.to_csv(
    summary_path,
    index=False,
    encoding="utf-8-sig",
)

print("[PASS] Analysis Summary")
print("Summary rows:", len(summary_df))
print("Saved:", summary_path)
print("[PASS] STEP 13 Analysis Complete")
