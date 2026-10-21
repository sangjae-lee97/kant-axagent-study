-- Chapter 14. SQL 데이터 분석과 Python 확장
-- 목적: 기간·상태·지역·강의별 분석이 가능한 기준 데이터를 입력합니다.
-- 실행 전 01_analysis_lab_schema.sql을 먼저 실행합니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;

-- ============================================================
-- 실행 전 상태 확인
-- ============================================================
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
            '실행 중단: analysis_lab 핵심 객체가 없습니다. 01 파일을 먼저 실행하세요.';
    END IF;

    IF (SELECT COUNT(*) FROM analysis_lab.students) <> 0
       OR (SELECT COUNT(*) FROM analysis_lab.instructors) <> 0
       OR (SELECT COUNT(*) FROM analysis_lab.courses) <> 0
       OR (SELECT COUNT(*) FROM analysis_lab.enrollments) <> 0 THEN
        RAISE EXCEPTION
            '실행 중단: 기준 테이블은 모두 비어 있어야 합니다. 기존 데이터를 확인하세요.';
    END IF;
END
$$;

BEGIN;

INSERT INTO analysis_lab.students (id, name, region, joined_at)
VALUES
    (101, '김민지', '서울', '2026-01-05'),
    (102, '이준호', '경기', '2026-01-12'),
    (103, '박서연', '부산', '2026-02-02'),
    (104, '최유진', '서울', '2026-02-10'),
    (105, '정우성', '대구', '2026-03-01'),
    (106, '한지민', '경기', '2026-03-05'),
    (107, '윤서준', '부산', '2026-04-05'),
    (108, '강하늘', '서울', '2026-05-01');

INSERT INTO analysis_lab.instructors (id, name, specialty)
VALUES
    (201, '문길래', 'Database'),
    (202, '홍길동', 'Python'),
    (203, '김하나', 'Data Analysis');

INSERT INTO analysis_lab.courses (
    id,
    instructor_id,
    title,
    category,
    level,
    price,
    opened_at
)
VALUES
    (301, 201, '데이터베이스 입문', 'Database', 'basic', 100000, '2026-01-01'),
    (302, 201, 'SQL 데이터 분석', 'Database', 'intermediate', 130000, '2026-02-01'),
    (303, 202, '파이썬 데이터 분석', 'Python', 'basic', 150000, '2026-01-15'),
    (304, 203, '데이터 시각화', 'Data Analysis', 'intermediate', 140000, '2026-02-15'),
    (305, 203, 'AI 활용 데이터 설계', 'AI', 'intermediate', 160000, '2026-03-01');

INSERT INTO analysis_lab.enrollments (
    id,
    student_id,
    course_id,
    enrolled_at,
    status,
    recorded_amount,
    completed_at
)
VALUES
    (1001, 101, 301, '2026-01-10', '완료',   100000, '2026-01-30'),
    (1002, 102, 301, '2026-01-18', '완료',   100000, '2026-02-05'),
    (1003, 101, 303, '2026-01-25', '취소',   150000, NULL),

    (1004, 103, 301, '2026-02-05', '완료',   100000, '2026-02-28'),
    (1005, 104, 302, '2026-02-12', '수강중', 130000, NULL),
    (1006, 102, 303, '2026-02-20', '완료',   150000, '2026-03-20'),
    (1007, 103, 304, '2026-02-25', '신청',   140000, NULL),

    (1008, 105, 301, '2026-03-03', '완료',   100000, '2026-03-28'),
    (1009, 106, 302, '2026-03-08', '완료',   130000, '2026-04-05'),
    (1010, 104, 303, '2026-03-15', '완료',   150000, '2026-04-20'),
    (1011, 105, 304, '2026-03-22', '취소',   140000, NULL),
    (1012, 101, 305, '2026-03-28', '수강중', 160000, NULL),

    (1013, 107, 301, '2026-04-08', '완료',   100000, '2026-05-01'),
    (1014, 106, 303, '2026-04-12', '수강중', 150000, NULL),
    (1015, 107, 304, '2026-04-18', '완료',   140000, '2026-05-15'),
    (1016, 103, 305, '2026-04-25', '신청',   160000, NULL),

    (1017, 108, 301, '2026-05-03', '수강중', 100000, NULL),
    (1018, 104, 302, '2026-05-10', '완료',   130000, '2026-06-01'),
    (1019, 108, 303, '2026-05-17', '취소',   150000, NULL),
    (1020, 105, 305, '2026-05-24', '완료',   160000, '2026-06-20'),

    (1021, 107, 302, '2026-06-02', '신청',   130000, NULL),
    (1022, 108, 304, '2026-06-08', '완료',   140000, '2026-07-01'),
    (1023, 102, 305, '2026-06-15', '수강중', 160000, NULL),
    (1024, 106, 304, '2026-06-22', '신청',   140000, NULL);

