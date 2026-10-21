-- Chapter 14. 기본 요약 분석
-- 목적: P14-Q01·Q03·Q04 질문을 같은 분석 기간과 행 단위로 집계합니다.
-- recorded_amount는 결제 완료나 회계 매출이 아니라 신청 시점 기록 금액입니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;

-- 공통 기간: [2026-01-01, 2026-07-01)
WITH filtered_enrollments AS (
    SELECT e.*
    FROM analysis_lab.enrollments AS e
    CROSS JOIN analysis_lab.analysis_parameters AS p
    WHERE e.enrolled_at >= p.start_date
      AND e.enrolled_at < p.end_date_exclusive
)
SELECT
    status,
    COUNT(*) AS enrollment_count
FROM filtered_enrollments
GROUP BY status
ORDER BY enrollment_count DESC, status;

-- 기대: 완료 12, 수강중 5, 신청 4, 취소 3

-- P14-Q01 보조 지표. 전체 신청 중 현재 완료 상태의 비중
-- 실제 완료율은 관찰 기간이 충분한 코호트와 분모 정책이 별도로 필요합니다.
WITH filtered_enrollments AS (
    SELECT e.*
    FROM analysis_lab.enrollments AS e
    CROSS JOIN analysis_lab.analysis_parameters AS p
    WHERE e.enrolled_at >= p.start_date
      AND e.enrolled_at < p.end_date_exclusive
)
SELECT
    status,
    COUNT(*) AS enrollment_count,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS enrollment_share_pct
FROM filtered_enrollments
GROUP BY status
ORDER BY enrollment_count DESC, status;

-- P14-Q03. 강의별 신청 건수와 신청 시점 기록 금액
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
    COUNT(e.id) AS enrollment_count,
    COALESCE(SUM(e.recorded_amount), 0) AS recorded_amount_sum
FROM analysis_lab.courses AS c
LEFT JOIN filtered_enrollments AS e
    ON e.course_id = c.id
GROUP BY c.id, c.title
ORDER BY enrollment_count DESC, c.id;

-- 기대:
-- 301 데이터베이스 입문 6 / 600000
-- 302 SQL 데이터 분석 4 / 520000
-- 303 파이썬 데이터 분석 5 / 750000
-- 304 데이터 시각화 5 / 700000
-- 305 AI 활용 데이터 설계 4 / 640000

-- 강사별 강의 수와 신청 건수
WITH filtered_enrollments AS (
    SELECT e.*
    FROM analysis_lab.enrollments AS e
    CROSS JOIN analysis_lab.analysis_parameters AS p
    WHERE e.enrolled_at >= p.start_date
      AND e.enrolled_at < p.end_date_exclusive
)
SELECT
    i.id AS instructor_id,
    i.name AS instructor_name,
    COUNT(DISTINCT c.id) AS course_count,
    COUNT(e.id) AS enrollment_count,
    COALESCE(SUM(e.recorded_amount), 0) AS recorded_amount_sum
FROM analysis_lab.instructors AS i
LEFT JOIN analysis_lab.courses AS c
    ON c.instructor_id = i.id
LEFT JOIN filtered_enrollments AS e
    ON e.course_id = c.id
GROUP BY i.id, i.name
ORDER BY enrollment_count DESC, i.id;

-- P14-Q04. 지역별 학생 수와 신청 건수
WITH filtered_enrollments AS (
    SELECT e.*
    FROM analysis_lab.enrollments AS e
    CROSS JOIN analysis_lab.analysis_parameters AS p
    WHERE e.enrolled_at >= p.start_date
      AND e.enrolled_at < p.end_date_exclusive
)
SELECT
    s.region,
    COUNT(DISTINCT s.id) AS student_count,
    COUNT(e.id) AS enrollment_count,
    COALESCE(SUM(e.recorded_amount), 0) AS recorded_amount_sum,
    ROUND(
        COUNT(e.id)::numeric / NULLIF(COUNT(DISTINCT s.id), 0),
        2
    ) AS enrollments_per_student
FROM analysis_lab.students AS s
LEFT JOIN filtered_enrollments AS e
    ON e.student_id = s.id
GROUP BY s.region
ORDER BY enrollment_count DESC, s.region;

-- 기대:
-- 서울 학생 3 / 신청 9 / 1210000
-- 경기 학생 2 / 신청 6 / 830000
-- 부산 학생 2 / 신청 6 / 770000
-- 대구 학생 1 / 신청 3 / 400000

-- 학생별 신청 수
WITH filtered_enrollments AS (
    SELECT e.*
    FROM analysis_lab.enrollments AS e
    CROSS JOIN analysis_lab.analysis_parameters AS p
    WHERE e.enrolled_at >= p.start_date
      AND e.enrolled_at < p.end_date_exclusive
)
SELECT
    s.id AS student_id,
    s.name,
    s.region,
    COUNT(e.id) AS enrollment_count,
    COALESCE(SUM(e.recorded_amount), 0) AS recorded_amount_sum
FROM analysis_lab.students AS s
LEFT JOIN filtered_enrollments AS e
    ON e.student_id = s.id
GROUP BY s.id, s.name, s.region
ORDER BY enrollment_count DESC, s.id;

-- 분석 기간 안에 신청이 없는 학생
WITH filtered_enrollments AS (
    SELECT e.*
    FROM analysis_lab.enrollments AS e
    CROSS JOIN analysis_lab.analysis_parameters AS p
    WHERE e.enrolled_at >= p.start_date
      AND e.enrolled_at < p.end_date_exclusive
)
SELECT
    s.id,
    s.name,
    s.region
FROM analysis_lab.students AS s
LEFT JOIN filtered_enrollments AS e
    ON e.student_id = s.id
WHERE e.id IS NULL
ORDER BY s.id;

-- 기준 데이터에서는 기대 0행입니다.