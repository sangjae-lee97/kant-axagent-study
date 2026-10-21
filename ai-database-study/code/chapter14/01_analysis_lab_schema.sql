-- Chapter 14. SQL 데이터 분석과 Python 확장
-- 목적: analysis_lab 전용 스키마와 분석 기준 테이블을 생성합니다.
-- 주의: 기존 객체를 자동으로 삭제하지 않습니다.

SELECT current_database();
SELECT current_user;
SELECT current_schema();
SHOW search_path;

-- ============================================================
-- P14-V01. 실행 위치와 기존 객체 보호
-- ============================================================
DO $$
DECLARE
    status_requested BIGINT;
    status_learning BIGINT;
    status_completed BIGINT;
    status_cancelled BIGINT;
    project_named_constraint_count INTEGER;
    project_not_null_count INTEGER;
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '실행 중단: 현재 데이터베이스는 %입니다. ai_database_book에 연결하세요.',
            current_database();
    END IF;

    IF current_setting('transaction_read_only')::boolean THEN
        RAISE EXCEPTION '실행 중단: 현재 트랜잭션이 읽기 전용입니다. analysis_lab 생성이 가능한 연결을 사용하세요.';
    END IF;

    IF NOT has_database_privilege(current_user, current_database(), 'CREATE') THEN
        RAISE EXCEPTION
            '실행 중단: 사용자 %에게 데이터베이스 %의 CREATE 권한이 없습니다.',
            current_user, current_database();
    END IF;

    IF to_regclass('course_project.students') IS NULL
       OR to_regclass('course_project.instructors') IS NULL
       OR to_regclass('course_project.courses') IS NULL
       OR to_regclass('course_project.enrollments') IS NULL THEN
        RAISE EXCEPTION '실행 중단: Chapter 07·08 course_project 기준 상태가 없습니다.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'course_project'
          AND table_name = 'enrollments'
          AND column_name = 'recorded_amount'
          AND data_type = 'numeric'
          AND numeric_precision = 12 AND numeric_scale = 0
    ) THEN
        RAISE EXCEPTION '실행 중단: course_project.enrollments.recorded_amount는 NUMERIC(12,0)이어야 합니다.';
    END IF;

    SELECT COUNT(*)
    INTO project_named_constraint_count
    FROM pg_constraint
    WHERE conrelid IN (
        'course_project.students'::regclass,
        'course_project.instructors'::regclass,
        'course_project.courses'::regclass,
        'course_project.enrollments'::regclass
    )
      AND conname IN (
        'uq_course_students_email','chk_course_students_name_not_blank','chk_course_students_email_not_blank',
        'uq_course_instructors_email','chk_course_instructors_name_not_blank','chk_course_instructors_email_not_blank','chk_course_instructors_specialty_not_blank',
        'fk_course_courses_instructor','chk_course_courses_title_not_blank','chk_course_courses_level','chk_course_courses_price',
        'fk_course_enrollments_student','fk_course_enrollments_course','chk_course_enrollments_status','chk_course_enrollments_recorded_amount'
      );

    SELECT COUNT(*)
    INTO project_not_null_count
    FROM information_schema.columns
    WHERE table_schema = 'course_project'
      AND table_name IN ('students','instructors','courses','enrollments')
      AND is_nullable = 'NO';

    IF project_named_constraint_count <> 15 OR project_not_null_count <> 20 THEN
        RAISE EXCEPTION
            '실행 중단: Chapter 07 구조 계약은 명명 제약조건 15개 / NOT NULL 열 20개여야 하지만 현재 % / %입니다.',
            project_named_constraint_count, project_not_null_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
        WHERE schemaname = 'course_project'
          AND indexname = 'uq_course_enrollments_active'
          AND indexdef ILIKE 'CREATE UNIQUE INDEX%'
          AND indexdef ILIKE '%student_id%course_id%'
          AND indexdef ILIKE '%WHERE%status%신청%수강중%'
    ) THEN
        RAISE EXCEPTION '실행 중단: Chapter 07 활성 신청 부분 고유 인덱스 정의가 다릅니다.';
    END IF;

    SELECT COUNT(*) FILTER (WHERE status = '신청'),
           COUNT(*) FILTER (WHERE status = '수강중'),
           COUNT(*) FILTER (WHERE status = '완료'),
           COUNT(*) FILTER (WHERE status = '취소')
    INTO status_requested, status_learning, status_completed, status_cancelled
    FROM course_project.enrollments;

    IF (SELECT COUNT(*) FROM course_project.students) <> 3
       OR (SELECT COUNT(*) FROM course_project.instructors) <> 2
       OR (SELECT COUNT(*) FROM course_project.courses) <> 3
       OR (SELECT COUNT(*) FROM course_project.enrollments) <> 5
       OR status_requested <> 2 OR status_learning <> 1
       OR status_completed <> 1 OR status_cancelled <> 1
       OR (SELECT SUM(recorded_amount) FROM course_project.enrollments) <> 590000
       OR (SELECT SUM(recorded_amount) FROM course_project.enrollments WHERE status IN ('신청','수강중')) <> 340000
       OR (SELECT SUM(recorded_amount) FROM course_project.enrollments WHERE status <> '취소') <> 440000
       OR NOT EXISTS (SELECT 1 FROM course_project.enrollments WHERE id = 1001 AND status = '완료' AND recorded_amount = 100000)
       OR NOT EXISTS (SELECT 1 FROM course_project.enrollments WHERE id = 1004 AND status = '취소' AND recorded_amount = 150000)
       OR NOT EXISTS (SELECT 1 FROM course_project.enrollments WHERE id = 1005 AND status = '신청' AND recorded_amount = 120000) THEN
        RAISE EXCEPTION '실행 중단: Chapter 07·08 course_project canonical 기준 상태와 다릅니다.';
    END IF;

    IF to_regnamespace('analysis_lab') IS NOT NULL THEN
        RAISE EXCEPTION '실행 중단: analysis_lab이 이미 존재합니다. 보존 여부를 확인한 뒤 reset_analysis_lab.sql 사용을 검토하세요.';
    END IF;
