-- Chapter 14. analysis_lab 초기화
-- 주의: 예상한 Chapter 14 객체만 삭제하며 예상 밖 객체가 있으면 중단합니다.

SELECT current_database();
SELECT current_user;
SELECT current_schema();
SHOW search_path;

DO $$
DECLARE
    unexpected_count INTEGER;
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION '초기화 중단: ai_database_book에서만 실행하세요.';
    END IF;
    IF to_regnamespace('analysis_lab') IS NULL THEN
        RAISE EXCEPTION '초기화 중단: analysis_lab 스키마가 없습니다.';
    END IF;
    WITH expected(kind, name) AS (
        VALUES ('table','students'), ('table','instructors'), ('table','courses'), ('table','enrollments'),
               ('view','analysis_parameters'), ('view','enrollment_analysis_dataset')
    ), actual(kind, name) AS (
        SELECT 'table', table_name FROM information_schema.tables WHERE table_schema = 'analysis_lab' AND table_type = 'BASE TABLE'
        UNION ALL
        SELECT 'view', table_name FROM information_schema.views WHERE table_schema = 'analysis_lab'
    )
    SELECT COUNT(*) INTO unexpected_count FROM actual a LEFT JOIN expected e USING (kind, name) WHERE e.name IS NULL;
    IF unexpected_count <> 0 THEN
        RAISE EXCEPTION '초기화 중단: analysis_lab에 예상 밖 테이블/VIEW가 %개 있습니다.', unexpected_count;
    END IF;
    IF (SELECT COUNT(*) FROM course_project.enrollments) <> 5
       OR (SELECT SUM(recorded_amount) FROM course_project.enrollments) <> 590000 THEN
        RAISE EXCEPTION '초기화 중단: 보호 대상 course_project 기준 상태가 다릅니다.';
    END IF;
END
$$;

BEGIN;
DROP VIEW analysis_lab.enrollment_analysis_dataset;
DROP VIEW analysis_lab.analysis_parameters;
DROP TABLE analysis_lab.enrollments;
DROP TABLE analysis_lab.courses;
DROP TABLE analysis_lab.instructors;
DROP TABLE analysis_lab.students;
DROP SCHEMA analysis_lab;

DO $$
BEGIN
    IF to_regnamespace('analysis_lab') IS NOT NULL THEN RAISE EXCEPTION '초기화 실패: analysis_lab이 남아 있습니다.'; END IF;
    IF (SELECT COUNT(*) FROM course_project.enrollments) <> 5
       OR (SELECT SUM(recorded_amount) FROM course_project.enrollments) <> 590000 THEN
        RAISE EXCEPTION '초기화 실패: 보호 대상 course_project가 변경되었습니다.';
    END IF;
END
$$;
COMMIT;

DO $$ BEGIN RAISE NOTICE 'Chapter 14 analysis lab reset passed'; END $$;

-- 초기화 후 01_analysis_lab_schema.sql부터 다시 실행합니다.