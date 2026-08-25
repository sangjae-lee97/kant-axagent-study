saved_id = "python"
saved_password = "1234"
user_id = input("id를 입력해 주세요: ").strip()
user_password = input("password를 입력해 주세요: ").strip()

if user_id == saved_id and user_password == saved_password:
    print("로그인 성공")
else:
    print("아이디 또는 비밀번호를 확인하세요.")