-- 명시적 ID 입력 뒤 자동값이 기존 PK와 충돌하지 않도록 다음 값을 조정합니다.
ALTER TABLE analysis_lab.students
    ALTER COLUMN id RESTART WITH 109;

ALTER TABLE analysis_lab.instructors
    ALTER COLUMN id RESTART WITH 204;

ALTER TABLE analysis_lab.courses
    ALTER COLUMN id RESTART WITH 306;

ALTER TABLE analysis_lab.enrollments
    ALTER COLUMN id RESTART WITH 1025;

-- COMMIT 전 기준 상태 자동 판정
DO $$
DECLARE
    active_duplicate_count BIGINT;
    temporal_issue_count BIGINT;
BEGIN
    IF (SELECT COUNT(*) FROM analysis_lab.students) <> 8
       OR (SELECT COUNT(*) FROM analysis_lab.instructors) <> 3
       OR (SELECT COUNT(*) FROM analysis_lab.courses) <> 5
       OR (SELECT COUNT(*) FROM analysis_lab.enrollments) <> 24 THEN
        RAISE EXCEPTION
            'Seed 중단: 기준 행 수 8/3/5/24와 일치하지 않습니다.';
    END IF;

    IF (SELECT SUM(recorded_amount) FROM analysis_lab.enrollments) <> 3210000 THEN
        RAISE EXCEPTION
            'Seed 중단: 신청 시점 기록 금액 합계가 3,210,000이 아닙니다.';
    END IF;

    IF (
        SELECT COUNT(*)
        FROM analysis_lab.enrollments
        WHERE status = '완료'
    ) <> 12 THEN
        RAISE EXCEPTION
            'Seed 중단: 완료 상태는 12건이어야 합니다.';
    END IF;

    SELECT COUNT(*)
    INTO active_duplicate_count
    FROM (
        SELECT student_id, course_id
        FROM analysis_lab.enrollments
        WHERE status IN ('신청', '수강중')
        GROUP BY student_id, course_id
        HAVING COUNT(*) > 1
    ) AS duplicated_active_pairs;

    IF active_duplicate_count <> 0 THEN
        RAISE EXCEPTION
            'Seed 중단: 활성 신청 중복 조합이 %건 있습니다.',
            active_duplicate_count;
    END IF;

    SELECT
        (SELECT COUNT(*)
         FROM analysis_lab.enrollments AS e
         JOIN analysis_lab.students AS s ON s.id = e.student_id
         WHERE e.enrolled_at < s.joined_at)
      + (SELECT COUNT(*)
         FROM analysis_lab.enrollments AS e
         JOIN analysis_lab.courses AS c ON c.id = e.course_id
         WHERE e.enrolled_at < c.opened_at)
      + (SELECT COUNT(*)
         FROM analysis_lab.enrollments
         WHERE completed_at < enrolled_at)
    INTO temporal_issue_count;

    IF temporal_issue_count <> 0 THEN
        RAISE EXCEPTION
            'Seed 중단: 가입일·개설일·완료일 시간 관계 이상이 %건 있습니다.',
            temporal_issue_count;
    END IF;
END
$$;

COMMIT;

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM analysis_lab.students) <> 8
       OR (SELECT COUNT(*) FROM analysis_lab.instructors) <> 3
       OR (SELECT COUNT(*) FROM analysis_lab.courses) <> 5
       OR (SELECT COUNT(*) FROM analysis_lab.enrollments) <> 24
       OR (SELECT SUM(recorded_amount) FROM analysis_lab.enrollments) <> 3210000 THEN
        RAISE EXCEPTION 'Chapter 14 seed post-commit validation failed.';
    END IF;
    RAISE NOTICE 'Chapter 14 analysis lab seed validation passed';
END
$$;

-- 기대 행 수: students 8, instructors 3, courses 5, enrollments 24
-- 상태별: 완료 12, 수강중 5, 신청 4, 취소 3
-- 신청 시점 기록 금액 합계: 3,210,000