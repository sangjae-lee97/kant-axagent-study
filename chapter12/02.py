tags = ["Python", "AI", "Python", "Data", "AI"]

# print(type(tags))
# print(len(tags))

# unique_tags = set(tags)

# print(type(unique_tags))
# print(len(unique_tags))
# print(unique_tags)


# set을 쓰지 말고 list 기능만 써서 unique_tags를 구현 하시오.
uni_tags = []
for i in tags:
    if i in uni_tags:
        continue
    else:
        uni_tags.append(i)
print(uni_tags)

# 수도코드(의사코드)로 작성해줘.
