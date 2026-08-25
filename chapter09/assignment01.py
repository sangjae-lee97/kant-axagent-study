age = int(input("나이를 입력해주세요: ").strip())

if age >= 20:
    print("성인 입니다.")
elif age >= 17:
    print("고등학생 입니다.")
elif age >= 14:
    print("중학생 입니다.")
elif age >= 8:
    print("초등학생 입니다.")
else:
    print("미취학 입니다.")