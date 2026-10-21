-- Chapter 14. 데이터 품질 점검
-- 목적: 집계 전에 행 수, 중복, 참조 관계, 시간 관계와 업무 규칙을 확인합니다.

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

    IF to_regclass('analysis_lab.students') IS NULL
       OR to_regclass('analysis_lab.instructors') IS NULL
       OR to_regclass('analysis_lab.courses') IS NULL
       OR to_regclass('analysis_lab.enrollments') IS NULL
       OR to_regclass('analysis_lab.analysis_parameters') IS NULL THEN
        RAISE EXCEPTION
            '실행 중단: analysis_lab 기준 객체가 없습니다.';
    END IF;
END
$$;

-- P14-V02-01. 테이블별 행 수
SELECT 'students' AS table_name, COUNT(*) AS row_count
FROM analysis_lab.students
UNION ALL
SELECT 'instructors', COUNT(*)
FROM analysis_lab.instructors
UNION ALL
SELECT 'courses', COUNT(*)
FROM analysis_lab.courses
UNION ALL
SELECT 'enrollments', COUNT(*)
FROM analysis_lab.enrollments
ORDER BY table_name;

-- 기대: courses 5, enrollments 24, instructors 3, students 8

-- P14-V02-02. enrollments PK 중복: 기대 0행
SELECT id, COUNT(*) AS duplicate_count
FROM analysis_lab.enrollments
GROUP BY id
HAVING COUNT(*) > 1;

-- P14-V02-03. 없는 학생을 참조하는 수강신청: 기대 0행
SELECT e.*
FROM analysis_lab.enrollments AS e
LEFT JOIN analysis_lab.students AS s
    ON s.id = e.student_id
WHERE s.id IS NULL;

-- P14-V02-04. 없는 강의를 참조하는 수강신청: 기대 0행
SELECT e.*
FROM analysis_lab.enrollments AS e
LEFT JOIN analysis_lab.courses AS c
    ON c.id = e.course_id
WHERE c.id IS NULL;

-- P14-V02-05. 없는 강사를 참조하는 강의: 기대 0행
SELECT c.*
FROM analysis_lab.courses AS c
LEFT JOIN analysis_lab.instructors AS i
    ON i.id = c.instructor_id
WHERE i.id IS NULL;

-- P14-V02-06. 완료인데 완료일이 없는 행: 기대 0행
SELECT id, status, completed_at
FROM analysis_lab.enrollments
WHERE status = '완료'
  AND completed_at IS NULL;

-- P14-V02-07. 완료가 아닌데 완료일이 있는 행: 기대 0행
SELECT id, status, completed_at
FROM analysis_lab.enrollments
WHERE status <> '완료'
  AND completed_at IS NOT NULL;

-- P14-V02-08. 완료일이 신청일보다 빠른 행: 기대 0행
SELECT id, enrolled_at, completed_at
FROM analysis_lab.enrollments
WHERE completed_at < enrolled_at;

-- P14-V02-09. 가입일보다 이른 신청: 기대 0행
SELECT
    e.id AS enrollment_id,
    e.student_id,
    s.joined_at,
    e.enrolled_at
FROM analysis_lab.enrollments AS e
JOIN analysis_lab.students AS s
    ON s.id = e.student_id
WHERE e.enrolled_at < s.joined_at;

-- P14-V02-10. 강의 개설일보다 이른 신청: 기대 0행
SELECT
    e.id AS enrollment_id,
    e.course_id,
    c.opened_at,
    e.enrolled_at
FROM analysis_lab.enrollments AS e
JOIN analysis_lab.courses AS c
    ON c.id = e.course_id
WHERE e.enrolled_at < c.opened_at;

-- P14-V02-11. 음수 신청 시점 기록 금액: 기대 0행
SELECT id, status, recorded_amount
FROM analysis_lab.enrollments
WHERE recorded_amount < 0;

-- P14-V02-12. 취소 후 기록 금액이 0으로 덮어써진 행: 기대 0행
SELECT id, status, recorded_amount
FROM analysis_lab.enrollments
WHERE status = '취소'
  AND recorded_amount = 0;

-- P14-V02-13. 허용되지 않은 상태: 기대 0행
SELECT id, status
FROM analysis_lab.enrollments
WHERE status NOT IN ('신청', '수강중', '완료', '취소')
   OR status IS NULL;

-- P14-V02-14. 분석 기간 밖의 행: 기대 0행
SELECT e.*
FROM analysis_lab.enrollments AS e
CROSS JOIN analysis_lab.analysis_parameters AS p
WHERE e.enrolled_at < p.start_date
   OR e.enrolled_at >= p.end_date_exclusive;

-- P14-V02-15. 활성 신청 중복: 기대 0행
SELECT
    student_id,
    course_id,
    COUNT(*) AS active_count
FROM analysis_lab.enrollments
WHERE status IN ('신청', '수강중')
GROUP BY student_id, course_id
HAVING COUNT(*) > 1;

-- P14-V02-16. 전체 요약
SELECT
    COUNT(*) AS enrollment_count,
    COUNT(DISTINCT id) AS distinct_enrollment_count,
    COUNT(*) FILTER (WHERE completed_at IS NULL) AS completed_at_null_count,
    COUNT(*) FILTER (WHERE status = '완료') AS completed_count,
    SUM(recorded_amount) AS recorded_amount_sum
FROM analysis_lab.enrollments;

-- 기대:
-- enrollment_count 24
-- distinct_enrollment_count 24
-- completed_at_null_count 12
-- completed_count 12
-- recorded_amount_sum 3210000