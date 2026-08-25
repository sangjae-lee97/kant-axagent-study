name = " 문길동 "
city = "seoul"
language = "Python"
intro = "I like Java"

# 1. name의 앞뒤 공백을 제거합니다.
clean = name.strip()
print(clean)
# 2. city를 대문자로 변경합니다.
upper_city = city.upper()
print(upper_city)
# 3. intro의 Java를 Python으로 바꿉니다.
changed = intro.replace("Java", "Python")
print(changed)
# 4. language의 첫 글자와 마지막 글자를 출력합니다.
print(language[0])
print(language[len(language)-1])
print(language[-1])
# 5. language의 길이를 출력합니다.
print(len(language))
# 6. f-string으로 최종 프로필 문장을 최소 3줄 출력합니다.
print(f"이름은 {clean}입니다.\n살고있는 곳은 {upper_city}입니다.\n사용할 수 있는 프로그램 언어는 {language}입니다.\n저를 소개하는 말은'{intro}'입니다.")