END
$$;

-- ============================================================
-- 스키마·테이블·분석 기간 VIEW를 하나의 트랜잭션에서 생성
-- ============================================================
BEGIN;

CREATE SCHEMA analysis_lab;

CREATE TABLE analysis_lab.students (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    region VARCHAR(20) NOT NULL,
    joined_at DATE NOT NULL,

    CONSTRAINT chk_analysis_students_name_not_blank
        CHECK (char_length(trim(name)) > 0),
    CONSTRAINT chk_analysis_students_region
        CHECK (region IN ('서울', '경기', '부산', '대구'))
);

CREATE TABLE analysis_lab.instructors (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    specialty VARCHAR(50) NOT NULL,

    CONSTRAINT chk_analysis_instructors_name_not_blank
        CHECK (char_length(trim(name)) > 0),
    CONSTRAINT chk_analysis_instructors_specialty_not_blank
        CHECK (char_length(trim(specialty)) > 0)
);

CREATE TABLE analysis_lab.courses (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    instructor_id INTEGER NOT NULL,
    title VARCHAR(120) NOT NULL,
    category VARCHAR(30) NOT NULL,
    level VARCHAR(20) NOT NULL,
    price NUMERIC(12,0) NOT NULL,
    opened_at DATE NOT NULL,

    CONSTRAINT fk_analysis_courses_instructor
        FOREIGN KEY (instructor_id)
        REFERENCES analysis_lab.instructors(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_analysis_courses_title_not_blank
        CHECK (char_length(trim(title)) > 0),
    CONSTRAINT chk_analysis_courses_category
        CHECK (category IN ('Database', 'Python', 'Data Analysis', 'AI')),
    CONSTRAINT chk_analysis_courses_level
        CHECK (level IN ('basic', 'intermediate', 'advanced')),
    CONSTRAINT chk_analysis_courses_price
        CHECK (price >= 0)
);

CREATE TABLE analysis_lab.enrollments (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    student_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    enrolled_at DATE NOT NULL,
    status VARCHAR(20) NOT NULL,
    recorded_amount NUMERIC(12,0) NOT NULL,
    completed_at DATE,

    CONSTRAINT fk_analysis_enrollments_student
        FOREIGN KEY (student_id)
        REFERENCES analysis_lab.students(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_analysis_enrollments_course
        FOREIGN KEY (course_id)
        REFERENCES analysis_lab.courses(id)
        ON DELETE RESTRICT,

    -- 같은 날짜의 동일 원천 행이 중복 적재되는 것을 막는 수집 규칙입니다.
    CONSTRAINT uq_analysis_enrollments_student_course_date
        UNIQUE (student_id, course_id, enrolled_at),

    CONSTRAINT chk_analysis_enrollments_status
        CHECK (status IN ('신청', '수강중', '완료', '취소')),

    CONSTRAINT chk_analysis_enrollments_recorded_amount
        CHECK (recorded_amount >= 0),


    CONSTRAINT chk_analysis_enrollments_completion_state
        CHECK (
            (status = '완료' AND completed_at IS NOT NULL)
            OR
            (status <> '완료' AND completed_at IS NULL)
        ),

    CONSTRAINT chk_analysis_enrollments_completion_date
        CHECK (completed_at IS NULL OR completed_at >= enrolled_at)
);

-- Chapter 07에서 확정한 활성 신청 규칙을 유지합니다.
-- 신청·수강중은 학생·강의 조합당 최대 한 건이며 완료·취소 이력 뒤 재신청은 허용합니다.
CREATE UNIQUE INDEX uq_analysis_enrollments_active
ON analysis_lab.enrollments (student_id, course_id)
WHERE status IN ('신청', '수강중');

-- 모든 SQL과 Python 분석이 같은 반개방 기간을 사용하도록 한 곳에 고정합니다.
CREATE VIEW analysis_lab.analysis_parameters AS
SELECT
    DATE '2026-01-01' AS start_date,
    DATE '2026-07-01' AS end_date_exclusive;

COMMIT;

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'analysis_lab' AND table_type = 'BASE TABLE') <> 4
       OR (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'analysis_lab') <> 1 THEN
        RAISE EXCEPTION 'Chapter 14 schema creation validation failed.';
    END IF;
    RAISE NOTICE 'Chapter 14 analysis lab schema validation passed';
END
$$;

-- 생성 결과 확인
SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'analysis_lab'
  AND table_type = 'BASE TABLE'
ORDER BY table_name;

SELECT
    table_schema,
    table_name
FROM information_schema.views
WHERE table_schema = 'analysis_lab'
ORDER BY table_name;

SELECT *
FROM analysis_lab.analysis_parameters;

-- DBeaver 탐색 위치:
-- Schemas -> analysis_lab -> Tables / Views