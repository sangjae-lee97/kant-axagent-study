product_price = int(input("상품가격을 입력해 주세요: ").strip())
quantity = int(input("수량을 입력해 주세요: ").strip())
amount = product_price * quantity

if amount >= 100000:
    print(f"10% 할인 받아 {amount*0.9}원 입니다.")
elif amount >= 50000:
    print(f"5% 할인 받아 {amount*0.95}원 입니다.")
else:
    print(f"총 금액은 {amount}원 입니다.")