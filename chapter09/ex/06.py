# score = int(input("점수를 입력하세요: ").strip())

# if score >= 60:
#     print("통과")
# else:
#     print("재도전")

day = input("요일: ").strip()
if day == "토요일" or day == "일요일":
    print("주말입니다")
else:
    print("평일입니다")