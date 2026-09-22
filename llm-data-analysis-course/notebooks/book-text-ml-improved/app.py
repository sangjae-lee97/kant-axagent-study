# app.py

from pathlib import Path

import pandas as pd
import streamlit as st

from kiwipiepy import Kiwi
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.metrics.pairwise import cosine_similarity


# --------------------------------------------------
# 1. 기본 설정
# --------------------------------------------------

st.set_page_config(
    page_title="도서 텍스트 분석 앱",
    layout="wide"
)

BASE_DIR = Path(__file__).resolve().parent
DATA_PATH = BASE_DIR / "books_improved.csv"


# --------------------------------------------------
# 2. 화면 먼저 표시
# --------------------------------------------------

st.title("교보문고 도서 텍스트 분석 앱")

st.write(
    "형태소 분석과 TF-IDF를 이용해 "
    "도서 분야 예측과 유사 도서 추천을 수행합니다."
)


# --------------------------------------------------
# 3. Kiwi 형태소 분석기
# --------------------------------------------------

@st.cache_resource
def load_kiwi():
    return Kiwi()


kiwi = load_kiwi()


# 사용할 품사
target_tags = {
    "NNG",  # 일반 명사
    "NNP",  # 고유 명사
    "SL",   # 영문
}


# 불용어
stopwords = {
    "에디션",
}


# --------------------------------------------------
# 4. 제목 전처리 함수
# --------------------------------------------------

def tokenize_title(text):

    tokens = kiwi.tokenize(str(text))

    selected_tokens = [
        token.form
        for token in tokens
        if token.tag in target_tags
    ]

    return " ".join(selected_tokens)


def clean_tokens(text):

    tokens = str(text).split()

    cleaned_tokens = [
        token
        for token in tokens
        if len(token) >= 2
        and not token.isdigit()
        and token not in stopwords
    ]

    return " ".join(cleaned_tokens)


def preprocess_title(text):

    tokenized = tokenize_title(text)
    cleaned = clean_tokens(tokenized)

    return cleaned


# --------------------------------------------------
# 5. 데이터 불러오기
# --------------------------------------------------

@st.cache_data
def load_data():

    df = pd.read_csv(
        DATA_PATH,
        encoding="utf-8-sig"
    )

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

    # 문자열 정리
    df["상품명"] = (
        df["상품명"]
        .fillna("")
        .astype(str)
        .str.strip()
    )

    df["분야"] = (
        df["분야"]
        .fillna("미분류")
        .astype(str)
        .str.strip()
    )

    # 빈 제목 제거
    df = df[
        df["상품명"] != ""
    ].reset_index(drop=True)

    return df


# --------------------------------------------------
# 6. 데이터 로드
# --------------------------------------------------

try:

    df = load_data()

except FileNotFoundError:

    st.error(
        "books_improved.csv 파일을 찾지 못했습니다. "
        "app.py와 같은 폴더에 있는지 확인해 주세요."
    )

    st.stop()

except Exception as e:

    st.error(f"데이터 로드 오류: {e}")

    st.stop()


st.write(
    "전체 도서 수:",
    len(df)
)


# --------------------------------------------------
# 7. 전체 상품명 전처리
# --------------------------------------------------

@st.cache_data
def preprocess_dataframe(df):

    result = df.copy()

    result["상품명_정제"] = (
        result["상품명"]
        .apply(preprocess_title)
    )

    return result


with st.spinner(
    "도서 제목을 형태소 분석하고 있습니다..."
):

    df = preprocess_dataframe(df)


# --------------------------------------------------
# 8. 분야 분류 모델 학습
# --------------------------------------------------

@st.cache_resource
def train_classifier(
    titles,
    categories
):

    vectorizer = TfidfVectorizer()

    # 학습 데이터에서는 fit_transform
    X = vectorizer.fit_transform(
        titles
    )

    model = MultinomialNB()

    model.fit(
        X,
        categories
    )

    return vectorizer, model


with st.spinner(
    "분류 모델을 학습하고 있습니다..."
):

    classifier_vectorizer, classifier_model = (
        train_classifier(
            df["상품명_정제"],
            df["분야"]
        )
    )


# --------------------------------------------------
# 9. 추천용 TF-IDF 생성
# --------------------------------------------------

@st.cache_resource
def build_recommender(titles):

    vectorizer = TfidfVectorizer()

    title_matrix = (
        vectorizer
        .fit_transform(titles)
    )

    return vectorizer, title_matrix


with st.spinner(
    "추천 데이터를 준비하고 있습니다..."
):

    recommender_vectorizer, title_matrix = (
        build_recommender(
            df["상품명_정제"]
        )
    )


