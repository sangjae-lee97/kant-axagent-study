name = input("고객 이름을 입력해 주세요: ")
amount = int(input("주문 금액: ").strip())
member_answer = input("회원인가요? (y/n): ").strip().lower()
is_member = member_answer == "y"

if amount >= 50000 or is_member:
    print(f"무료배상 대상이어서 총 금액은 {amount}원 입니다.")
else:
    print(f"총 금액은 배송비 3000원이 추가되어 {amount+3000}원 입니다.")