from pathlib import Path

import pandas as pd
import streamlit as st

from src.classification import (
    build_classification_dataset,
    choose_threshold,
    load_classification_source_data,
    select_validation_model,
    split_train_validation_test,
    threshold_metrics,
    train_and_compare_on_validation,
)


BASE_DIR = Path(__file__).resolve().parent
PROCESSED_DIR = BASE_DIR / "data" / "processed"

WEEKDAY_LABELS = {
    "월요일": 0,
    "화요일": 1,
    "수요일": 2,
    "목요일": 3,
    "금요일": 4,
    "토요일": 5,
    "일요일": 6,
}


@st.cache_resource
def load_model():
    """Chapter 10과 같은 규칙으로 모델과 Threshold를 재현합니다."""
    data = load_classification_source_data(PROCESSED_DIR)

    (
        model_data,
        numeric_features,
        categorical_features,
        _merge_checks,
        _data_quality_checks,
    ) = build_classification_dataset(
        customers=data["customers"],
        orders=data["orders"],
        order_items=data["order_items"],
    )

    (
        X_train,
        X_valid,
        X_test,
        y_train,
        y_valid,
        y_test,
        features,
    ) = split_train_validation_test(
        model_data=model_data,
        numeric_features=numeric_features,
        categorical_features=categorical_features,
        random_state=42,
    )

    (
        models,
        validation_comparison,
        _validation_predictions,
        validation_probabilities,
    ) = train_and_compare_on_validation(
        X_train=X_train,
        X_valid=X_valid,
        y_train=y_train,
        y_valid=y_valid,
        numeric_features=numeric_features,
        categorical_features=categorical_features,
        random_state=42,
    )

    selected_model_name = select_validation_model(validation_comparison)
    selected_model = models[selected_model_name]

    threshold_df = threshold_metrics(
        y_valid,
        validation_probabilities[selected_model_name],
    )
    selected_threshold = choose_threshold(threshold_df)

    return {
        "model": selected_model,
        "model_name": selected_model_name,
        "threshold": selected_threshold,
        "model_data": model_data,
        "features": features,
        "X_test": X_test,
        "y_test": y_test,
    }


def int_stat(series: pd.Series, stat: str) -> int:
    values = pd.to_numeric(series, errors="coerce").dropna()
    if stat == "min":
        return int(values.min())
    if stat == "max":
        return int(values.max())
    return int(round(values.median()))


st.set_page_config(
    page_title="Chapter 10 주문 취소 예측",
    page_icon="📦",
    layout="wide",
)

st.title("📦 Chapter 10 주문 취소 예측")
st.caption(
    "9개 Feature를 직접 입력해 Logistic Regression의 취소 확률과 "
    "Threshold 기준 예측 결과를 확인합니다."
)

bundle = load_model()
model = bundle["model"]
model_name = bundle["model_name"]
threshold = float(bundle["threshold"])
model_data = bundle["model_data"]

m1, m2, m3 = st.columns(3)
m1.metric("선택 모델", model_name)
m2.metric("Threshold", f"{threshold:.2f}")
m3.metric("사용 Feature", f"{len(bundle['features'])}개")

tab1, tab2 = st.tabs(["직접 입력해서 예측", "기존 주문으로 확인"])

