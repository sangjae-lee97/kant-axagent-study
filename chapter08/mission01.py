customer_name = input("성함을 입력해 주세요: ").strip()
product_name = input("주문할 상품을 입력해 주세요: ").strip()
product_price = int(input("상품 가격을 입력해 주세요: ").strip())
quantity = int(input("수량을 입력해 주세요: ").strip())
shipping_fee = int(input("배송비를 입력해 주세요: ").strip())
total_price = product_price * quantity + shipping_fee

print(f"{customer_name}님이 {product_name} {quantity}개를 주문했습니다. 총 {total_price}원 입니다")