-- Chapter 08. JOIN·집계 결과 자동 검증
-- 실행 전 00 → 01 → 02 파일을 확인합니다.
-- 이 파일은 데이터를 변경하지 않으며 반복 실행할 수 있습니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;

DO $$
DECLARE
    v_detail_count bigint;
    v_grouped_count bigint;
    v_detail_total numeric;
    v_grouped_total numeric;
    v_active_count bigint;
    v_active_total numeric;
    v_grouped_active_count bigint;
    v_grouped_active_total numeric;
    v_non_cancelled_count bigint;
    v_non_cancelled_total numeric;
    v_grouped_non_cancelled_count bigint;
    v_grouped_non_cancelled_total numeric;
    v_joined_count bigint;
    v_orphan_student_count bigint;
    v_orphan_course_count bigint;
    v_orphan_instructor_count bigint;
    v_anti_join_left_count bigint;
    v_anti_join_exists_count bigint;
    v_on_student_count bigint;
    v_where_student_count bigint;
    v_course301_count bigint;
    v_course301_students bigint;
    v_course301_total numeric;
    v_course302_count bigint;
    v_course302_students bigint;
    v_course302_total numeric;
    v_course303_joined_rows bigint;
    v_course303_count bigint;
    v_course303_students bigint;
    v_course303_total numeric;
    v_instructor201_courses bigint;
    v_instructor201_enrollments bigint;
    v_instructor201_non_cancelled bigint;
    v_instructor202_courses bigint;
    v_instructor202_enrollments bigint;
    v_instructor202_non_cancelled bigint;
    v_having_course_count bigint;
    v_instructor201_wrong_price_sum numeric;
    v_instructor201_correct_price_sum numeric;
    v_instructor202_wrong_price_sum numeric;
    v_instructor202_correct_price_sum numeric;
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '검증 중단: 현재 데이터베이스는 %입니다. ai_database_book에 연결하세요.',
            current_database();
    END IF;

    IF to_regclass('course_project.students') IS NULL
       OR to_regclass('course_project.instructors') IS NULL
       OR to_regclass('course_project.courses') IS NULL
       OR to_regclass('course_project.enrollments') IS NULL THEN
        RAISE EXCEPTION
            '검증 중단: Chapter 07 course_project 테이블이 모두 존재하지 않습니다.';
    END IF;

    SELECT COUNT(*) INTO v_detail_count
    FROM course_project.enrollments;

    SELECT COALESCE(SUM(enrollment_count), 0)
    INTO v_grouped_count
    FROM (
        SELECT status, COUNT(*) AS enrollment_count
        FROM course_project.enrollments
        GROUP BY status
    ) AS status_summary;

    SELECT COALESCE(SUM(recorded_amount), 0)
    INTO v_detail_total
    FROM course_project.enrollments;

    SELECT COALESCE(SUM(total_recorded_amount), 0)
    INTO v_grouped_total
    FROM (
        SELECT course_id, SUM(recorded_amount) AS total_recorded_amount
        FROM course_project.enrollments
        GROUP BY course_id
    ) AS course_summary;

    SELECT COUNT(*), COALESCE(SUM(recorded_amount), 0)
    INTO v_active_count, v_active_total
    FROM course_project.enrollments
    WHERE status IN ('신청', '수강중');

    SELECT
        COALESCE(SUM(active_count), 0),
        COALESCE(SUM(active_recorded_amount), 0)
    INTO v_grouped_active_count, v_grouped_active_total
    FROM (
        SELECT
            status,
            COUNT(*) AS active_count,
            SUM(recorded_amount) AS active_recorded_amount
        FROM course_project.enrollments
        WHERE status IN ('신청', '수강중')
        GROUP BY status
    ) AS active_summary;

    SELECT COUNT(*), COALESCE(SUM(recorded_amount), 0)
    INTO v_non_cancelled_count, v_non_cancelled_total
    FROM course_project.enrollments
    WHERE status <> '취소';

    SELECT
        COALESCE(SUM(non_cancelled_count), 0),
        COALESCE(SUM(non_cancelled_recorded_amount), 0)
    INTO v_grouped_non_cancelled_count, v_grouped_non_cancelled_total
    FROM (
        SELECT
            c.id,
            COUNT(e.id) AS non_cancelled_count,
            COALESCE(SUM(e.recorded_amount), 0) AS non_cancelled_recorded_amount
        FROM course_project.courses AS c
        LEFT JOIN course_project.enrollments AS e
            ON c.id = e.course_id
           AND e.status <> '취소'
        GROUP BY c.id
    ) AS course_summary;

    SELECT COUNT(*) INTO v_joined_count
    FROM course_project.enrollments AS e
    JOIN course_project.students AS s
        ON e.student_id = s.id
    JOIN course_project.courses AS c
        ON e.course_id = c.id
    JOIN course_project.instructors AS i
        ON c.instructor_id = i.id;

    SELECT COUNT(*) INTO v_orphan_student_count
    FROM course_project.enrollments AS e
    LEFT JOIN course_project.students AS s
        ON e.student_id = s.id
    WHERE s.id IS NULL;

    SELECT COUNT(*) INTO v_orphan_course_count
    FROM course_project.enrollments AS e
    LEFT JOIN course_project.courses AS c
        ON e.course_id = c.id
    WHERE c.id IS NULL;

    SELECT COUNT(*) INTO v_orphan_instructor_count
    FROM course_project.courses AS c
    LEFT JOIN course_project.instructors AS i
        ON c.instructor_id = i.id
    WHERE i.id IS NULL;

    SELECT COUNT(*) INTO v_anti_join_left_count
    FROM course_project.students AS s
    LEFT JOIN course_project.enrollments AS e
        ON s.id = e.student_id
       AND e.status <> '취소'
    WHERE e.id IS NULL;

    SELECT COUNT(*) INTO v_anti_join_exists_count
    FROM course_project.students AS s
    WHERE NOT EXISTS (
        SELECT 1
        FROM course_project.enrollments AS e
        WHERE e.student_id = s.id
          AND e.status <> '취소'
    );

    SELECT COUNT(*) INTO v_on_student_count
    FROM (
        SELECT s.id
        FROM course_project.students AS s
        LEFT JOIN course_project.enrollments AS e
            ON s.id = e.student_id
           AND e.status <> '취소'
        GROUP BY s.id
    ) AS on_students;

    SELECT COUNT(*) INTO v_where_student_count
    FROM (
        SELECT s.id
        FROM course_project.students AS s
        LEFT JOIN course_project.enrollments AS e
            ON s.id = e.student_id
        WHERE e.status <> '취소'
        GROUP BY s.id
    ) AS where_students;

    SELECT COUNT(e.id), COUNT(DISTINCT e.student_id), COALESCE(SUM(e.recorded_amount), 0)
    INTO v_course301_count, v_course301_students, v_course301_total
    FROM course_project.courses AS c
    LEFT JOIN course_project.enrollments AS e
        ON c.id = e.course_id
       AND e.status <> '취소'
    WHERE c.id = 301
    GROUP BY c.id;

    SELECT COUNT(e.id), COUNT(DISTINCT e.student_id), COALESCE(SUM(e.recorded_amount), 0)
    INTO v_course302_count, v_course302_students, v_course302_total
    FROM course_project.courses AS c
    LEFT JOIN course_project.enrollments AS e
        ON c.id = e.course_id
       AND e.status <> '취소'
    WHERE c.id = 302
    GROUP BY c.id;

    SELECT COUNT(*), COUNT(e.id), COUNT(DISTINCT e.student_id), COALESCE(SUM(e.recorded_amount), 0)
    INTO v_course303_joined_rows, v_course303_count, v_course303_students, v_course303_total
    FROM course_project.courses AS c
    LEFT JOIN course_project.enrollments AS e
        ON c.id = e.course_id
       AND e.status <> '취소'
    WHERE c.id = 303
    GROUP BY c.id;

    SELECT
        COUNT(DISTINCT c.id),
        COUNT(e.id),
        COUNT(e.id) FILTER (WHERE e.status <> '취소')
    INTO v_instructor201_courses, v_instructor201_enrollments, v_instructor201_non_cancelled
    FROM course_project.instructors AS i
    LEFT JOIN course_project.courses AS c
        ON i.id = c.instructor_id
    LEFT JOIN course_project.enrollments AS e
        ON c.id = e.course_id
    WHERE i.id = 201
    GROUP BY i.id;

    SELECT
        COUNT(DISTINCT c.id),
        COUNT(e.id),
        COUNT(e.id) FILTER (WHERE e.status <> '취소')
    INTO v_instructor202_courses, v_instructor202_enrollments, v_instructor202_non_cancelled
    FROM course_project.instructors AS i
    LEFT JOIN course_project.courses AS c
        ON i.id = c.instructor_id
    LEFT JOIN course_project.enrollments AS e
        ON c.id = e.course_id
    WHERE i.id = 202
    GROUP BY i.id;

    SELECT COUNT(*) INTO v_having_course_count
    FROM (
        SELECT c.id
        FROM course_project.courses AS c
        JOIN course_project.enrollments AS e ON c.id = e.course_id
        WHERE e.status <> '취소'
        GROUP BY c.id
        HAVING COUNT(e.id) >= 2
    ) AS having_courses;

    SELECT COALESCE(SUM(c.price), 0) INTO v_instructor201_wrong_price_sum
    FROM course_project.instructors AS i
    JOIN course_project.courses AS c ON i.id = c.instructor_id
    JOIN course_project.enrollments AS e ON c.id = e.course_id
    WHERE i.id = 201;

    SELECT COALESCE(SUM(price), 0) INTO v_instructor201_correct_price_sum
    FROM course_project.courses WHERE instructor_id = 201;

    SELECT COALESCE(SUM(c.price), 0) INTO v_instructor202_wrong_price_sum
    FROM course_project.instructors AS i
    JOIN course_project.courses AS c ON i.id = c.instructor_id
    JOIN course_project.enrollments AS e ON c.id = e.course_id
    WHERE i.id = 202;

    SELECT COALESCE(SUM(price), 0) INTO v_instructor202_correct_price_sum
    FROM course_project.courses WHERE instructor_id = 202;

    IF v_detail_count <> 5
       OR v_grouped_count <> 5
       OR v_detail_total <> 590000
       OR v_grouped_total <> 590000
       OR v_active_count <> 3
       OR v_active_total <> 340000
       OR v_grouped_active_count <> 3
       OR v_grouped_active_total <> 340000
       OR v_non_cancelled_count <> 4
       OR v_non_cancelled_total <> 440000
       OR v_grouped_non_cancelled_count <> 4
       OR v_grouped_non_cancelled_total <> 440000
       OR v_joined_count <> 5
       OR v_orphan_student_count <> 0
       OR v_orphan_course_count <> 0
       OR v_orphan_instructor_count <> 0
       OR v_anti_join_left_count <> 1
       OR v_anti_join_exists_count <> 1
       OR v_on_student_count <> 3
       OR v_where_student_count <> 2
       OR v_course301_count <> 2
       OR v_course301_students <> 2
       OR v_course301_total <> 200000
       OR v_course302_count <> 2
       OR v_course302_students <> 2
       OR v_course302_total <> 240000
       OR v_course303_joined_rows <> 1
       OR v_course303_count <> 0
       OR v_course303_students <> 0
       OR v_course303_total <> 0
       OR v_instructor201_courses <> 2
       OR v_instructor201_enrollments <> 4
       OR v_instructor201_non_cancelled <> 4
       OR v_instructor202_courses <> 1
       OR v_instructor202_enrollments <> 1
       OR v_instructor202_non_cancelled <> 0 THEN
        RAISE EXCEPTION
            'Chapter 08 검증 실패: detail=%/% grouped=%/%, active=%/% grouped_active=%/%, non_cancelled=%/% grouped_non_cancelled=%/%, join=%, orphan=%/%/%, anti=%/%, on_where=%/%, c301=%/%/%, c302=%/%/%, c303=%/%/%/%, i201=%/%/%, i202=%/%/%',
            v_detail_count,
            v_detail_total,
            v_grouped_count,
            v_grouped_total,
            v_active_count,
            v_active_total,
            v_grouped_active_count,
            v_grouped_active_total,
            v_non_cancelled_count,
            v_non_cancelled_total,
            v_grouped_non_cancelled_count,
            v_grouped_non_cancelled_total,
            v_joined_count,
            v_orphan_student_count,
            v_orphan_course_count,
            v_orphan_instructor_count,
            v_anti_join_left_count,
            v_anti_join_exists_count,
            v_on_student_count,
            v_where_student_count,
            v_course301_count,
            v_course301_students,
            v_course301_total,
            v_course302_count,
            v_course302_students,
            v_course302_total,
            v_course303_joined_rows,
            v_course303_count,
            v_course303_students,
            v_course303_total,
            v_instructor201_courses,
            v_instructor201_enrollments,
            v_instructor201_non_cancelled,
            v_instructor202_courses,
            v_instructor202_enrollments,
            v_instructor202_non_cancelled;
    END IF;

    IF v_having_course_count <> 2
       OR v_instructor201_wrong_price_sum <> 440000
       OR v_instructor201_correct_price_sum <> 220000
       OR v_instructor202_wrong_price_sum <> 150000
       OR v_instructor202_correct_price_sum <> 150000 THEN
        RAISE EXCEPTION
            'Chapter 08 HAVING/과대 집계 검증 실패: having=%, i201_wrong/correct=%/%, i202_wrong/correct=%/%',
            v_having_course_count,
            v_instructor201_wrong_price_sum,
            v_instructor201_correct_price_sum,
            v_instructor202_wrong_price_sum,
            v_instructor202_correct_price_sum;
    END IF;

    RAISE NOTICE 'Chapter 08 join and aggregation validation passed';
END
$$;

-- 검산 결과를 사람이 다시 확인할 수 있도록 요약 조회를 함께 제공합니다.
SELECT
    COUNT(*) AS total_enrollments,
    SUM(recorded_amount) AS total_recorded_amount,
    COUNT(*) FILTER (WHERE status IN ('신청', '수강중')) AS active_enrollments,
    SUM(recorded_amount) FILTER (WHERE status IN ('신청', '수강중')) AS active_recorded_amount,
    COUNT(*) FILTER (WHERE status <> '취소') AS non_cancelled_enrollments,
    SUM(recorded_amount) FILTER (WHERE status <> '취소') AS non_cancelled_recorded_amount
FROM course_project.enrollments;

SELECT
    status,
    COUNT(*) AS enrollment_count,
    SUM(recorded_amount) AS recorded_amount_total
FROM course_project.enrollments
GROUP BY status
ORDER BY CASE status
    WHEN '신청' THEN 1
    WHEN '수강중' THEN 2
    WHEN '완료' THEN 3
    WHEN '취소' THEN 4
    ELSE 99
END;