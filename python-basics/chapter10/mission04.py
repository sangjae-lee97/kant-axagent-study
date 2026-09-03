number = int(input("양의 정수를 입력하세요: ").strip())
result = 0
for i in range(1, number+1):
    result += i
print(f"1부터 {number}까지의 합계는 {result}입니다.")