# Chapter 12 LLM 분석 코드 검증 요약

## 핵심 원칙

- 생성 코드는 검토되지 않은 초안입니다.
- 코드가 실행됨 ≠ 분석이 올바름.
- 정적 스캔 0건 ≠ 코드가 안전함.
- 자동 검증 PASS ≠ 실행 승인. 사람 승인과 제한된 실행 환경이 별도로 필요합니다.

## 1. 데이터셋 인벤토리
```text
    dataset  exists  rows  columns                                                                                   column_list  missing_values  duplicated_rows
  customers    True   150        6                                             customer_id, name, gender, age, city, signup_date               0                0
   products    True   100        4                                                     product_id, product_name, category, price               0                0
     orders    True   300        7 order_id, customer_id, order_date, payment_method, order_status, order_month, order_dayofweek               0                0
order_items    True   764        6                         order_item_id, order_id, product_id, quantity, unit_price, line_total               0                0
```

## 2. 필수 컬럼
```text
    dataset         column  dataset_exists  exists status
  customers            age            True    True   PASS
  customers           city            True    True   PASS
  customers    customer_id            True    True   PASS
  customers         gender            True    True   PASS
   products       category            True    True   PASS
   products          price            True    True   PASS
   products     product_id            True    True   PASS
   products   product_name            True    True   PASS
     orders    customer_id            True    True   PASS
     orders     order_date            True    True   PASS
     orders       order_id            True    True   PASS
     orders   order_status            True    True   PASS
     orders payment_method            True    True   PASS
order_items       order_id            True    True   PASS
order_items  order_item_id            True    True   PASS
order_items     product_id            True    True   PASS
order_items       quantity            True    True   PASS
order_items     unit_price            True    True   PASS
```

## 3. PK
```text
    dataset   primary_key  key_exists  missing_key_count  duplicated_key_count status
  customers   customer_id        True                  0                     0   PASS
   products    product_id        True                  0                     0   PASS
     orders      order_id        True                  0                     0   PASS
order_items order_item_id        True                  0                     0   PASS
```

## 4. 관계
```text
        purpose left_dataset right_dataset         key  left_has_key  right_has_key  missing_left_key_count  duplicated_parent_key_count  invalid_reference_count status
상품 정보와 주문 상세 연결  order_items      products  product_id          True           True                       0                            0                        0   PASS
주문 정보와 주문 상세 연결  order_items        orders    order_id          True           True                       0                            0                        0   PASS
주문 정보와 고객 정보 연결       orders     customers customer_id          True           True                       0                            0                        0   PASS
```

## 5. 카테고리 집계 검증
```text
               check_item        value status
    order_merge_row_count         True   PASS
    order_merge_unmatched            0   PASS
    completed_detail_rows          474   PASS
          included_status    completed   PASS
  product_merge_row_count         True   PASS
  product_merge_unmatched            0   PASS
         category_missing            0   PASS
   completed_source_total  148990000.0   PASS
   category_grouped_total  148990000.0   PASS
category_total_difference          0.0   PASS
   category_ratio_sum_pct        100.0   PASS
```

## 6. 월별 집계 검증
```text
                   check_item        value status
        order_merge_row_count         True   PASS
        order_merge_unmatched            0   PASS
        completed_detail_rows          474   PASS
              included_status    completed   PASS
order_date_missing_or_failure          0.0   PASS
       completed_source_total  148990000.0   PASS
        monthly_grouped_total  148990000.0   PASS
     monthly_total_difference          0.0   PASS
```

## 7. 문제별 ML 누수 계약
```text
       problem                    prediction_time                                      target                                                                                                             forbidden_examples                                                                            split_rule status                                                                                                                                                latest_contract
    regression 주문 상세 기반 target 재료를 아직 사용할 수 없는 시점                                 order_total avg_unit_price, customer_id, item_count, line_total, order_id, order_status, order_total, quantity, total_quantity, unit_price                  날짜 순서 split + train 내부 TimeSeriesSplit selection + frozen final test REVIEW                                                         최종 train/test는 날짜 그룹을 보존; 기본 TimeSeriesSplit은 행 단위이므로 동일 날짜가 CV 경계에서 나뉠 수 있음을 검토하고 필요 시 날짜 그룹 기반 CV 사용
classification                           주문 생성 직후 completed=0, cancelled=1; refunded/other 제외   cancel_reason, cancelled_at, customer_id, is_cancelled, line_total, order_id, order_status, product_id, quantity, unit_price 교육용 stratified train/validation/test; model/threshold는 validation, test는 frozen final REVIEW completed/cancelled 교육용 모집단; predict_proba는 보정된 실제 발생 확률로 단정 금지; 작은 클래스 표본 경고; F1 임계값은 교육용이며 실제 운영은 FP/FN 업무 비용 반영; 같은 validation의 model+threshold 반복 선택 한계 기록
```

## 8. 정적 스캔
```text
severity   category  line                       detail
  review     import     1 외부 작업 가능 모듈 import: requests
    high    network     3      외부 URL 사용: requests.get
    high  operation     3     외부 네트워크 요청: requests.get
    high file_write     4    파일 쓰기 모드: open(..., 'wb')
```

## 9. 실행 Gate
```text
                gate         status                                                                meaning
     schema_and_keys           PASS                                                            필수 구조·PK·관계
aggregate_validation           PASS                                                     completed 범위·병합·총합
          ml_leakage         REVIEW 문제별 prediction time·forbidden feature·split/selection 계약을 실제 생성 코드에 대조
         static_scan        BLOCKED                                                        차단 심각도 탐지: high
 sandbox_and_package         REVIEW                                    격리 환경·쓰기 범위·네트워크·리소스 제한·공급망을 사람이 확인
      human_approval         REVIEW                                          자동 Evidence와 별도로 명시적 실행 승인 필요
  execution_decision DO_NOT_EXECUTE                                                             자동 승인하지 않음
```

## 10. 해석 범위
- 금액 집계는 `order_status == "completed"`인 주문 상세만 사용합니다.
- `line_total = quantity × unit_price`이며 여기서는 완료 주문 상세 금액입니다.
- 할인·배송비·세금·부분 환불을 모두 반영한 회계상 순매출이라고 단정하지 않습니다.
- 모델 결과와 동시 변화를 원인으로 단정하지 않습니다.
