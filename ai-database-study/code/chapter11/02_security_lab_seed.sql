-- Chapter 11. security_lab 정상 샘플 데이터
-- 실행 전 01_security_lab_schema.sql을 먼저 실행합니다.
-- 관계를 쉽게 재현하기 위해 명시적 ID를 사용하고 마지막에 IDENTITY 시작값을 조정합니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;

-- ============================================================
-- 0. 실행 전 상태 확인
-- ============================================================
DO $$
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '실행 중단: 현재 데이터베이스는 %입니다.',
            current_database();
    END IF;

    IF current_setting('transaction_read_only')::boolean THEN
        RAISE EXCEPTION '실행 중단: 읽기 전용 연결에서는 샘플 데이터를 만들 수 없습니다.';
    END IF;

    IF to_regclass('security_lab.students') IS NULL
       OR to_regclass('security_lab.courses') IS NULL
       OR to_regclass('security_lab.enrollments') IS NULL
       OR to_regclass('security_lab.uq_security_enrollments_active') IS NULL THEN
        RAISE EXCEPTION
            '실행 중단: security_lab 핵심 객체가 없습니다. 01 파일을 먼저 실행하세요.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'security_lab'
          AND table_name = 'enrollments'
          AND column_name = 'recorded_amount'
          AND data_type = 'numeric'
          AND numeric_precision = 12
          AND numeric_scale = 0
    ) OR EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'security_lab'
          AND table_name = 'enrollments'
          AND column_name = 'paid_amount'
    ) THEN
        RAISE EXCEPTION
            '실행 중단: enrollments 금액 열은 recorded_amount NUMERIC(12,0)이어야 합니다.';
    END IF;

    IF (SELECT COUNT(*) FROM security_lab.students) <> 0
       OR (SELECT COUNT(*) FROM security_lab.courses) <> 0
       OR (SELECT COUNT(*) FROM security_lab.enrollments) <> 0 THEN
        RAISE EXCEPTION
            '실행 중단: security_lab 테이블은 비어 있어야 합니다. 기존 데이터를 확인하세요.';
    END IF;
END
$$;

BEGIN;

INSERT INTO security_lab.students (id, name, email, joined_at)
VALUES
    (101, '김민지', 'minji.security@example.com', '2026-03-01'),
    (102, '이준호', 'junho.security@example.com', '2026-03-03'),
    (103, '박서연', 'seoyeon.security@example.com', '2026-03-05');

INSERT INTO security_lab.courses (id, title, level, price)
VALUES
    (201, '데이터베이스 보안 기초', 'basic', 100000),
    (202, '백업과 복구 이해', 'basic', 120000),
    (203, '권한 관리 입문', 'basic', 90000);

-- recorded_amount는 결제 승인액·정산 매출이 아니라 신청 행에 기록한 금액입니다.
INSERT INTO security_lab.enrollments (
    id,
    student_id,
    course_id,
    status,
    recorded_amount,
    enrolled_at
)
VALUES
    (1001, 101, 201, '수강중', 100000, '2026-04-01'),
    (1002, 102, 202, '신청', 120000, '2026-04-02'),
    (1003, 103, 203, '완료', 90000, '2026-04-03');

-- 명시적 ID 입력은 IDENTITY 내부 시퀀스의 다음 값을 자동으로 이동시키지 않습니다.
ALTER TABLE security_lab.students
    ALTER COLUMN id RESTART WITH 104;

ALTER TABLE security_lab.courses
    ALTER COLUMN id RESTART WITH 204;

ALTER TABLE security_lab.enrollments
    ALTER COLUMN id RESTART WITH 1004;

-- COMMIT 전 기준 상태를 자동 판정합니다.
DO $$
DECLARE
    v_join_count BIGINT;
    v_requested_count BIGINT;
    v_learning_count BIGINT;
    v_completed_count BIGINT;
    v_cancelled_count BIGINT;
    v_total_amount NUMERIC;
    v_active_count BIGINT;
    v_duplicate_active_pair_count BIGINT;
    v_amount_mismatch BIGINT;
    v_students_next BIGINT;
    v_courses_next BIGINT;
    v_enrollments_next BIGINT;
