score = int(input("점수를 입력하세요: ").strip())

if score == 85:
    print("정확히 85점")

elif score >= 80:
    print("우수")

elif score >= 60:
    print("통과")

else:
    print("미통과")


