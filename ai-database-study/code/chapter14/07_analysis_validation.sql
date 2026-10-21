-- Chapter 14. SQL 분석 상세 검증
-- 목적: P14-V03 기준 행 수, 상태·월별·기록 금액·완료 기간과 품질 결과를 조회합니다.
-- 이 파일은 읽기 전용 증거 조회이며 최종 예외 기반 완료 게이트는 08 파일입니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;

-- 1. 분석 기간
SELECT *
FROM analysis_lab.analysis_parameters;

-- 2. 테이블과 VIEW 행 수
SELECT
    (SELECT COUNT(*) FROM analysis_lab.students) AS students_count,
    (SELECT COUNT(*) FROM analysis_lab.instructors) AS instructors_count,
    (SELECT COUNT(*) FROM analysis_lab.courses) AS courses_count,
    (SELECT COUNT(*) FROM analysis_lab.enrollments) AS enrollments_count,
    (SELECT COUNT(*) FROM analysis_lab.enrollment_analysis_dataset)
        AS dataset_count;

-- 기대: 8 / 3 / 5 / 24 / 24

-- 3. 상태별 기대값과 실제값 비교
WITH expected(status, expected_count) AS (
    VALUES
        ('완료'::varchar, 12),
        ('수강중'::varchar, 5),
        ('신청'::varchar, 4),
        ('취소'::varchar, 3)
),
actual AS (
    SELECT
        e.status,
        COUNT(*)::integer AS actual_count
    FROM analysis_lab.enrollments AS e
    CROSS JOIN analysis_lab.analysis_parameters AS p
    WHERE e.enrolled_at >= p.start_date
      AND e.enrolled_at < p.end_date_exclusive
    GROUP BY e.status
)
SELECT
    e.status,
    e.expected_count,
    COALESCE(a.actual_count, 0) AS actual_count,
    e.expected_count = COALESCE(a.actual_count, 0) AS passed
FROM expected AS e
LEFT JOIN actual AS a
    ON a.status = e.status
ORDER BY CASE e.status
    WHEN '신청' THEN 1
    WHEN '수강중' THEN 2
    WHEN '완료' THEN 3
    WHEN '취소' THEN 4
    ELSE 99
END;

-- 4. date spine을 포함한 월별 기대값과 실제값 비교
WITH expected(
    enrollment_month,
    expected_count,
    expected_recorded_amount
) AS (
    VALUES
        (DATE '2026-01-01', 3, 350000),
        (DATE '2026-02-01', 4, 520000),
        (DATE '2026-03-01', 5, 680000),
        (DATE '2026-04-01', 4, 550000),
        (DATE '2026-05-01', 4, 540000),
        (DATE '2026-06-01', 4, 570000)
),
actual AS (
    SELECT
        DATE_TRUNC('month', e.enrolled_at)::date AS enrollment_month,
        COUNT(*)::integer AS actual_count,
        SUM(e.recorded_amount)::integer AS actual_recorded_amount
    FROM analysis_lab.enrollments AS e
    CROSS JOIN analysis_lab.analysis_parameters AS p
    WHERE e.enrolled_at >= p.start_date
      AND e.enrolled_at < p.end_date_exclusive
    GROUP BY DATE_TRUNC('month', e.enrolled_at)
)
SELECT
    e.enrollment_month,
    e.expected_count,
    COALESCE(a.actual_count, 0) AS actual_count,
    e.expected_count = COALESCE(a.actual_count, 0)
        AS count_passed,
    e.expected_recorded_amount,
    COALESCE(a.actual_recorded_amount, 0) AS actual_recorded_amount,
    e.expected_recorded_amount = COALESCE(a.actual_recorded_amount, 0)
        AS recorded_amount_passed
FROM expected AS e
LEFT JOIN actual AS a
    ON a.enrollment_month = e.enrollment_month
ORDER BY e.enrollment_month;

-- 5. 완료된 신청의 완료 기간 기준값
SELECT
    COUNT(*) AS completed_count,
    ROUND(AVG(e.completed_at - e.enrolled_at), 2) AS avg_completion_days,
    MIN(e.completed_at - e.enrolled_at) AS min_completion_days,
    MAX(e.completed_at - e.enrolled_at) AS max_completion_days,
    COUNT(*) = 12 AS completed_count_passed,
    ROUND(AVG(e.completed_at - e.enrolled_at), 2) = 25.00
        AS avg_completion_days_passed,
    MIN(e.completed_at - e.enrolled_at) = 18
        AS min_completion_days_passed,
    MAX(e.completed_at - e.enrolled_at) = 36
        AS max_completion_days_passed
FROM analysis_lab.enrollments AS e
CROSS JOIN analysis_lab.analysis_parameters AS p
WHERE e.status = '완료'
  AND e.enrolled_at >= p.start_date
  AND e.enrolled_at < p.end_date_exclusive;

