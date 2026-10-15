
import subprocess
import sys
import logging
from datetime import datetime
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
LOG_DIR = BASE_DIR / "logs"
LOG_DIR.mkdir(exist_ok=True)

log_path = LOG_DIR / f"pipeline_{datetime.now():%Y%m%d_%H%M%S}.log"

logging.basicConfig(
    filename=log_path,
    level=logging.INFO,
    encoding="utf-8",
    format="%(asctime)s [%(levelname)s] %(message)s",
)

STEPS = [
    "collect_naver.py",
    "collect_tourism.py",
    "analyze.py",
    "generate_llm_report.py",
    "generate_pdf.py",
]


def main():
    print("=== 관광 데이터 자동화 시작 ===", flush=True)
    logging.info("Pipeline started")

    for script in STEPS:
        print(f"\n[RUN] {script}", flush=True)
        logging.info("Starting %s", script)

        script_path = BASE_DIR / "src" / script

        try:
            subprocess.run(
                [sys.executable, "-u", str(script_path)],
                cwd=BASE_DIR,
                check=True,
                timeout=180,
            )
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            logging.error("%s failed: %s", script, error)
            print(f"[FAIL] {script}: {error}", flush=True)
            sys.exit(1)

        print(f"[PASS] {script}", flush=True)
        logging.info("Completed %s", script)

    print("\n[PASS] Pipeline Complete", flush=True)
    logging.info("Pipeline completed successfully")


if __name__ == "__main__":
    main()