with tab1:
    st.subheader("Feature 입력")

    c1, c2, c3 = st.columns(3)

    with c1:
        age = st.number_input(
            "나이 (age)",
            min_value=int_stat(model_data["age"], "min"),
            max_value=int_stat(model_data["age"], "max"),
            value=int_stat(model_data["age"], "median"),
            step=1,
        )
        item_count = st.number_input(
            "상품 종류 수 (item_count)",
            min_value=int_stat(model_data["item_count"], "min"),
            max_value=int_stat(model_data["item_count"], "max"),
            value=int_stat(model_data["item_count"], "median"),
            step=1,
        )
        total_quantity = st.number_input(
            "총 주문 수량 (total_quantity)",
            min_value=int_stat(model_data["total_quantity"], "min"),
            max_value=int_stat(model_data["total_quantity"], "max"),
            value=int_stat(model_data["total_quantity"], "median"),
            step=1,
        )

    with c2:
        order_amount = st.number_input(
            "주문 금액 (order_amount)",
            min_value=int_stat(model_data["order_amount"], "min"),
            max_value=int_stat(model_data["order_amount"], "max"),
            value=int_stat(model_data["order_amount"], "median"),
            step=1000,
        )
        order_month = st.selectbox(
            "주문 월 (order_month)",
            options=list(range(1, 13)),
            index=int_stat(model_data["order_month"], "median") - 1,
        )

        weekday_labels = list(WEEKDAY_LABELS.keys())
        weekday_median = int_stat(model_data["order_dayofweek"], "median")
        order_dayofweek_label = st.selectbox(
            "주문 요일 (order_dayofweek)",
            options=weekday_labels,
            index=max(0, min(weekday_median, 6)),
        )
        order_dayofweek = WEEKDAY_LABELS[order_dayofweek_label]

    with c3:
        gender_options = sorted(model_data["gender"].dropna().astype(str).unique().tolist())
        city_options = sorted(model_data["city"].dropna().astype(str).unique().tolist())
        payment_options = sorted(
            model_data["payment_method"].dropna().astype(str).unique().tolist()
        )

        gender = st.selectbox("성별 (gender)", gender_options)
        city = st.selectbox("도시 (city)", city_options)
        payment_method = st.selectbox("결제수단 (payment_method)", payment_options)

    input_row = pd.DataFrame(
        [
            {
                "age": int(age),
                "item_count": int(item_count),
                "total_quantity": int(total_quantity),
                "order_amount": int(order_amount),
                "order_month": int(order_month),
                "order_dayofweek": int(order_dayofweek),
                "gender": gender,
                "city": city,
                "payment_method": payment_method,
            }
        ],
        columns=bundle["features"],
    )

    st.markdown("#### 현재 입력값")
    st.dataframe(input_row, use_container_width=True, hide_index=True)

    probability = float(model.predict_proba(input_row)[:, 1][0])
    prediction = int(probability >= threshold)

    st.markdown("#### 예측 결과")
    r1, r2, r3 = st.columns(3)
    r1.metric("취소 확률", f"{probability:.1%}")
    r2.metric("판정 기준", f"{threshold:.0%}")
    r3.metric("예측 클래스", "취소 위험 (1)" if prediction == 1 else "정상 완료 (0)")

    if prediction == 1:
        st.warning(
            f"취소 확률 {probability:.1%}가 Threshold {threshold:.0%} 이상이므로 "
            "취소 위험 주문으로 예측합니다."
        )
    else:
        st.success(
            f"취소 확률 {probability:.1%}가 Threshold {threshold:.0%} 미만이므로 "
            "정상 완료 주문으로 예측합니다."
        )

    st.caption(
        "이 값은 취소의 원인을 설명하는 값이 아니라, 현재 학습 데이터에서 "
        "비슷한 Feature 조합이 취소 클래스에 속할 확률을 모델이 추정한 결과입니다."
    )

with tab2:
    st.subheader("기존 주문의 실제값과 예측값 비교")

    order_ids = model_data["order_id"].tolist()
    selected_order_id = st.selectbox("order_id 선택", order_ids)

    row = model_data.loc[model_data["order_id"].eq(selected_order_id)].iloc[0]
    existing_input = pd.DataFrame(
        [{feature: row[feature] for feature in bundle["features"]}],
        columns=bundle["features"],
    )

    existing_probability = float(model.predict_proba(existing_input)[:, 1][0])
    existing_prediction = int(existing_probability >= threshold)
    actual = int(row["is_cancelled"])

    st.dataframe(existing_input, use_container_width=True, hide_index=True)

    e1, e2, e3 = st.columns(3)
    e1.metric("실제값", "cancelled (1)" if actual == 1 else "completed (0)")
    e2.metric("예측값", "cancelled (1)" if existing_prediction == 1 else "completed (0)")
    e3.metric("취소 확률", f"{existing_probability:.1%}")

    if actual == existing_prediction:
        st.success("이 주문은 실제값과 예측값이 일치합니다.")
    else:
        st.error("이 주문은 실제값과 예측값이 다릅니다.")

st.divider()
st.caption(
    "교육용 Chapter 10 모델입니다. Validation에서 모델과 Threshold를 선택했고, "
    "Test 결과를 보고 다시 튜닝하지 않습니다."
)
