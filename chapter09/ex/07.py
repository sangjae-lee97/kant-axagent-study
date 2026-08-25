age = int(input("나이를 입력하세요: ").strip())
has_ticket = input("티켓을 소유하고 계신가요? (y/n): ".strip())

if age >= 18:
    if has_ticket == "y":
        print("입장 가능합니다.")
    else:
        print("티켓이 필요합니다.")
else:
    print("나이 조건 불충족")