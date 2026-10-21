-- Chapter 14. 기간별·범주별 분석
-- 목적: P14-Q02·Q05 질문을 고정 기간과 재현 가능한 월 기준표로 분석합니다.
-- recorded_amount는 신청 시점 기록 금액입니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;

-- P14-Q02. 데이터가 없는 월도 0으로 유지하는 월별 신청 건수와 기록 금액
WITH parameters AS (
    SELECT start_date, end_date_exclusive
    FROM analysis_lab.analysis_parameters
),
months AS (
    SELECT generate_series(
        p.start_date,
        p.end_date_exclusive - INTERVAL '1 month',
        INTERVAL '1 month'
    )::date AS enrollment_month
    FROM parameters AS p
),
monthly_actual AS (
    SELECT
        DATE_TRUNC('month', e.enrolled_at)::date AS enrollment_month,
        COUNT(*) AS enrollment_count,
        SUM(e.recorded_amount) AS recorded_amount_sum
    FROM analysis_lab.enrollments AS e
    CROSS JOIN parameters AS p
    WHERE e.enrolled_at >= p.start_date
      AND e.enrolled_at < p.end_date_exclusive
    GROUP BY DATE_TRUNC('month', e.enrolled_at)
)
SELECT
    m.enrollment_month,
    COALESCE(a.enrollment_count, 0) AS enrollment_count,
    COALESCE(a.recorded_amount_sum, 0) AS recorded_amount_sum
FROM months AS m
LEFT JOIN monthly_actual AS a
    ON a.enrollment_month = m.enrollment_month
ORDER BY m.enrollment_month;

-- 기대:
-- 2026-01 3 / 350000
-- 2026-02 4 / 520000
-- 2026-03 5 / 680000
-- 2026-04 4 / 550000
-- 2026-05 4 / 540000
-- 2026-06 4 / 570000

-- 이전 달과 비교: date spine이 있으므로 중간 월이 비어도 이전 달 의미가 유지됩니다.
WITH parameters AS (
    SELECT start_date, end_date_exclusive
    FROM analysis_lab.analysis_parameters
),
months AS (
    SELECT generate_series(
        p.start_date,
        p.end_date_exclusive - INTERVAL '1 month',
        INTERVAL '1 month'
    )::date AS enrollment_month
    FROM parameters AS p
),
monthly_actual AS (
    SELECT
        DATE_TRUNC('month', e.enrolled_at)::date AS enrollment_month,
        COUNT(*) AS enrollment_count,
        SUM(e.recorded_amount) AS recorded_amount_sum
    FROM analysis_lab.enrollments AS e
    CROSS JOIN parameters AS p
    WHERE e.enrolled_at >= p.start_date
      AND e.enrolled_at < p.end_date_exclusive
    GROUP BY DATE_TRUNC('month', e.enrolled_at)
),
monthly AS (
    SELECT
        m.enrollment_month,
        COALESCE(a.enrollment_count, 0) AS enrollment_count,
        COALESCE(a.recorded_amount_sum, 0) AS recorded_amount_sum
    FROM months AS m
    LEFT JOIN monthly_actual AS a
        ON a.enrollment_month = m.enrollment_month
)
SELECT
    enrollment_month,
    enrollment_count,
    LAG(enrollment_count) OVER (
        ORDER BY enrollment_month
    ) AS previous_enrollment_count,
    enrollment_count
        - LAG(enrollment_count) OVER (
            ORDER BY enrollment_month
        ) AS enrollment_count_change,
    recorded_amount_sum,
    LAG(recorded_amount_sum) OVER (
        ORDER BY enrollment_month
    ) AS previous_recorded_amount_sum,
    recorded_amount_sum
        - LAG(recorded_amount_sum) OVER (
            ORDER BY enrollment_month
        ) AS recorded_amount_change
FROM monthly
ORDER BY enrollment_month;

-- 월별 상태 구성
WITH filtered_enrollments AS (
    SELECT e.*
    FROM analysis_lab.enrollments AS e
    CROSS JOIN analysis_lab.analysis_parameters AS p
    WHERE e.enrolled_at >= p.start_date
      AND e.enrolled_at < p.end_date_exclusive
)
SELECT
    DATE_TRUNC('month', enrolled_at)::date AS enrollment_month,
    status,
    COUNT(*) AS enrollment_count
FROM filtered_enrollments
GROUP BY DATE_TRUNC('month', enrolled_at), status
ORDER BY enrollment_month, status;

