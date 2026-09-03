name = input("이름: ").strip()
score = int(input("점수: ").strip())
rate_attendance = float(input("출석률: ").strip())
status_submission = input("과제 제출 여부 (yes/no): ").strip().lower()

if score >= 90 and rate_attendance >= 90 and status_submission == "yes":
    status_completion = "우수 수료"
elif score >= 60 and rate_attendance >= 80 and status_submission == "yes":
    status_completion = "수료"
else:
    status_completion = "미수료"

print(f"{name}님의 최종 판정: {status_completion}")
