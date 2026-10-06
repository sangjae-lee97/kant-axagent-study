-- Chapter 11. 역할·권한 계획
-- 기준: PostgreSQL 16
-- 주의: Role은 클러스터 전역 객체입니다.
-- 관리자 권한이 있는 테스트 환경에서만 필요한 문장을 한 줄씩 선택 실행합니다.
-- 실제 비밀번호는 이 파일이나 저장소에 기록하지 않습니다.

SELECT current_user;
SELECT current_database();
SELECT current_schema();
SHOW search_path;
SELECT current_setting('server_version') AS postgresql_version;

-- ============================================================
-- 1. 실행 환경과 역할 이름 충돌 확인
-- ============================================================
SELECT
    rolname,
    rolcanlogin,
    rolsuper,
    rolcreatedb,
    rolcreaterole,
    rolinherit
FROM pg_roles
WHERE rolname IN (
    'lab_role_security_owner',
    'lab_role_report_reader',
    'lab_role_enrollment_app',
    'lab_role_backup_reader',
    'lab_readonly_user',
    'lab_enrollment_user',
    'lab_backup_user'
)
ORDER BY rolname;

-- 현재 데이터베이스의 직접 ACL과 PUBLIC 경로를 확인합니다.
SELECT datname, datacl
FROM pg_database
WHERE datname = current_database();

-- ============================================================
-- 2. 권한 역할과 로그인 역할 생성
-- 기존 역할이 없는지 확인한 뒤 필요한 문장만 실행합니다.
-- ============================================================
 CREATE ROLE lab_role_security_owner NOLOGIN;
 CREATE ROLE lab_role_report_reader NOLOGIN;
 CREATE ROLE lab_role_enrollment_app NOLOGIN;
 CREATE ROLE lab_role_backup_reader NOLOGIN;
 CREATE ROLE lab_readonly_user LOGIN;
 CREATE ROLE lab_enrollment_user LOGIN;
 CREATE ROLE lab_backup_user LOGIN;

-- 실제 인증 정보는 별도 비밀 관리 절차에서 설정합니다.
-- PASSWORD '...'를 이 파일에 작성하지 않습니다.

-- ============================================================
-- 3. PostgreSQL 16 역할 멤버십
-- ============================================================
-- PostgreSQL 16에서는 멤버십마다 INHERIT·SET·ADMIN 옵션을 구분할 수 있습니다.
-- 이 교재는 권한 역할을 자동 상속하면서 필요할 때 SET ROLE도 가능하도록
-- INHERIT TRUE, SET TRUE를 명시해 실습 의도를 고정합니다.
--
 GRANT lab_role_report_reader TO lab_readonly_user
     WITH INHERIT TRUE, SET TRUE;
 GRANT lab_role_enrollment_app TO lab_enrollment_user
     WITH INHERIT TRUE, SET TRUE;
 GRANT lab_role_backup_reader TO lab_backup_user
     WITH INHERIT TRUE, SET TRUE;

-- 04_permission_checks.sql에서 다음을 함께 확인합니다.
-- pg_has_role(..., 'MEMBER') : 멤버십 경로가 존재하는가?
-- pg_has_role(..., 'USAGE')  : 현재 설정에서 권한을 즉시 사용할 수 있는가?
-- pg_auth_members            : inherit_option / set_option / admin_option은 무엇인가?
SELECT
    role_role.rolname AS granted_role,
    member_role.rolname AS member_user,
    m.inherit_option,
    m.set_option,
    m.admin_option
FROM pg_auth_members m
JOIN pg_roles role_role
    ON m.roleid = role_role.oid
JOIN pg_roles member_role
    ON m.member = member_role.oid
WHERE role_role.rolname IN (
    'lab_role_report_reader',
    'lab_role_enrollment_app',
    'lab_role_backup_reader'
)
ORDER BY role_role.rolname;

-- ============================================================
-- 4. 데이터베이스 접속 권한
-- ============================================================
-- PUBLIC에 CONNECT가 남아 있으면 아래 GRANT가 유일한 경로는 아닐 수 있습니다.
-- 실제 DB 이름과 pg_database.datacl을 먼저 확인합니다.
 GRANT CONNECT ON DATABASE ai_database_book
 TO lab_role_report_reader, lab_role_enrollment_app, lab_role_backup_reader;

-- PUBLIC CONNECT 회수는 다른 계정 접속에 영향을 줄 수 있으므로
-- 별도 테스트 DB에서 의존성을 확인한 뒤에만 검토합니다.
-- REVOKE CONNECT ON DATABASE ai_database_book FROM PUBLIC;

-- ============================================================
-- 5. security_lab 스키마 사용 권한
-- ============================================================
 GRANT USAGE ON SCHEMA security_lab
 TO lab_role_report_reader, lab_role_enrollment_app, lab_role_backup_reader;

-- 스키마 CREATE는 앱·보고·백업 역할에 부여하지 않습니다.

-- ============================================================
-- 6. 보고 역할: 세 테이블 읽기만 허용
-- ============================================================
 GRANT SELECT ON TABLE
     security_lab.students,
     security_lab.courses,
     security_lab.enrollments
 TO lab_role_report_reader;

-- ============================================================
-- 7. 수강신청 앱 역할
-- ============================================================
-- 학생·강의·신청 조회
 GRANT SELECT ON TABLE
     security_lab.students,
     security_lab.courses,
     security_lab.enrollments
 TO lab_role_enrollment_app;

