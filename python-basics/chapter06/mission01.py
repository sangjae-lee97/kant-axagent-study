price = 37000
quantity = 5
shipping_fee = 0

# 요구사항
# 1. 상품 금액을 계산합니다
# 2. 배송비를 더한 최종 금액을 계산합니다.
# 3. 결과를 각각 출력합니다.

product_price = price * quantity
total_price = product_price + shipping_fee

print("상품 금액:", product_price)
print("최종 금액:", total_price)
