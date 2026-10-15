
import json
import os
from datetime import datetime
from pathlib import Path

import requests
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parents[1]
RAW_DIR = BASE_DIR / "data" / "raw"
CONFIG_PATH = BASE_DIR / "config" / "tourism_params.json"

RAW_DIR.mkdir(parents=True, exist_ok=True)
load_dotenv(BASE_DIR / ".env")

service_key = os.getenv("TOURISM_SERVICE_KEY")
stay_url = os.getenv("TOURISM_STAY_URL")
consumption_url = os.getenv("TOURISM_CONSUMPTION_URL")

if not service_key:
    raise RuntimeError("TOURISM_SERVICE_KEY가 없습니다.")

if not stay_url or not consumption_url:
    raise RuntimeError("관광 API URL이 설정되지 않았습니다.")

with CONFIG_PATH.open("r", encoding="utf-8") as f:
    config = json.load(f)


def call_api(name, url, params):
    request_params = dict(params)
    request_params["serviceKey"] = service_key

    response = requests.get(
        url,
        params=request_params,
        timeout=30,
    )

    if response.status_code != 200:
        raise RuntimeError(
            f"{name} API 실패: HTTP {response.status_code}"
        )

    try:
        data = response.json()
    except ValueError as e:
        raise RuntimeError(
            f"{name} 응답이 JSON이 아닙니다."
        ) from e

    header = data.get("response", {}).get("header", {})
    body = data.get("response", {}).get("body", {})

    if header.get("resultCode") != "0000":
        raise RuntimeError(f"{name} API 결과 오류: {header}")

    if body.get("totalCount", 0) < 1:
        raise RuntimeError(f"{name} API 조회 결과가 0건입니다.")

    items = body.get("items", {})
    if not isinstance(items, dict) or not items.get("item"):
        raise RuntimeError(f"{name} API 실제 데이터가 없습니다.")

    return data


stay_data = call_api(
    "stay",
    stay_url,
    config["stay"]["params"],
)

consumption_data = call_api(
    "consumption",
    consumption_url,
    config["consumption"]["params"],
)

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

stay_path = RAW_DIR / f"tourism_stay_{timestamp}.json"
consumption_path = RAW_DIR / f"tourism_consumption_{timestamp}.json"

with stay_path.open("w", encoding="utf-8") as f:
    json.dump(stay_data, f, ensure_ascii=False, indent=2)

with consumption_path.open("w", encoding="utf-8") as f:
    json.dump(consumption_data, f, ensure_ascii=False, indent=2)

print("[PASS] Tourism API")
print("stay saved:", stay_path)
print("consumption saved:", consumption_path)
