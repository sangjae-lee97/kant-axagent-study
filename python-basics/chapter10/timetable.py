dan = int(input("출력할 단을 입력하세요"))
for number in range(1,10):
    result = dan * number    
    if result % 2 == 0:
        print(f"{dan}*{number}={result} 짝수 결과입니다.")
    else:
        print(f"{dan}*{number}={result}")