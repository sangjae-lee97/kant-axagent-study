fruits = ["사과", "바나나"]
fruits.append("포도")

print(fruits)

fruits = ["사과", "포도"]
fruits.insert(1, "바나나")

print(fruits)

fruits = ["사과", "바나나"]
more_fruits = ["포도", "딸기", "키위"]

print("원래 fruits의 과일 갯수: ", len(fruits))

fruits.extend(more_fruits)

print(fruits)

print("extend 후 fruits의 과일 갯수: ", len(fruits))