text = "Banana "

# 처음 na가 나온 자리수
print(text.find("na"))

# 없으면 -1 반환
print(text.find("tna"))

# a의 개수
print(text.count("a"))

# 대문자로 바꾸기
print(text.upper())

# 소문자로 바꾸기
print(text.lower())

# 양쪽 끝 공백 제거
print(text.strip())

# 문자열 일부 교체
new_text = text.replace("a","z")
print(text)
print(new_text)


word = " python basics "

clean = word.strip()
print(clean)

upper_word = clean.upper()
print(upper_word)

changed = clean.replace("basics", "practice")
print(changed)

memory = " i like java "

clean = memory.strip()
changed = clean.replace("java", "python")
upper_memory = changed.upper()

print(upper_memory)