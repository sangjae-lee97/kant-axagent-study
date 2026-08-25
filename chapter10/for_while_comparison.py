count = 0          # 시도 횟수
success = False    # 성공 여부를 기록할 변수

for i in range(5):
    password = input("비밀번호 입력: ")
    if password == "1234":
        print("로그인 성공!")
        break
else:
    print("5회 모두 틀렸습니다.")

count = 0          # 시도 횟수
success = False    # 성공 여부를 기록할 변수

while count < 5 and not success:
    if input("비밀번호 입력: ") == "1234":
        success = True
    else:
        count += 1
        print(f"틀렸습니다 ({count}/5)")

print("성공" if success else "잠김")