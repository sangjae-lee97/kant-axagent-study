product_name = input("음료 이름: ").strip()
price = int(input("가격: ").strip())
quantity = int(input("수량: ").strip())

print(f"주문 상품: {product_name}\n총 금액: {price*quantity}")