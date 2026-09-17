# Chapter 08 실습 코드

## JOIN과 집계로 서비스 질문에 답하기

이 폴더는 Chapter 07에서 완성한 `course_project` 데이터를 변경하지 않고 JOIN과 집계 결과를 조회·검산하는 SQL 파일을 관리합니다.

## 실행 전 조건

Chapter 07의 다음 파일을 순서대로 실행합니다.

```text
01_course_project_schema.sql
→ 02_course_project_seed.sql
→ 03_course_project_changes.sql
→ 04_course_project_validation.sql
```

Chapter 07 검증 통과 메시지:

```text
Chapter 07 course project validation passed
```

최종 기준:

```text
students 3
instructors 2
courses 3
enrollments 5
1001 완료 / recorded_amount 100000
1004 취소 / recorded_amount 150000
1005 신청 / recorded_amount 120000
```

## 파일 목록과 실행 순서

```text
00_check_course_project.sql
→ 01_join_queries.sql
→ 02_aggregation_queries.sql
→ 03_join_aggregation_validation.sql
```

| 파일 | 설명 |
| --- | --- |
| `00_check_course_project.sql` | Chapter 07 최종 구조·행 수·상태·관계·기록 금액 자동 사전 검사 |
| `01_join_queries.sql` | INNER·다중·LEFT JOIN과 ON/WHERE·anti-join 비교 |
| `02_aggregation_queries.sql` | COUNT·SUM·AVG·GROUP BY·FILTER·HAVING·과대 집계 사례 |
| `03_join_aggregation_validation.sql` | JOIN·집계 핵심 결과를 자동 판정하는 완료 게이트 |
| `join_aggregation_practice.sql` | 기존 링크 호환용 읽기 전용 핵심 조회 |

모든 Chapter 08 SQL은 조회 전용이며 `course_project.table_name` 형식을 사용합니다.

## 00 사전 검사 게이트

`00_check_course_project.sql`은 단순 행 수만 확인하지 않습니다.

```text
current_database = ai_database_book
students / instructors / courses / enrollments 존재
uq_course_enrollments_active 존재
recorded_amount = NUMERIC(12,0)
Chapter 07 명명 제약조건 = 15 / NOT NULL 열 = 20
행 수 = 3 / 2 / 3 / 5
상태 = 신청 2 / 수강중 1 / 완료 1 / 취소 1
전체 = 5 / 590000 / 평균 118000.00
활성 = 3 / 340000
취소 제외 = 4 / 440000
고아 관계 = 0 / 0 / 0
활성 중복 = 0
1001 = 완료 / 100000
1004 = 취소 / 150000
1005 = 신청 / 120000
```

통과 메시지:

```text
Chapter 08 prerequisite check passed
```

## 금액 열

```text
courses.price
→ 현재 강의 기준 가격

enrollments.recorded_amount
→ 신청 시 기록 금액
```

`recorded_amount`는 실제 결제 승인액·환불액·회계 매출이 아닙니다. Chapter 08에서는 신청 행에 기록된 값을 집계합니다.

## 분석 범위와 기준값

| 범위 | 포함 상태 | 건수 | recorded_amount 합계 |
| --- | --- | ---: | ---: |
| 전체 신청 이력 | 모든 상태 | 5 | 590000 |
| 활성 신청 | 신청, 수강중 | 3 | 340000 |
| 취소 제외 이력 | 신청, 수강중, 완료 | 4 | 440000 |
| 취소 신청 | 취소 | 1 | 150000 |

```text
전체 평균 recorded_amount = 118000.00
취소 제외 평균 recorded_amount = 110000.00
```

`recorded_amount`는 `NUMERIC(12,0)`이며 `AVG(recorded_amount)`는 `numeric` 결과를 반환합니다.

## COUNT 구분

```text
COUNT(*)
→ JOIN 결과 행 전체 수

COUNT(e.id)
→ 실제 신청 행 수

COUNT(DISTINCT e.student_id)
→ 고유 학생 수
```

LEFT JOIN에서 자식 사건 수를 계산할 때 `COUNT(*)`를 사용하면 자식이 없는 부모도 한 행처럼 보일 수 있습니다.

Chapter 07 기준 데이터에서 강의 303은 취소 제외 신청이 없습니다.

