# 과제 A. 카페 주문 금액
coffee_price = 4500
coffee_quantity = 3
cake_price = 6500
cake_quantity = 2
total_price = coffee_price*coffee_quantity + cake_price*cake_quantity

print(total_price, "원")

# 과제 B. 학습 시간 변환
time = 385
hours = time//60
minutes = time%60

print(hours, "시간", minutes, "분")

# 과제 C. 직사각형 계산
# 새 넓이를 다시 계산
width = 12
height = 8
area = width * height

# 넓이를 계산
print(area)

# 넓이가 100보다 큰지 비교
print(area>100)

# width += 3 적용
width += 3
area_next = width * height
print(area_next)