st.success("모델 준비 완료!")


# --------------------------------------------------
# 10. 추천 함수
# --------------------------------------------------

def recommend_books(
    df,
    title_matrix,
    selected_index,
    top_n=5,
    min_similarity=0.1
):

    # 선택 도서 분야
    selected_category = df.loc[
        selected_index,
        "분야"
    ]

    # 같은 분야만 후보
    candidate_indices = df.index[
        df["분야"] == selected_category
    ].tolist()

    # 자기 자신 제외
    candidate_indices = [
        idx
        for idx in candidate_indices
        if idx != selected_index
    ]

    if not candidate_indices:
        return pd.DataFrame()

    # 선택 도서 벡터
    selected_vector = (
        title_matrix[selected_index]
    )

    # 후보 도서 벡터
    candidate_matrix = (
        title_matrix[candidate_indices]
    )

    # 코사인 유사도
    similarities = cosine_similarity(
        selected_vector,
        candidate_matrix
    ).ravel()

    # 출력 컬럼
    display_columns = [
        col
        for col in [
            "상품명",
            "인물",
            "출판사",
            "분야"
        ]
        if col in df.columns
    ]

    result = df.loc[
        candidate_indices,
        display_columns
    ].copy()

    result["유사도"] = similarities

    # 최소 유사도 이상만 유지
    result = result[
        result["유사도"] >= min_similarity
    ]

    # 높은 순 정렬 후 최대 5권
    result = (
        result
        .sort_values(
            "유사도",
            ascending=False
        )
        .head(top_n)
        .reset_index(drop=True)
    )

    result["유사도"] = (
        result["유사도"]
        .round(3)
    )

    return result


# ==================================================
# 11. 도서 분야 예측
# ==================================================

st.header(
    "1. 도서 분야 예측"
)

user_title = st.text_input(
    "도서 제목을 입력하세요",
    placeholder="예: 처음 배우는 파이썬 데이터 분석"
)


if st.button(
    "분야 예측",
    key="predict_button"
):

    clean_title = (
        user_title.strip()
    )

    if not clean_title:

        st.warning(
            "도서 제목을 입력해 주세요."
        )

    else:

        # 형태소 분석 + 단어 필터링
        processed_title = (
            preprocess_title(
                clean_title
            )
        )

        if not processed_title:

            st.warning(
                "전처리 후 사용할 수 있는 단어가 없습니다."
            )

        else:

            # 새 제목은 transform만 사용
            title_vector = (
                classifier_vectorizer
                .transform(
                    [processed_title]
                )
            )

            predicted_category = (
                classifier_model
                .predict(
                    title_vector
                )[0]
            )

            st.success(
                f"예상 분야: {predicted_category}"
            )

            st.write(
                "원본 제목:",
                clean_title
            )

            st.write(
                "전처리 결과:",
                processed_title
            )

            st.caption(
                "새 제목에서는 TF-IDF를 다시 학습하지 않고 "
                "기존 Vectorizer의 transform()만 사용합니다."
            )


# ==================================================
# 12. 비슷한 도서 추천
# ==================================================

st.header(
    "2. 비슷한 도서 추천"
)


def format_book(index):

    title = (
        df.iloc[index]["상품명"]
    )

    if "인물" in df.columns:

        author = str(
            df.iloc[index]["인물"]
        )

        return (
            f"{title} | {author}"
        )

    return title


selected_index = st.selectbox(
    "기준 도서를 선택하세요",
    options=list(
        range(len(df))
    ),
    format_func=format_book
)


if st.button(
    "비슷한 도서 5권 추천",
    key="recommend_button"
):

    selected_title = df.loc[
        selected_index,
        "상품명"
    ]

    selected_category = df.loc[
        selected_index,
        "분야"
    ]

    recommendations = (
        recommend_books(
            df=df,
            title_matrix=title_matrix,
            selected_index=selected_index,
            top_n=5,
            min_similarity=0.1
        )
    )

    st.write(
        "선택 도서:",
        selected_title
    )

    st.write(
        "분야:",
        selected_category
    )

    if recommendations.empty:

        st.info(
            "현재 기준으로 유사도가 있는 "
            "추천 도서를 찾지 못했습니다."
        )

    else:

        st.subheader(
            "추천 결과"
        )

        st.dataframe(
            recommendations,
            width="stretch",
            hide_index=True
        )

        st.caption(
            "같은 분야의 도서 중 "
            "코사인 유사도가 0.1 이상인 도서만 추천합니다."
        )