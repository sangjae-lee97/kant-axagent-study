-- Chapter 08. 집계 쿼리
-- 실행 전 Chapter 07 최종 데이터와 00_check_course_project.sql을 확인합니다.
-- 이 파일은 데이터를 변경하지 않습니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;

-- 용어
-- 전체 신청 이력: 모든 enrollments 행
-- 활성 신청: status IN ('신청', '수강중')
-- 취소 제외 신청 이력: status <> '취소'
-- recorded_amount: 신청 시 기록 금액이며 실제 결제·회계 매출이 아닙니다.

-- 1. 기본 집계 기준값: 5 / 590000 / 118000.00 / 100000 / 150000
SELECT
    COUNT(*) AS enrollment_count,
    SUM(recorded_amount) AS total_recorded_amount,
    ROUND(AVG(recorded_amount), 2) AS avg_recorded_amount,
    MIN(recorded_amount) AS min_recorded_amount,
    MAX(recorded_amount) AS max_recorded_amount
FROM course_project.enrollments;

-- 2. 활성 신청 기준값: 3건 / 340000
SELECT
    COUNT(*) AS active_enrollment_count,
    SUM(recorded_amount) AS active_recorded_amount,
    ROUND(AVG(recorded_amount), 2) AS active_avg_recorded_amount
FROM course_project.enrollments
WHERE status IN ('신청', '수강중');

-- 3. 취소 제외 신청 이력: 4건 / 440000 / 110000.00
SELECT
    COUNT(*) AS non_cancelled_count,
    SUM(recorded_amount) AS non_cancelled_recorded_amount,
    ROUND(AVG(recorded_amount), 2) AS non_cancelled_avg_recorded_amount
FROM course_project.enrollments
WHERE status <> '취소';

-- 4. 상태별 GROUP BY
SELECT
    status,
    COUNT(*) AS enrollment_count,
    SUM(recorded_amount) AS total_recorded_amount
FROM course_project.enrollments
GROUP BY status
ORDER BY CASE status
    WHEN '신청' THEN 1
    WHEN '수강중' THEN 2
    WHEN '완료' THEN 3
    WHEN '취소' THEN 4
    ELSE 99
END;

-- 5. PostgreSQL FILTER 조건부 집계
SELECT
    COUNT(*) AS total_count,
    COUNT(*) FILTER (WHERE status = '신청') AS requested_count,
    COUNT(*) FILTER (WHERE status = '수강중') AS learning_count,
    COUNT(*) FILTER (
        WHERE status IN ('신청', '수강중')
    ) AS active_enrollment_count,
    COUNT(*) FILTER (WHERE status = '완료') AS completed_count,
    COUNT(*) FILTER (WHERE status = '취소') AS cancelled_count,
    SUM(recorded_amount) FILTER (
        WHERE status IN ('신청', '수강중')
    ) AS active_recorded_amount,
    SUM(recorded_amount) FILTER (
        WHERE status <> '취소'
    ) AS non_cancelled_recorded_amount
FROM course_project.enrollments;

-- 6. 강의별 COUNT 대상 비교
SELECT
    c.id AS course_id,
    c.title AS course_title,
    COUNT(*) AS joined_row_count,
    COUNT(e.id) AS enrollment_count,
    COUNT(DISTINCT e.student_id) AS student_count
FROM course_project.courses AS c
LEFT JOIN course_project.enrollments AS e
    ON c.id = e.course_id
   AND e.status <> '취소'
GROUP BY c.id, c.title
ORDER BY c.id;

-- 7. 강의별 취소 제외 신청·학생·기록 금액
SELECT
    c.id AS course_id,
    c.title AS course_title,
    COUNT(e.id) AS non_cancelled_count,
    COUNT(DISTINCT e.student_id) AS student_count,
    COALESCE(SUM(e.recorded_amount), 0) AS non_cancelled_recorded_amount
FROM course_project.courses AS c
LEFT JOIN course_project.enrollments AS e
    ON c.id = e.course_id
   AND e.status <> '취소'
GROUP BY c.id, c.title
ORDER BY c.id;

-- 8. HAVING: 취소 제외 신청 2건 이상 강의
SELECT
    c.id,
    c.title,
    COUNT(e.id) AS enrollment_count
FROM course_project.courses AS c
JOIN course_project.enrollments AS e
    ON c.id = e.course_id
WHERE e.status <> '취소'
GROUP BY c.id, c.title
HAVING COUNT(e.id) >= 2
ORDER BY c.id;

-- 9. 강사별 강의 수·신청 수
SELECT
    i.id AS instructor_id,
    i.name AS instructor_name,
    COUNT(DISTINCT c.id) AS course_count,
    COUNT(e.id) AS enrollment_count,
    COUNT(e.id) FILTER (
        WHERE e.status <> '취소'
    ) AS non_cancelled_count
FROM course_project.instructors AS i
LEFT JOIN course_project.courses AS c
    ON i.id = c.instructor_id
LEFT JOIN course_project.enrollments AS e
    ON c.id = e.course_id
GROUP BY i.id, i.name
ORDER BY i.id;

-- 10. 여러 JOIN에서 강의 가격을 잘못 합산하는 예
-- 기준 데이터에서 강사 201은 잘못된 합계 440000, 실제 강의 가격 합계 220000입니다.
-- 강사 202는 신청이 한 건뿐이라 두 값이 우연히 150000으로 같지만, 쿼리 기준이 올바르다는 뜻은 아닙니다.
SELECT
    i.id AS instructor_id,
    i.name AS instructor_name,
    SUM(c.price) AS wrong_course_price_sum
FROM course_project.instructors AS i
JOIN course_project.courses AS c
    ON i.id = c.instructor_id
JOIN course_project.enrollments AS e
    ON c.id = e.course_id
GROUP BY i.id, i.name
ORDER BY i.id;

-- 강의 가격 합계가 질문이라면 신청 테이블을 JOIN하지 않습니다.
SELECT
    i.id AS instructor_id,
    i.name AS instructor_name,
    COALESCE(SUM(c.price), 0) AS course_price_sum
FROM course_project.instructors AS i
LEFT JOIN course_project.courses AS c
    ON i.id = c.instructor_id
GROUP BY i.id, i.name
ORDER BY i.id;

-- 11. 학생별 전체 신청·취소 제외 신청
SELECT
    s.id,
    s.name,
    COUNT(e.id) AS total_enrollment_count,
    COUNT(e.id) FILTER (
        WHERE e.status <> '취소'
    ) AS non_cancelled_count
FROM course_project.students AS s
LEFT JOIN course_project.enrollments AS e
    ON s.id = e.student_id
GROUP BY s.id, s.name
ORDER BY s.id;