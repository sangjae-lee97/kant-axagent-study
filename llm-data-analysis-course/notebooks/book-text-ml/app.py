from pathlib import Path

import pandas as pd
import streamlit as st

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.metrics.pairwise import cosine_similarity


# =========================
# 1. 기본 경로 설정
# =========================

BASE_DIR = Path(__file__).resolve().parent
DATA_PATH = BASE_DIR / "book_bestseller_clean.csv"


# =========================
# 2. 데이터 불러오기
# =========================

@st.cache_data
def load_data():

    df = pd.read_csv(
        DATA_PATH,
        encoding="utf-8-sig"
    )

    # 필수 컬럼 확인
    required_columns = [
        "상품명",
        "분야"
    ]

    missing_columns = [
        col
        for col in required_columns
        if col not in df.columns
    ]

    if missing_columns:
        raise ValueError(
            f"필수 컬럼이 없습니다: {missing_columns}"
        )

    # 상품명 정리
    df["상품명"] = (
        df["상품명"]
        .fillna("")
        .astype(str)
        .str.strip()
    )

    # 분야 정리
    df["분야"] = (
        df["분야"]
        .fillna("미분류")
        .astype(str)
        .str.strip()
    )

    # 상품명이 비어 있는 행 제거
    df = df[
        df["상품명"] != ""
    ].reset_index(drop=True)

    return df


# =========================
# 3. 분류 모델 학습
# =========================

@st.cache_resource
def train_classifier():

    df = load_data()

    # 미분류 제외
    train_df = df[
        df["분야"] != "미분류"
    ].copy()

    # 분야가 2개 이상인지 확인
    if train_df["분야"].nunique() < 2:
        raise ValueError(
            "서로 다른 분야가 2개 이상 필요합니다."
        )

    # 분류용 TF-IDF
    vectorizer = TfidfVectorizer()

    X = vectorizer.fit_transform(
        train_df["상품명"]
    )

    y = train_df["분야"]

    # Naive Bayes 모델
    model = MultinomialNB()

    model.fit(X, y)

    return vectorizer, model


# =========================
# 4. 추천용 TF-IDF 준비
# =========================

@st.cache_resource
def build_recommender():

    df = load_data()

    # 추천용 TF-IDF
    vectorizer = TfidfVectorizer()

    title_matrix = vectorizer.fit_transform(
        df["상품명"]
    )

    return vectorizer, title_matrix


# =========================
# 5. 추천 함수
# =========================

def recommend_books(
    df,
    title_matrix,
    selected_index,
    top_n=5,
):

    # 선택 도서의 TF-IDF 벡터
    selected_vector = title_matrix[
        selected_index
    ]

    # 전체 도서와 코사인 유사도 계산
    similarities = cosine_similarity(
        selected_vector,
        title_matrix
    ).ravel()

    # 자기 자신 제외
    similarities[selected_index] = -1

    # 유사도가 높은 순서 Top N
    top_indices = (
        similarities
        .argsort()[::-1][:top_n]
    )

    # 화면에 보여줄 컬럼
    display_columns = [
        col
        for col in [
            "상품명",
            "저자",
            "출판사",
            "분야"
        ]
        if col in df.columns
    ]

    # 추천 결과
    result = df.iloc[
        top_indices
    ][display_columns].copy()

    # 유사도 추가
    result["유사도"] = (
        similarities[top_indices]
        .round(3)
    )

    return result.reset_index(drop=True)


# =========================
# 6. 데이터와 모델 준비
# =========================

df = load_data()

# 분류용
classifier_vectorizer, classifier_model = (
    train_classifier()
)

# 추천용
recommender_vectorizer, title_matrix = (
    build_recommender()
)


# =========================
# 7. Streamlit 기본 화면
# =========================

st.title(
    "교보문고 베스트셀러 텍스트 분석 앱"
)

st.write(
    "도서 분야 분류와 유사 도서 추천 기능을 실습합니다."
)

st.write(
    "데이터 크기:",
    df.shape
)

st.dataframe(
    df.head()
)


# =========================
# 8. 도서 분야 예측 UI
# =========================

st.header(
    "1. 도서 분야 예측"
)

user_title = st.text_input(
    "도서 제목을 입력하세요",
    placeholder="예: 처음 배우는 파이썬 데이터 분석"
)

if st.button("분야 예측"):

    clean_title = user_title.strip()

    if not clean_title:

        st.warning(
            "도서 제목을 입력해 주세요."
        )

    else:

        # 새로운 제목은 transform만 사용
        title_vector = (
            classifier_vectorizer
            .transform([clean_title])
        )

        # 분야 예측
        predicted_category = (
            classifier_model
            .predict(title_vector)[0]
        )

        st.success(
            f"예상 분야: {predicted_category}"
        )

        # 결과 해석
        st.subheader(
            "분류 결과 해석"
        )

        st.write(
            f"입력한 제목 `{clean_title}`에 대해 "
            f"모델은 `{predicted_category}` 분야로 예측했습니다."
        )

        st.info(
            "현재 학습 데이터의 도서 제목 패턴을 바탕으로 "
            "모델이 해당 분야를 예측한 결과입니다."
        )

        st.markdown("""
- 실제 공식 분야가 반드시 이 분야라는 의미는 아닙니다.
- 모델이 제목의 의미를 완전히 이해했다는 의미는 아닙니다.
- 예측 결과가 100% 정답이라는 의미는 아닙니다.
- 학습 데이터의 크기와 분야 분포에 따라 결과가 달라질 수 있습니다.
        """)


# =========================
# 9. 도서 선택 UI
# =========================

st.header(
    "2. 비슷한 도서 추천"
)


# selectbox에서 보여줄 문자열
def format_book(index):

    title = df.iloc[index]["상품명"]

    # 저자 컬럼이 있는 경우
    if "저자" in df.columns:

        author = str(
            df.iloc[index]["저자"]
        )

        return f"{title} | {author}"

    return title


# 기준 도서 선택
selected_index = st.selectbox(
    "기준 도서를 선택하세요",
    options=list(range(len(df))),
    format_func=format_book
)


# =========================
# 10. Top 5 추천
# =========================

if st.button(
    "비슷한 도서 5권 추천"
):

    recommendations = recommend_books(
        df=df,
        title_matrix=title_matrix,
        selected_index=selected_index,
        top_n=5
    )

    st.write(
        "선택 도서:",
        df.iloc[selected_index]["상품명"]
    )

    st.dataframe(
        recommendations,
        width="stretch",
        hide_index=True
    )

    st.caption(
        "유사도는 도서 제목의 TF-IDF 벡터를 "
        "코사인 유사도로 비교한 값입니다."
    )