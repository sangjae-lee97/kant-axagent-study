order_amount = int(input("총 금액을 입력하세요: ").strip())
is_member = True

if order_amount >= 50000 or is_member :
    print("무료배송 입니다.")
else:
    print("배송비가 있습니다.")