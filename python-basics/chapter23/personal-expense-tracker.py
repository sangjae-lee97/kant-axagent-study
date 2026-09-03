# 해야 할 것 1
def add_expense(expenses):
    date = input("날짜(YYYY-MM-DD): ").strip()
    category = input("카테고리: ").strip()
    description = input("내용: ").strip()
    if not date or not category or not description:
        print("날짜, 카테고리, 내용은 비워 둘 수 없습니다.")
        return

    try:
        amount = int(input("금액: "))
    except ValueError:
        print("금액은 정수로 입력해 주세요.")
        return

    if amount <= 0:
        print("금액은 0보다 큰 값으로 입력해 주세요.")
        return
    
    expense = {
        "date": date,
        "category": category,
        "description": description,
        "amount": amount,
    }
    expenses.append(expense)
    print("지출 내역을 추가했습니다.")


# 해야 할 것 2
def show_expenses(expenses):
    if not expenses:
        print("등록된 지출이 없습니다.")
        return
    print("\n=== 지출 내역 ===")
    number = 1
    for expense in expenses:
        print(
            f"{number}.{expense['date']}|"
            f"{expense['category']}|"
            f"{expense['description']}|"
            f"{expense['amount']:, 원}"
        )
        number += 1
