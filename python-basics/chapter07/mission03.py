name = " 길동 "
email = "gil@example.com"
city = "seoul"
message = "I like Java"

# • 이름의 앞뒤 공백 제거
print(name.strip())
# • 도시를 대문자로 변환
print(city.upper())
# • Java를 Python으로 교체
print(message.replace("Java", "Python"))
# • 이메일 첫 글자와 마지막 글자 출력
print(email[0],email[-1])
# • 이메일 전체 길이 출력
print(len(email))
# • 이메일 앞 3글자를 출력합니다.
print(email[0:2])
# • 이름의 첫 글자와 마지막 글자를 출력합니다.
print(name[0], name[3])
# • 자신이 선택한 문자열 한 개에서 원하는 범위를 슬라이싱합니다.
print(email[4:])
# 최소 3줄의 문장을 만듭니다.
print(f"이름: {name.strip()}")
print(f"도시: {city.upper()}")
print(f"이메일 길이: {len(email)}")

# 다음 중 한 가지 오류를 일부러 만들어 봅니다.
# • 닫히지 않은 따옴표
print("Hello)
# • 범위를 벗어난 인덱스
print(email[20])
# • 문자열과 정수를 +로 연결
print(name + 30)