-- 신청 생성
 GRANT INSERT ON TABLE security_lab.enrollments
 TO lab_role_enrollment_app;

-- 신청 상태 컬럼만 변경
 GRANT UPDATE (status) ON TABLE security_lab.enrollments
 TO lab_role_enrollment_app;

-- IDENTITY 기본값의 nextval 사용에 필요한 최소 시퀀스 권한
 GRANT USAGE
 ON SEQUENCE security_lab.enrollments_id_seq
 TO lab_role_enrollment_app;

-- 일반 자동 ID INSERT에는 별도 SELECT 권한이 필요하지 않습니다.
-- 시퀀스 상태 직접 조회라는 업무 요구가 있을 때만 SELECT를 추가 검토합니다.
-- recorded_amount UPDATE·DELETE·TRUNCATE·schema CREATE는 부여하지 않습니다.

-- ============================================================
-- 8. 스키마 백업 전용 읽기 역할
-- ============================================================
-- pg_dump는 대상 테이블의 데이터를 읽을 수 있어야 합니다.
-- IDENTITY 시퀀스 상태까지 완전하게 덤프하는 실습이므로 백업 역할에는
-- 앱 역할과 달리 세 시퀀스의 SELECT를 명시적으로 부여합니다.
--
 GRANT SELECT ON TABLE
     security_lab.students,
     security_lab.courses,
     security_lab.enrollments
 TO lab_role_backup_reader;

 GRANT SELECT ON SEQUENCE
     security_lab.students_id_seq,
     security_lab.courses_id_seq,
     security_lab.enrollments_id_seq
 TO lab_role_backup_reader;

-- RLS 주의:
-- 일반적인 전체 논리 백업에서는 보이는 행만 조용히 덤프하는 것을 목표로 하지 않습니다.
-- pg_dump는 기본적으로 row_security를 끄려 하며, 백업 역할이 정책을 우회할 수 없으면
-- 오류로 중단될 수 있습니다. --enable-row-security는 역할에게 보이는 행만 덤프하려는
-- 명시적 요구가 있을 때 별도로 검토합니다. 운영 전체 백업과 같은 의미로 사용하지 않습니다.
-- 이 실습 security_lab에는 RLS를 적용하지 않습니다.

-- ============================================================
-- 9. 명시적 권한 회수 예시
-- ============================================================
-- 변경 전 다른 역할과 애플리케이션 의존성을 먼저 확인합니다.
 REVOKE INSERT, UPDATE, DELETE
 ON TABLE security_lab.students
 FROM lab_role_enrollment_app;

 REVOKE DELETE, TRUNCATE
 ON TABLE security_lab.enrollments
 FROM lab_role_enrollment_app;

-- ============================================================
-- 10. 미래 객체 Default Privileges 예시
-- ============================================================
-- FOR ROLE은 실제로 미래 객체를 생성할 소유 역할이어야 합니다.
-- 기존 객체 권한은 이 명령으로 바뀌지 않습니다.
 ALTER DEFAULT PRIVILEGES
 FOR ROLE lab_role_security_owner
 IN SCHEMA security_lab
 GRANT SELECT ON TABLES
 TO lab_role_report_reader;

 ALTER DEFAULT PRIVILEGES
 FOR ROLE lab_role_security_owner
 IN SCHEMA security_lab
 GRANT SELECT ON TABLES
 TO lab_role_enrollment_app;

-- ============================================================
-- 11. 선택적 소유권 분리 예시
-- ============================================================
-- 소유 역할을 실제로 만든 뒤 테스트 환경에서만 실행합니다.
 ALTER SCHEMA security_lab OWNER TO lab_role_security_owner;
 ALTER TABLE security_lab.students OWNER TO lab_role_security_owner;
 ALTER TABLE security_lab.courses OWNER TO lab_role_security_owner;
 ALTER TABLE security_lab.enrollments OWNER TO lab_role_security_owner;
 ALTER SEQUENCE security_lab.students_id_seq OWNER TO lab_role_security_owner;
 ALTER SEQUENCE security_lab.courses_id_seq OWNER TO lab_role_security_owner;
 ALTER SEQUENCE security_lab.enrollments_id_seq OWNER TO lab_role_security_owner;

-- ============================================================
-- 12. 역할 정리 계획
-- ============================================================
-- Role은 다른 DB와 객체에서 사용 중일 수 있으므로 자동 정리하지 않습니다.
-- 소유 역할은 객체를 소유한 상태에서 바로 DROP할 수 없습니다.
-- 관련된 각 데이터베이스에서 다음 순서를 검토합니다.
--
 REVOKE lab_role_report_reader FROM lab_readonly_user;
 REVOKE lab_role_enrollment_app FROM lab_enrollment_user;
 REVOKE lab_role_backup_reader FROM lab_backup_user;

 REASSIGN OWNED BY lab_role_security_owner TO postgres;
 DROP OWNED BY lab_role_security_owner;

 DROP ROLE lab_readonly_user;
 DROP ROLE lab_enrollment_user;
 DROP ROLE lab_backup_user;
 
 DROP ROLE lab_role_report_reader;
 DROP ROLE lab_role_enrollment_app;
 DROP ROLE lab_role_backup_reader;
 DROP ROLE lab_role_security_owner;
--
-- DROP OWNED는 권한과 소유 객체에 영향을 줄 수 있으므로 CASCADE를 기본으로 사용하지 않습니다.