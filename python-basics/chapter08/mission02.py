name = input("이름: ").strip()
time_hours = float(input("하루 학습 시간: "))
time_days = int(input("학습 일수: "))
total_time = time_days * time_hours

print(f"{name}님의 총 학습 시간은 {total_time}시간 입니다.")