-- 범주별 신청 건수와 기록 금액
WITH filtered_enrollments AS (
    SELECT e.*
    FROM analysis_lab.enrollments AS e
    CROSS JOIN analysis_lab.analysis_parameters AS p
    WHERE e.enrolled_at >= p.start_date
      AND e.enrolled_at < p.end_date_exclusive
)
SELECT
    c.category,
    COUNT(e.id) AS enrollment_count,
    COALESCE(SUM(e.recorded_amount), 0) AS recorded_amount_sum,
    ROUND(AVG(e.recorded_amount), 2) AS avg_recorded_amount
FROM analysis_lab.courses AS c
LEFT JOIN filtered_enrollments AS e
    ON e.course_id = c.id
GROUP BY c.category
ORDER BY enrollment_count DESC, c.category;

-- 기대:
-- Database 10 / 1120000
-- Python 5 / 750000
-- Data Analysis 5 / 700000
-- AI 4 / 640000

-- 범주별 현재 완료 상태 비중
-- 이는 전체 신청 중 현재 완료 상태가 차지하는 비율입니다.
-- 실제 완료율은 관찰 기간이 충분한 코호트와 취소 포함 여부를 별도로 정의해야 합니다.
WITH filtered_enrollments AS (
    SELECT e.*
    FROM analysis_lab.enrollments AS e
    CROSS JOIN analysis_lab.analysis_parameters AS p
    WHERE e.enrolled_at >= p.start_date
      AND e.enrolled_at < p.end_date_exclusive
)
SELECT
    c.category,
    COUNT(e.id) AS enrollment_count,
    COUNT(e.id) FILTER (
        WHERE e.status = '완료'
    ) AS completed_count,
    ROUND(
        COUNT(e.id) FILTER (WHERE e.status = '완료')
        * 100.0
        / NULLIF(COUNT(e.id), 0),
        2
    ) AS completed_share_pct
FROM analysis_lab.courses AS c
LEFT JOIN filtered_enrollments AS e
    ON e.course_id = c.id
GROUP BY c.category
ORDER BY c.category;

-- P14-Q05. 완료된 신청의 완료 기간 요약
-- 아직 완료되지 않은 신청은 제외되므로 전체 수강생의 평균 소요 기간으로 일반화하지 않습니다.
WITH filtered_enrollments AS (
    SELECT e.*
    FROM analysis_lab.enrollments AS e
    CROSS JOIN analysis_lab.analysis_parameters AS p
    WHERE e.enrolled_at >= p.start_date
      AND e.enrolled_at < p.end_date_exclusive
)
SELECT
    COUNT(*) AS completed_count,
    ROUND(AVG(completed_at - enrolled_at), 2) AS avg_completion_days,
    MIN(completed_at - enrolled_at) AS min_completion_days,
    MAX(completed_at - enrolled_at) AS max_completion_days
FROM filtered_enrollments
WHERE status = '완료';

-- 기대: completed_count 12, avg 25, min 18, max 36

-- 강의별 완료된 신청의 평균 완료 기간
WITH filtered_enrollments AS (
    SELECT e.*
    FROM analysis_lab.enrollments AS e
    CROSS JOIN analysis_lab.analysis_parameters AS p
    WHERE e.enrolled_at >= p.start_date
      AND e.enrolled_at < p.end_date_exclusive
)
SELECT
    c.id AS course_id,
    c.title,
    COUNT(e.id) FILTER (
        WHERE e.status = '완료'
    ) AS completed_count,
    ROUND(
        AVG(e.completed_at - e.enrolled_at)
            FILTER (WHERE e.status = '완료'),
        2
    ) AS avg_completion_days
FROM analysis_lab.courses AS c
LEFT JOIN filtered_enrollments AS e
    ON e.course_id = c.id
GROUP BY c.id, c.title
ORDER BY c.id;

-- 분석 기간 검산
SELECT
    p.start_date,
    p.end_date_exclusive,
    MIN(e.enrolled_at) AS min_enrolled_at,
    MAX(e.enrolled_at) AS max_enrolled_at,
    COUNT(*) AS enrollment_count,
    SUM(e.recorded_amount) AS recorded_amount_sum
FROM analysis_lab.enrollments AS e
CROSS JOIN analysis_lab.analysis_parameters AS p
WHERE e.enrolled_at >= p.start_date
  AND e.enrolled_at < p.end_date_exclusive
GROUP BY p.start_date, p.end_date_exclusive;

-- 기대: 2026-01-01 / 2026-07-01 / 2026-01-10 / 2026-06-22 / 24 / 3210000