-- 6. 데이터셋 중복과 핵심 합계
SELECT
    COUNT(*) AS dataset_row_count,
    COUNT(DISTINCT enrollment_id) AS distinct_enrollment_count,
    SUM(recorded_amount) AS recorded_amount_sum,
    COUNT(*) FILTER (WHERE is_completed) AS completed_count,
    COUNT(*) = 24 AS dataset_row_count_passed,
    COUNT(DISTINCT enrollment_id) = 24
        AS distinct_enrollment_count_passed,
    SUM(recorded_amount) = 3210000 AS recorded_amount_sum_passed,
    COUNT(*) FILTER (WHERE is_completed) = 12
        AS completed_count_passed
FROM analysis_lab.enrollment_analysis_dataset;

-- 7. 데이터 품질 이상 건수
WITH quality_issues AS (
    SELECT 'orphan_student' AS issue_type, COUNT(*) AS issue_count
    FROM analysis_lab.enrollments AS e
    LEFT JOIN analysis_lab.students AS s
        ON s.id = e.student_id
    WHERE s.id IS NULL

    UNION ALL

    SELECT 'orphan_course', COUNT(*)
    FROM analysis_lab.enrollments AS e
    LEFT JOIN analysis_lab.courses AS c
        ON c.id = e.course_id
    WHERE c.id IS NULL

    UNION ALL

    SELECT 'orphan_instructor', COUNT(*)
    FROM analysis_lab.courses AS c
    LEFT JOIN analysis_lab.instructors AS i
        ON i.id = c.instructor_id
    WHERE i.id IS NULL

    UNION ALL

    SELECT 'completed_without_date', COUNT(*)
    FROM analysis_lab.enrollments
    WHERE status = '완료'
      AND completed_at IS NULL

    UNION ALL

    SELECT 'non_completed_with_date', COUNT(*)
    FROM analysis_lab.enrollments
    WHERE status <> '완료'
      AND completed_at IS NOT NULL

    UNION ALL

    SELECT 'enrollment_before_join', COUNT(*)
    FROM analysis_lab.enrollments AS e
    JOIN analysis_lab.students AS s
        ON s.id = e.student_id
    WHERE e.enrolled_at < s.joined_at

    UNION ALL

    SELECT 'enrollment_before_course_open', COUNT(*)
    FROM analysis_lab.enrollments AS e
    JOIN analysis_lab.courses AS c
        ON c.id = e.course_id
    WHERE e.enrolled_at < c.opened_at

    UNION ALL

    SELECT 'cancel_amount_zeroed', COUNT(*)
    FROM analysis_lab.enrollments
    WHERE status = '취소'
      AND recorded_amount = 0

    UNION ALL

    SELECT 'outside_analysis_period', COUNT(*)
    FROM analysis_lab.enrollments AS e
    CROSS JOIN analysis_lab.analysis_parameters AS p
    WHERE e.enrolled_at < p.start_date
       OR e.enrolled_at >= p.end_date_exclusive

    UNION ALL

    SELECT 'duplicate_active_enrollment', COUNT(*)
    FROM (
        SELECT student_id, course_id
        FROM analysis_lab.enrollments
        WHERE status IN ('신청', '수강중')
        GROUP BY student_id, course_id
        HAVING COUNT(*) > 1
    ) AS duplicates

    UNION ALL

    SELECT 'duplicate_dataset_id', COUNT(*)
    FROM (
        SELECT enrollment_id
        FROM analysis_lab.enrollment_analysis_dataset
        GROUP BY enrollment_id
        HAVING COUNT(*) > 1
    ) AS duplicates
)
SELECT
    issue_type,
    issue_count,
    issue_count = 0 AS passed
FROM quality_issues
ORDER BY issue_type;

-- 8. 상세 검증 요약
WITH checks AS (
    SELECT
        (SELECT COUNT(*) FROM analysis_lab.students) = 8
            AS students_passed,
        (SELECT COUNT(*) FROM analysis_lab.instructors) = 3
            AS instructors_passed,
        (SELECT COUNT(*) FROM analysis_lab.courses) = 5
            AS courses_passed,
        (SELECT COUNT(*) FROM analysis_lab.enrollments) = 24
            AS enrollments_passed,
        (SELECT COUNT(*) FROM analysis_lab.enrollment_analysis_dataset) = 24
            AS dataset_passed,
        (SELECT SUM(recorded_amount) FROM analysis_lab.enrollment_analysis_dataset) = 3210000
            AS recorded_amount_passed,
        (
            SELECT COUNT(*)
            FROM analysis_lab.enrollment_analysis_dataset
            WHERE is_completed
        ) = 12 AS completed_count_passed
)
SELECT
    *,
    students_passed
    AND instructors_passed
    AND courses_passed
    AND enrollments_passed
    AND dataset_passed
    AND recorded_amount_passed
    AND completed_count_passed
        AS chapter14_sql_evidence_summary_passed
FROM checks;

-- 최종 완료 판정은 08_analysis_lab_validation.sql에서 예외 기반으로 수행합니다.