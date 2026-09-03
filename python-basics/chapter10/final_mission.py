# 미션 A - 카운트다운
# 사용자에게 시작 숫자를 입력받는다.
# 그 숫자부터 1까지 거꾸로 출력한다.
# 마지막에 "시작!"을 출력한다.

number = int(input("숫자를 입력해주세요").strip())
for i in range(number,0,-1):
    print(i)
print("시작!")

# 미션 B - 배수 찾기
# 1부터 30까지 반복한다.
# 3의 배수만 출력한다.

for i in range(1,31):
    if i % 3 == 0:
        print(i)

# 미션 C — 합계 계산기
# 사용자에게 양의 정수를 입력받는다.
# 1부터 그 숫자까지의 합계를 계산한다.

number = int(input("양의 정수를 입력해 주세요: ").strip())
result = 0
for i in range(1,number+1):
    result += i
print(result)

# 미션 D — 비밀번호 재입력 연습
# 정답 문자열을 하나 정한다.
# 사용자가 정답을 입력할 때까지 계속 입력받는다.
# 정답이면 반복을 끝낸다.

password = "1234"
not_matched = True
while not_matched:
    if password == input("비밀번호를 입력해 주세요: ").strip():
        not_matched = False
        print("정답입니다")
    else:
        print("틀렸습니다. 다시 입력해주세요.")

   