BEGIN
    IF (SELECT COUNT(*) FROM security_lab.students) <> 3
       OR (SELECT COUNT(*) FROM security_lab.courses) <> 3
       OR (SELECT COUNT(*) FROM security_lab.enrollments) <> 3 THEN
        RAISE EXCEPTION
            '샘플 입력 중단: 기준 행 수가 예상과 다릅니다.';
    END IF;

    SELECT COUNT(*) INTO v_join_count
    FROM security_lab.enrollments AS e
    JOIN security_lab.students AS s ON s.id = e.student_id
    JOIN security_lab.courses AS c ON c.id = e.course_id;

    SELECT
        COUNT(*) FILTER (WHERE status = '신청'),
        COUNT(*) FILTER (WHERE status = '수강중'),
        COUNT(*) FILTER (WHERE status = '완료'),
        COUNT(*) FILTER (WHERE status = '취소'),
        COALESCE(SUM(recorded_amount), 0),
        COUNT(*) FILTER (WHERE status IN ('신청', '수강중'))
    INTO
        v_requested_count,
        v_learning_count,
        v_completed_count,
        v_cancelled_count,
        v_total_amount,
        v_active_count
    FROM security_lab.enrollments;

    SELECT COUNT(*)
    INTO v_duplicate_active_pair_count
    FROM (
        SELECT student_id, course_id
        FROM security_lab.enrollments
        WHERE status IN ('신청', '수강중')
        GROUP BY student_id, course_id
        HAVING COUNT(*) > 1
    ) AS duplicated_active_pairs;

    SELECT COUNT(*)
    INTO v_amount_mismatch
    FROM security_lab.enrollments AS e
    JOIN security_lab.courses AS c ON c.id = e.course_id
    WHERE e.recorded_amount <> c.price;

    SELECT CASE WHEN is_called THEN last_value + 1 ELSE last_value END
    INTO v_students_next
    FROM security_lab.students_id_seq;

    SELECT CASE WHEN is_called THEN last_value + 1 ELSE last_value END
    INTO v_courses_next
    FROM security_lab.courses_id_seq;

    SELECT CASE WHEN is_called THEN last_value + 1 ELSE last_value END
    INTO v_enrollments_next
    FROM security_lab.enrollments_id_seq;

    IF v_join_count <> 3
       OR v_requested_count <> 1
       OR v_learning_count <> 1
       OR v_completed_count <> 1
       OR v_cancelled_count <> 0
       OR v_total_amount <> 310000
       OR v_active_count <> 2
       OR v_duplicate_active_pair_count <> 0
       OR v_amount_mismatch <> 0
       OR v_students_next <> 104
       OR v_courses_next <> 204
       OR v_enrollments_next <> 1004 THEN
        RAISE EXCEPTION
            '샘플 입력 검증 실패: join %, status=%/%/%/%, total %, active %, dup %, amount mismatch %, next=%/%/%.',
            v_join_count,
            v_requested_count, v_learning_count, v_completed_count, v_cancelled_count,
            v_total_amount, v_active_count, v_duplicate_active_pair_count,
            v_amount_mismatch,
            v_students_next, v_courses_next, v_enrollments_next;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM security_lab.enrollments
        WHERE id = 1001 AND student_id = 101 AND course_id = 201
          AND status = '수강중' AND recorded_amount = 100000
    ) OR NOT EXISTS (
        SELECT 1 FROM security_lab.enrollments
        WHERE id = 1002 AND student_id = 102 AND course_id = 202
          AND status = '신청' AND recorded_amount = 120000
    ) OR NOT EXISTS (
        SELECT 1 FROM security_lab.enrollments
        WHERE id = 1003 AND student_id = 103 AND course_id = 203
          AND status = '완료' AND recorded_amount = 90000
    ) THEN
        RAISE EXCEPTION '샘플 입력 검증 실패: 기준 신청 1001·1002·1003 값이 다릅니다.';
    END IF;

    RAISE NOTICE 'Chapter 11 security lab seed validation passed';
END
$$;

COMMIT;

-- ============================================================
-- 1. 결과 확인
-- 기대: 3 / 3 / 3 / JOIN 3 / 총 recorded_amount 310000
-- ============================================================
SELECT COUNT(*) AS student_count
FROM security_lab.students;

SELECT COUNT(*) AS course_count
FROM security_lab.courses;

SELECT COUNT(*) AS enrollment_count
FROM security_lab.enrollments;

SELECT COUNT(*) AS joined_row_count
FROM security_lab.enrollments AS e
JOIN security_lab.students AS s
    ON s.id = e.student_id
JOIN security_lab.courses AS c
    ON c.id = e.course_id;

SELECT
    status,
    COUNT(*) AS enrollment_count,
    SUM(recorded_amount) AS recorded_amount
FROM security_lab.enrollments
GROUP BY status
ORDER BY CASE status
    WHEN '신청' THEN 1
    WHEN '수강중' THEN 2
    WHEN '완료' THEN 3
    WHEN '취소' THEN 4
    ELSE 5
END;

-- IDENTITY 다음 값은 104 / 204 / 1004입니다.
-- 권한 동작 테스트에서 nextval()을 호출한 뒤 ROLLBACK하면 번호 공백은 생길 수 있습니다.