```text
강의 303
COUNT(*) = 1
COUNT(e.id) = 0
COUNT(DISTINCT e.student_id) = 0
기록 금액 = 0
```

## ON과 WHERE

모든 부모를 유지하면서 연결 대상을 제한하려면 오른쪽 조건을 `ON`에 둡니다.

```sql
LEFT JOIN course_project.enrollments AS e
    ON c.id = e.course_id
   AND e.status <> '취소'
```

학생 기준 예제의 실제 결과:

```text
ON에 조건 사용 → 학생 3명 유지
WHERE에 조건 사용 → 취소 제외 신청이 없는 박서연 제외, 학생 2명
```

취소 제외 신청이 없는 학생 찾기:

```text
LEFT JOIN ... IS NULL = 1명
NOT EXISTS = 1명
결과 = 박서연
```

## 집계와 NULL

```text
COUNT(*)·COUNT(column)
→ 대상이 없으면 0

SUM·AVG·MIN·MAX
→ 대상이 없으면 NULL 가능
```

`COALESCE(..., 0)`는 데이터 없음과 0을 같은 의미로 표시해도 될 때만 사용합니다.

## 과대 집계 주의

강의와 신청을 JOIN하면 강의 한 행이 신청 수만큼 반복됩니다. 이 상태에서 `SUM(c.price)`를 계산하면 강의 가격이 과대 합산될 수 있습니다.

```text
강사 201
실제 강의: 301, 302 두 개
신청 JOIN 뒤에는 두 강의가 각각 신청 수만큼 반복
```

강의 가격 합계가 질문이면 신청 테이블을 JOIN하지 않고 강의 수준에서 계산합니다. `SUM(DISTINCT c.price)` 역시 서로 다른 강의의 가격이 같을 때 하나를 제거할 수 있으므로 일반적인 해결책이 아닙니다.

## 03 자동 완료 게이트

`03_join_aggregation_validation.sql`은 다음 결과를 자동 판정하고 하나라도 다르면 예외를 발생시킵니다.

```text
상세 신청 수 = 5
상태별 건수 합 = 5
상세 기록 금액 = 590000
강의별 기록 금액 합 = 590000
활성 상세·그룹 = 3 / 340000
취소 제외 상세·강의별 = 4 / 440000
INNER JOIN 결과 = 5
고아 관계 = 0 / 0 / 0
anti-join 두 방식 = 각각 1명
ON 조건 학생 수 = 3
WHERE 조건 학생 수 = 2
강의 301 = 2건 / 2명 / 200000
강의 302 = 2건 / 2명 / 240000
강의 303 = LEFT JOIN 결과 1행 / 실제 신청 0 / 고유 학생 0 / 0원
강사 201 = 강의 2 / 신청 4 / 취소 제외 4
강사 202 = 강의 1 / 신청 1 / 취소 제외 0
HAVING 취소 제외 2건 이상 강의 = 2개
강사 201 가격: 신청 JOIN 뒤 잘못된 합계 440000 / 강의 수준 올바른 합계 220000
강사 202 가격: 두 방식 모두 150000(우연히 같음)
```

통과 메시지:

```text
Chapter 08 join and aggregation validation passed
```

## 최종 검산 원칙

```text
전체 신청 이력: 5 / 590000
활성 신청: 3 / 340000
취소 제외 신청 이력: 4 / 440000
INNER JOIN 결과: 5행
고아 관계: 0행
```

복잡한 SQL 결과가 이 기준과 다르면 `DISTINCT`나 `COALESCE`를 먼저 추가하지 않고 결과 한 행의 기준, JOIN 경로, 상태 범위, 조건 위치와 집계 대상을 먼저 확인합니다.

## 자동 검증

저장소의 `.github/workflows/validate-chapter08.yml`은 정적 문서·자산 검사와 PostgreSQL 16 실제 실행 검증을 함께 수행합니다. Chapter 07 기준 상태를 생성한 뒤 Chapter 08의 `00 → 01 → 02 → 03 → 호환 조회` 경로를 읽기 전용 트랜잭션에서 실행하고, 기준 상태나 집계값을 의도적으로 바꿨을 때 `00`과 `03`이 차단하는지도 확인합니다.