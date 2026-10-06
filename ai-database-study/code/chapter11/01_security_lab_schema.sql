-- Chapter 11. security_lab 스키마 생성
-- 목적: 기존 프로젝트를 보호하면서 권한·백업·복원 검증용 테이블을 만듭니다.
-- 주의: 기존 스키마나 테이블을 자동으로 삭제하지 않습니다.

SELECT current_user AS current_user_name;
SELECT current_database();
SELECT current_schema();
SHOW search_path;
SELECT current_setting('server_version') AS postgresql_version;

-- ============================================================
-- 0. 실행 전 보호 조건
-- Chapter 07·08에서 확정한 course_project 기준 상태를 확인합니다.
-- ============================================================
DO $$
DECLARE
    v_student_count BIGINT;
    v_instructor_count BIGINT;
    v_course_count BIGINT;
    v_enrollment_count BIGINT;
    v_requested_count BIGINT;
    v_learning_count BIGINT;
    v_completed_count BIGINT;
    v_cancelled_count BIGINT;
    v_total_amount NUMERIC;
    v_active_count BIGINT;
    v_active_amount NUMERIC;
    v_non_cancelled_count BIGINT;
    v_non_cancelled_amount NUMERIC;
    v_project_named_constraint_count BIGINT;
    v_project_not_null_count BIGINT;
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '실행 중단: 현재 데이터베이스는 %입니다. ai_database_book에 연결하세요.',
            current_database();
    END IF;

    IF current_setting('transaction_read_only')::boolean THEN
        RAISE EXCEPTION '실행 중단: 읽기 전용 연결에서는 security_lab을 만들 수 없습니다.';
    END IF;

    IF to_regclass('course_project.students') IS NULL
       OR to_regclass('course_project.instructors') IS NULL
       OR to_regclass('course_project.courses') IS NULL
       OR to_regclass('course_project.enrollments') IS NULL THEN
        RAISE EXCEPTION
            '실행 중단: Chapter 07·08의 course_project 핵심 테이블이 없습니다.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'course_project'
          AND table_name = 'enrollments'
          AND column_name = 'recorded_amount'
          AND data_type = 'numeric'
          AND numeric_precision = 12
          AND numeric_scale = 0
    ) THEN
        RAISE EXCEPTION
            '실행 중단: course_project.enrollments.recorded_amount는 NUMERIC(12,0)이어야 합니다.';
    END IF;

    SELECT COUNT(*) INTO v_student_count FROM course_project.students;
    SELECT COUNT(*) INTO v_instructor_count FROM course_project.instructors;
    SELECT COUNT(*) INTO v_course_count FROM course_project.courses;
    SELECT COUNT(*) INTO v_enrollment_count FROM course_project.enrollments;

    SELECT
        COUNT(*) FILTER (WHERE status = '신청'),
        COUNT(*) FILTER (WHERE status = '수강중'),
        COUNT(*) FILTER (WHERE status = '완료'),
        COUNT(*) FILTER (WHERE status = '취소'),
        COALESCE(SUM(recorded_amount), 0),
        COUNT(*) FILTER (WHERE status IN ('신청', '수강중')),
        COALESCE(SUM(recorded_amount) FILTER (WHERE status IN ('신청', '수강중')), 0),
        COUNT(*) FILTER (WHERE status <> '취소'),
        COALESCE(SUM(recorded_amount) FILTER (WHERE status <> '취소'), 0)
    INTO
        v_requested_count,
        v_learning_count,
        v_completed_count,
        v_cancelled_count,
        v_total_amount,
        v_active_count,
        v_active_amount,
        v_non_cancelled_count,
        v_non_cancelled_amount
    FROM course_project.enrollments;

    IF v_student_count <> 3
       OR v_instructor_count <> 2
       OR v_course_count <> 3
       OR v_enrollment_count <> 5
       OR v_requested_count <> 2
       OR v_learning_count <> 1
       OR v_completed_count <> 1
       OR v_cancelled_count <> 1
       OR v_total_amount <> 590000
       OR v_active_count <> 3
       OR v_active_amount <> 340000
       OR v_non_cancelled_count <> 4
       OR v_non_cancelled_amount <> 440000 THEN
        RAISE EXCEPTION
            '실행 중단: Chapter 07·08 기준 상태가 아닙니다. rows=%/%/%/%, status=%/%/%/%, amount=%/%/%',
            v_student_count, v_instructor_count, v_course_count, v_enrollment_count,
            v_requested_count, v_learning_count, v_completed_count, v_cancelled_count,
            v_total_amount, v_active_amount, v_non_cancelled_amount;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM course_project.enrollments
        WHERE id = 1001 AND status = '완료' AND recorded_amount = 100000
    ) OR NOT EXISTS (
        SELECT 1
        FROM course_project.enrollments
        WHERE id = 1004 AND status = '취소' AND recorded_amount = 150000
    ) OR NOT EXISTS (
        SELECT 1
        FROM course_project.enrollments
        WHERE id = 1005 AND status = '신청' AND recorded_amount = 120000
    ) THEN
        RAISE EXCEPTION '실행 중단: Chapter 07의 기준 신청 1001·1004·1005 상태가 다릅니다.';
    END IF;

    IF to_regclass('course_project.uq_course_enrollments_active') IS NULL THEN
        RAISE EXCEPTION '실행 중단: course_project 활성 신청 부분 고유 인덱스가 없습니다.';
    END IF;

    IF NOT has_database_privilege(current_user, current_database(), 'CREATE') THEN
        RAISE EXCEPTION
            '실행 중단: 현재 역할 %에는 데이터베이스 %의 CREATE 권한이 없습니다.',
            current_user, current_database();
    END IF;

    SELECT COUNT(*) INTO v_project_named_constraint_count
    FROM pg_constraint
    WHERE conrelid IN (
        'course_project.students'::regclass,
        'course_project.instructors'::regclass,
        'course_project.courses'::regclass,
        'course_project.enrollments'::regclass
    )
      AND conname IN (
        'uq_course_students_email',
        'chk_course_students_name_not_blank',
        'chk_course_students_email_not_blank',
        'uq_course_instructors_email',
        'chk_course_instructors_name_not_blank',
        'chk_course_instructors_email_not_blank',
        'chk_course_instructors_specialty_not_blank',
        'fk_course_courses_instructor',
        'chk_course_courses_title_not_blank',
        'chk_course_courses_level',
        'chk_course_courses_price',
        'fk_course_enrollments_student',
        'fk_course_enrollments_course',
        'chk_course_enrollments_status',
        'chk_course_enrollments_recorded_amount'
      );

    SELECT COUNT(*) INTO v_project_not_null_count
    FROM information_schema.columns
    WHERE table_schema = 'course_project'
      AND table_name IN ('students', 'instructors', 'courses', 'enrollments')
      AND is_nullable = 'NO';

    IF v_project_named_constraint_count <> 15 OR v_project_not_null_count <> 20 THEN
        RAISE EXCEPTION
            '실행 중단: Chapter 07 구조 기준과 다릅니다. named_constraints=%, not_null_columns=%',
            v_project_named_constraint_count, v_project_not_null_count;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_namespace
        WHERE nspname = 'security_lab'
    ) THEN
        RAISE EXCEPTION
            '실행 중단: security_lab 스키마가 이미 존재합니다. 보존 여부를 확인한 뒤 reset_security_lab.sql 사용을 검토하세요.';
    END IF;
