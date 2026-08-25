score = float(input("점수를 입력하세요: ").strip())

if score >= 90:
    print("A")
elif score >= 80:
    print("B 이상")
elif score >= 70:
    print("C 이상")
elif score >= 60:
    print("D 이상")
else:
    print("F")
