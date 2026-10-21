-- Chapter 14. 분석용 데이터셋
-- 목적: 고정 분석 기간 안에서 수강신청 1건을 한 행으로 하는 Python 분석용 VIEW를 생성합니다.
-- 주의: 원본 테이블을 변경하거나 데이터를 복제하지 않습니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;

DO $$
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '실행 중단: 현재 데이터베이스는 %입니다.',
            current_database();
    END IF;

    IF to_regclass('analysis_lab.enrollments') IS NULL
       OR to_regclass('analysis_lab.analysis_parameters') IS NULL THEN
        RAISE EXCEPTION
            '실행 중단: analysis_lab 기준 객체가 없습니다.';
    END IF;

    IF to_regclass('analysis_lab.enrollment_analysis_dataset') IS NOT NULL THEN
        RAISE EXCEPTION
            '실행 중단: enrollment_analysis_dataset VIEW가 이미 존재합니다.';
    END IF;
END
$$;

BEGIN;

CREATE VIEW analysis_lab.enrollment_analysis_dataset AS
SELECT
    e.id AS enrollment_id,
    s.id AS student_id,
    s.name AS student_name,
    s.region,
    c.id AS course_id,
    c.title AS course_title,
    c.category,
    c.level,
    i.id AS instructor_id,
    i.name AS instructor_name,
    e.enrolled_at,
    DATE_TRUNC('month', e.enrolled_at)::date AS enrollment_month,
    e.status,
    e.recorded_amount AS recorded_amount,
    e.completed_at,
    CASE
        WHEN e.completed_at IS NOT NULL
        THEN e.completed_at - e.enrolled_at
        ELSE NULL
    END AS completion_days,
    (e.status = '완료') AS is_completed
FROM analysis_lab.enrollments AS e
JOIN analysis_lab.students AS s
    ON s.id = e.student_id
JOIN analysis_lab.courses AS c
    ON c.id = e.course_id
JOIN analysis_lab.instructors AS i
    ON i.id = c.instructor_id
CROSS JOIN analysis_lab.analysis_parameters AS p
WHERE e.enrolled_at >= p.start_date
  AND e.enrolled_at < p.end_date_exclusive;

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM analysis_lab.enrollment_analysis_dataset) <> 24
       OR (SELECT COUNT(DISTINCT enrollment_id) FROM analysis_lab.enrollment_analysis_dataset) <> 24
       OR (SELECT SUM(recorded_amount) FROM analysis_lab.enrollment_analysis_dataset) <> 3210000 THEN
        RAISE EXCEPTION 'Chapter 14 analysis dataset validation failed before COMMIT.';
    END IF;
END
$$;

COMMIT;
DO $$ BEGIN RAISE NOTICE 'Chapter 14 analysis dataset validation passed'; END $$;

-- 1. 전체 데이터셋
SELECT *
FROM analysis_lab.enrollment_analysis_dataset
ORDER BY enrollment_id;

-- 2. 행 수: 기대 24
SELECT COUNT(*) AS dataset_row_count
FROM analysis_lab.enrollment_analysis_dataset;

-- 3. enrollment_id 중복: 기대 0행
SELECT
    enrollment_id,
    COUNT(*) AS duplicate_count
FROM analysis_lab.enrollment_analysis_dataset
GROUP BY enrollment_id
HAVING COUNT(*) > 1;

-- 4. 같은 기간의 원본과 데이터셋 행 수 비교: 기대 24 / 24
SELECT
    (
        SELECT COUNT(*)
        FROM analysis_lab.enrollments AS e
        CROSS JOIN analysis_lab.analysis_parameters AS p
        WHERE e.enrolled_at >= p.start_date
          AND e.enrolled_at < p.end_date_exclusive
    ) AS source_row_count,
    (
        SELECT COUNT(*)
        FROM analysis_lab.enrollment_analysis_dataset
    ) AS dataset_row_count;

-- 5. Python 또는 CSV 내보내기용 조회
SELECT *
FROM analysis_lab.enrollment_analysis_dataset
ORDER BY enrollment_id;