END
$$;

-- ============================================================
-- 1. 스키마와 테이블 생성
-- 중간 실패 시 일부 객체만 남지 않도록 하나의 트랜잭션으로 처리합니다.
-- ============================================================
BEGIN;

CREATE SCHEMA security_lab;

CREATE TABLE security_lab.students (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    joined_at DATE NOT NULL,

    CONSTRAINT uq_security_students_email
        UNIQUE (email),

    CONSTRAINT chk_security_students_name_not_blank
        CHECK (char_length(trim(name)) > 0),

    CONSTRAINT chk_security_students_email_not_blank
        CHECK (char_length(trim(email)) > 0)
);

CREATE TABLE security_lab.courses (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    level VARCHAR(20) NOT NULL,
    price INTEGER NOT NULL,

    CONSTRAINT chk_security_courses_title_not_blank
        CHECK (char_length(trim(title)) > 0),

    CONSTRAINT chk_security_courses_level
        CHECK (level IN ('basic', 'intermediate', 'advanced')),

    CONSTRAINT chk_security_courses_price
        CHECK (price >= 0)
);

CREATE TABLE security_lab.enrollments (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    student_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL,
    recorded_amount NUMERIC(12,0) NOT NULL,
    enrolled_at DATE NOT NULL,

    CONSTRAINT fk_security_enrollments_student
        FOREIGN KEY (student_id)
        REFERENCES security_lab.students(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_security_enrollments_course
        FOREIGN KEY (course_id)
        REFERENCES security_lab.courses(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_security_enrollments_status
        CHECK (status IN ('신청', '수강중', '완료', '취소')),

    CONSTRAINT chk_security_enrollments_recorded_amount
        CHECK (recorded_amount >= 0)
);

-- Chapter 07에서 확정한 정책을 유지합니다.
-- 완료·취소 이력은 여러 건 허용하지만 진행 중 신청은 학생·강의당 한 건입니다.
CREATE UNIQUE INDEX uq_security_enrollments_active
ON security_lab.enrollments (student_id, course_id)
WHERE status IN ('신청', '수강중');

-- COMMIT 전에 구조 자체를 자동 판정합니다.
DO $$
DECLARE
    v_table_count INTEGER;
    v_constraint_count INTEGER;
    v_not_null_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_table_count
    FROM information_schema.tables
    WHERE table_schema = 'security_lab'
      AND table_name IN ('students', 'courses', 'enrollments');

    SELECT COUNT(*) INTO v_constraint_count
    FROM pg_constraint
    WHERE connamespace = 'security_lab'::regnamespace
      AND conname IN (
          'students_pkey',
          'uq_security_students_email',
          'chk_security_students_name_not_blank',
          'chk_security_students_email_not_blank',
          'courses_pkey',
          'chk_security_courses_title_not_blank',
          'chk_security_courses_level',
          'chk_security_courses_price',
          'enrollments_pkey',
          'fk_security_enrollments_student',
          'fk_security_enrollments_course',
          'chk_security_enrollments_status',
          'chk_security_enrollments_recorded_amount'
      );

    SELECT COUNT(*) INTO v_not_null_count
    FROM information_schema.columns
    WHERE table_schema = 'security_lab'
      AND table_name IN ('students', 'courses', 'enrollments')
      AND is_nullable = 'NO';

    IF v_table_count <> 3
       OR v_constraint_count <> 13
       OR v_not_null_count <> 14
       OR NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'security_lab'
              AND table_name = 'enrollments'
              AND column_name = 'recorded_amount'
              AND data_type = 'numeric'
              AND numeric_precision = 12
              AND numeric_scale = 0
       )
       OR EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'security_lab'
              AND table_name = 'enrollments'
              AND column_name = 'paid_amount'
       )
       OR NOT EXISTS (
            SELECT 1
            FROM pg_index AS i
            JOIN pg_class AS c ON c.oid = i.indexrelid
            JOIN pg_namespace AS n ON n.oid = c.relnamespace
            WHERE n.nspname = 'security_lab'
              AND c.relname = 'uq_security_enrollments_active'
              AND i.indisunique
              AND i.indisvalid
              AND i.indisready
       )
       OR (SELECT COUNT(*) FROM security_lab.students) <> 0
       OR (SELECT COUNT(*) FROM security_lab.courses) <> 0
       OR (SELECT COUNT(*) FROM security_lab.enrollments) <> 0 THEN
        RAISE EXCEPTION
            '스키마 생성 검증 실패: tables %, constraints %, not-null %.',
            v_table_count, v_constraint_count, v_not_null_count;
    END IF;

    RAISE NOTICE 'Chapter 11 security lab schema validation passed';
END
$$;

COMMIT;

-- ============================================================
-- 2. 생성 결과 확인
-- ============================================================
SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'security_lab'
ORDER BY table_name;

SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'security_lab'
ORDER BY tablename, indexname;