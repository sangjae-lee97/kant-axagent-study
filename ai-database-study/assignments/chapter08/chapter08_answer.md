# Chapter 08 확장 실습 답안 템플릿

> **과제:** JOIN과 집계로 서비스 질문에 답하기  
> **사용 방법:** 이 파일을 내려받아 본인의 GitHub 저장소에 `chapter08_answer.md`라는 이름으로 저장한 뒤 실습하면서 바로 작성합니다.  
> **제출 방법:** LMS에는 파일을 직접 업로드하지 않고, **본인 GitHub 저장소의 `chapter08_answer.md` 파일 URL**을 제출합니다.

---

## 제출 전 주의

이 파일과 캡처 화면에는 실제 비밀번호, 전체 DB 접속 URL, API Key, 개인정보를 기록하지 않습니다.

```text
GitHub 계정 또는 별칭: sangjae-lee97 
과제 작성일: 2026.09.18
사용한 AI 도구: gpt
```

---

# 1. Chapter 07 기준 상태 확인

다음을 실행합니다.

```text
code/chapter08/00_check_course_project.sql
```

## 1-1. 사전 검사 결과

```text
검증 메시지: Chapter 08 prerequisite check passed

students 행 수: 3
instructors 행 수: 2
courses 행 수: 3
enrollments 행 수: 5

전체 신청 건수: 5
전체 recorded_amount: 590000
활성 신청 건수: 3
활성 recorded_amount: 340000
취소 제외 신청 건수: 4
취소 제외 recorded_amount: 440000
```

기준값:

```text
students = 3
instructors = 2
courses = 3
enrollments = 5

전체 = 5 / 590000
활성 = 3 / 340000
취소 제외 = 4 / 440000
```

### 기준값이 다르면 그대로 진행하면 안 되는 이유

```text
같은 결과가 안나오면 제대로된 분석 재현성이 떨어져 신뢰도에 영향을 미치기 때문
```

### 증거 화면

권장 경로:

```text
assignments/chapter08/images/step01_prerequisite.png
```

`여기에 사전 검사 통과 화면을 삽입하세요.`
![분석 전 준비](./images/step01_prerequisite.png)
---

# 2. 업무 질문을 SQL보다 먼저 정의하기

다음 세 질문을 각각 SQL 작성 전에 먼저 정의합니다.

## 질문 A

```text
| 항목                        | 내용                                                |
| ------------------------- | ------------------------------------------------- |
| 업무 질문                     | 취소되지 않은 신청 수를 강의별로 보여 주세요.                        |
| 결과 한 행의 의미                | 강의 한 개                                            |
| 포함 상태                     | 신청, 수강중, 완료                                       |
| 제외 상태                     | 취소                                                |
| JOIN할 테이블                 | courses, enrollments                              |
| JOIN 경로                   | courses.id = enrollments.course_id                |
| INNER JOIN / LEFT JOIN 선택 | LEFT JOIN                                         |
| 집계 대상                     | 강의별 취소되지 않은 수강신청 건수                               |
| 예상 결과                     | 모든 강의가 표시되고, 취소되지 않은 신청이 없는 강의는 0건으로 표시           |
| 검산 방법                     | enrollments에서 취소 상태를 제외한 전체 건수와 강의별 집계 건수의 합계를 비교 |

```

## 질문 B

```text
| 항목                        | 내용                                     |
| ------------------------- | -------------------------------------- |
| 업무 질문                     | 강사별로 담당 강의 수를 보여 주세요.                  |
| 결과 한 행의 의미                | 강사 한 명                                 |
| 포함 상태                     | 모든 강의                                  |
| 제외 상태                     | 없음                                     |
| JOIN할 테이블                 | instructors, courses                   |
| JOIN 경로                   | instructors.id = courses.instructor_id |
| INNER JOIN / LEFT JOIN 선택 | LEFT JOIN                              |
| 집계 대상                     | 강사별 담당 강의 수                            |
| 예상 결과                     | 모든 강사가 표시되고, 담당 강의가 없는 강사는 0개로 표시      |
| 검산 방법                     | courses 전체 행 수와 강사별 강의 수 합계를 비교        |

```

## 질문 C

```text
| 항목                        | 내용                                                           |
| ------------------------- | ------------------------------------------------------------ |
| 업무 질문                     | 학생별로 취소되지 않은 수강신청의 기록 금액 합계를 보여 주세요.                         |
| 결과 한 행의 의미                | 학생 한 명                                                       |
| 포함 상태                     | 신청, 수강중, 완료                                                  |
| 제외 상태                     | 취소                                                           |
| JOIN할 테이블                 | students, enrollments                                        |
| JOIN 경로                   | students.id = enrollments.student_id                         |
| INNER JOIN / LEFT JOIN 선택 | LEFT JOIN                                                    |
| 집계 대상                     | 학생별 `recorded_amount` 합계                                     |
| 예상 결과                     | 모든 학생이 표시되고, 취소되지 않은 신청이 없는 학생은 금액 합계가 0으로 표시                |
| 검산 방법                     | enrollments에서 취소를 제외한 `recorded_amount` 총합과 학생별 합계의 전체 합을 비교 |

```

---

# 3. INNER JOIN과 다중 JOIN

## 3-1. 신청 한 건마다 학생 이름과 강의 제목 조회

실행 전 예상:

```text
결과 한 행 = 수강신청 한 건
예상 행 수 = 5행
JOIN 경로 = enrollments.student_id-> students.id
JOIN 경로 = enrollments.course_id-> courses.id
```

내가 실행한 SQL:

```sql
SELECT
    e.id AS enrollment_id,
    s.name AS student_name,
    c.title AS course_title,
    e.status
FROM course_project.enrollments AS e
JOIN course_project.students AS s
    ON e.student_id = s.id
JOIN course_project.courses AS c
    ON e.course_id = c.id
ORDER BY e.id;
```

실제 결과:

```text
실제 행 수: 5행
예상과 일치 여부: 일치
```

### 학생 이름이 여러 번 보이는 것이 중복 오류가 아닐 수 있는 이유

```text
학생 한 명이 여러 강의를 신청했을 수도 있기 때문
```

## 3-2. 학생·강의·강사까지 연결

```text
결과 한 행 = 수강신청 한건과 신청한 학생 그 강의 강사
강사까지 가는 JOIN 경로 = enrollments.course_id -> courses.id -> courses.instructor_id -> instructors.id
```

```sql
SELECT
    e.id AS enrollment_id,
    s.name AS student_name,
    c.title AS course_title,
    i.name as instructor_name,
    e.status
FROM course_project.enrollments AS e
JOIN course_project.students AS s
    ON e.student_id = s.id
JOIN course_project.courses AS c
    ON e.course_id = c.id
JOIN course_project.instructors AS i
    ON c.instructor_id = i.id
ORDER BY e.id;
```

실제 행 수:5

```text

```

### 증거 화면

권장 경로:

```text
assignments/chapter08/images/step03_inner_join.png
```

`여기에 다중 JOIN 결과 화면을 삽입하세요.`
![다중 join](./images/step03_inner_join.png)
---

# 4. LEFT JOIN과 0건 표현

## 4-1. 강의별 취소 제외 신청 수

신청이 없는 강의도 결과에 남도록 작성합니다.

실행 전:

```text
결과 한 행 = 강의 한 개
강의 303의 예상 실제 신청 수 = 0
강의 303의 예상 고유 학생 수 = 0
강의 303의 예상 recorded_amount = 0 
```

내 SQL:

```sql
SELECT
    c.id AS course_id,
    c.title AS course_title,
    COUNT(
        CASE
            WHEN e.status <> '취소'
            THEN e.id
        END
    ) AS enrollment_count,
    COUNT(
        DISTINCT CASE
            WHEN e.status <> '취소'
            THEN e.student_id
        END
    ) AS unique_student_count,
    COALESCE(
        SUM(
            CASE
                WHEN e.status <> '취소'
                THEN e.recorded_amount
                ELSE 0
            END
        ),
        0
    ) AS total_recorded_amount
FROM course_project.courses AS c
LEFT JOIN course_project.enrollments AS e
    ON c.id = e.course_id
GROUP BY
    c.id,
    c.title
ORDER BY
    c.id;
```

실제 결과:

```text
| course_id | course_title | enrollment_count | unique_student_count | total_recorded_amount |
| --------: | ------------ | ---------------: | -------------------: | --------------------: |
|       301 | 데이터베이스 입문    |                2 |                    2 |                200000 |
|       302 | 정규화 실습       |                2 |                    2 |                240000 |
|       303 | 파이썬 데이터 분석   |                0 |                    0 |                     0 |

```

## 4-2. `COUNT(*)`와 `COUNT(e.id)` 비교

강의 303을 기준으로 작성합니다.

```text
COUNT(*) 결과: 1
COUNT(e.id) 결과: 0
COUNT(DISTINCT e.student_id) 결과: 0
```

### 왜 `COUNT(*) = 1`인데 실제 신청 수는 0일 수 있나요?

```text
join 결과의 행 수를 세기 때문
```

### 자식 사건 수를 셀 때 `COUNT(child.id)`가 더 적절한 이유

```text
null이 아닌 실제 신청 id만 세기 때문
```

---

# 5. `LEFT JOIN`에서 `ON`과 `WHERE` 조건 비교

취소 제외 신청만 연결한다고 가정합니다.

## 5-1. 조건을 `ON`에 둔 경우

```sql
SELECT
    s.id,
    s.name,
    COUNT(e.id) AS non_cancelled_count
FROM course_project.students AS s
LEFT JOIN course_project.enrollments AS e
    ON s.id = e.student_id
   AND e.status <> '취소'
GROUP BY s.id, s.name
ORDER BY s.id;
```

```text
결과 학생 수: 3
박서연 포함 여부: 포함
```

## 5-2. 조건을 `WHERE`에 둔 경우

```sql
SELECT
    s.id,
    s.name,
    COUNT(e.id) AS non_cancelled_count
FROM course_project.students AS s
LEFT JOIN course_project.enrollments AS e
    ON s.id = e.student_id
WHERE e.status <> '취소'
GROUP BY s.id, s.name
ORDER BY s.id;
```

```text
결과 학생 수: 2
박서연 포함 여부: 미포함
```

## 5-3. 차이 설명

```text
ON 조건이 LEFT JOIN의 오른쪽 연결 대상을 제한하는 방식: 왼쪽 행을 유지하면서 join 대상만 제한

WHERE 조건이 JOIN 이후 결과 행을 제거하는 방식: join 결과가 만들어진 뒤 행을 제거

이번 사례에서 ON = 3명, WHERE = 2명이 되는 이유: on은 null 행을 세지만 where은 후에 조건에 맞는 행을 제거해버리기 때문
```

---

# 6. 신청이 없는 학생 찾기 — 두 방법 비교

## 방법 1. `LEFT JOIN ... IS NULL`

```sql
SELECT
    s.id,
    s.name,
    s.email
FROM course_project.students AS s
LEFT JOIN course_project.enrollments AS e
    ON s.id = e.student_id
   AND e.status <> '취소'
WHERE e.id IS NULL;
```

## 방법 2. `NOT EXISTS`

```sql
SELECT
    s.id,
    s.name,
    s.email
FROM course_project.students AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM course_project.enrollments AS e
    WHERE e.student_id = s.id
      AND e.status <> '취소'
);
```

```text
방법 1 결과:
103	박서연	seoyeon@example.com
방법 2 결과:
103	박서연	seoyeon@example.com
두 결과가 같은가: 같음
찾아진 학생: 박서연
```

### 두 방식의 공통 의미를 자신의 말로 설명

```text
left join ... is null은 대응하는 오른쪽 행이 없는 결과를 찾는다
not exists는 조건을 만족하는 자식 행이 존재하지 않는 부모를 찾는다.
공통 의미는 연결 대상이 존재하지 않는 부모를 찾는다.
```

---

# 7. 기본 집계 검산

다음 결과를 직접 확인합니다.

| 분석 범위 | 예상 건수 | 실제 건수 | 예상 금액 | 실제 금액 | 일치? |
| --- | ---: | ---: | ---: | ---: | --- |
| 전체 신청 | 5 | 5 | 590000 | 590000 | 일치 |
| 활성 신청 | 3 | 3 | 340000 | 340000 | 일치 |
| 취소 제외 | 4 | 4 | 440000 | 440000 | 일치 |
| 취소 | 1 | 1 | 150000 | 150000 | 일치 |

## 7-1. 전체 평균 `recorded_amount`

```text
예상 평균: 590000
실제 평균: 590000
```

## 7-2. 취소 제외 평균

```text
예상 평균: 340000
실제 평균: 340000
```

### `recorded_amount`를 실제 회계 매출이라고 부르면 안 되는 이유

```text
수강 상태에 관계 없이 합계되기 때문
```

---

# 8. `GROUP BY`, `HAVING`, `FILTER`

## 8-1. 상태별 신청 건수

```sql
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
```

결과:

```text
신청: 2
수강중: 1
완료: 1
취소:1 
상태별 합계: 5
```

### 상태별 건수 합이 전체 신청 5건과 맞는지 검산

```text
그룹별 건수 합 = 2 + 1 + 1 + 1 = 5
```

## 8-2. 강의별 취소 제외 신청 수와 금액

```sql
SELECT
    c.id AS course_id,
    c.title AS course_title,
    COUNT(e.id) AS enrollment_count,
    COUNT(DISTINCT e.student_id) AS unique_student_count,
    COALESCE(SUM(e.recorded_amount), 0) AS total_recorded_amount
FROM course_project.courses AS c
LEFT JOIN course_project.enrollments AS e
    ON c.id = e.course_id
   AND e.status <> '취소'
GROUP BY
    c.id,
    c.title
ORDER BY
    c.id;
```

```text
강의 301: 2
강의 302: 2
강의 303: 0 
강의별 합계를 다시 더한 값: 440000
전체 취소 제외 기준 440000과 일치 여부: 일치
```

## 8-3. `HAVING` 사용

취소 제외 신청이 2건 이상인 강의를 조회합니다.

```sql
SELECT
    c.id AS course_id,
    c.title AS course_title,
    COUNT(e.id) AS non_cancelled_count
FROM course_project.courses AS c
JOIN course_project.enrollments AS e
    ON c.id = e.course_id
WHERE e.status <> '취소'
GROUP BY
    c.id,
    c.title
HAVING COUNT(e.id) >= 2
ORDER BY c.id;
```

```text
예상 강의 수: 4
실제 강의 수: 4
```

---

# 9. 과대 집계 오류 직접 관찰

강사 201의 강의 가격 합계를 구한다고 가정합니다.

## 9-1. 신청까지 JOIN해서 잘못 집계한 결과

```sql
SELECT
    i.id,
    SUM(c.price) AS wrong_course_price_sum
FROM course_project.instructors AS i
JOIN course_project.courses AS c
    ON i.id = c.instructor_id
JOIN course_project.enrollments AS e
    ON c.id = e.course_id
GROUP BY i.id;
```

```text
강사 201 잘못된 가격 합계: 440000
```

본문 기준:

```text
440000
```

## 9-2. 강의 수준에서 올바르게 집계

```sql
SELECT
    instructor_id,
    SUM(price) AS course_price_sum
FROM course_project.courses
GROUP BY instructor_id
ORDER BY instructor_id;
```

```text
강사 201 올바른 가격 합계: 220000
```

본문 기준:

```text
220000
```

## 9-3. 왜 두 결과가 달라졌나요?

```text
JOIN 전 강의 행 수: 2
JOIN 후 강의가 반복된 이유: 4 
SUM이 무엇을 반복해서 더했는가: 신청행도 집계되어 중복 계산 됨
```

### `SUM(DISTINCT c.price)`를 일반적인 해결책으로 사용하면 안 되는 이유

```text
distinct가 제거하는 기준이 "강의"가 아니라 "가격 값"이기 때문에 서로 다른 강의의 가격이 같을 때 지워질 수 있어서 위험함. 따라서 신청 테이블이 필요하지 않다면 join하지 않고 강의 수준에서 계산해야함

```

### 증거 화면

권장 경로:

```text
assignments/chapter08/images/step09_over_aggregation.png
```

`여기에 잘못된 합계와 올바른 합계를 비교한 화면을 삽입하세요.`
![비교 사진](./images/step09_over_aggregation.png)
---

# 10. 상세 결과 ↔ 집계 결과 교차 검산

강의 하나를 선택합니다.

```text
선택한 course_id: 301
강의 제목: 데이터베이스 입문
```

## 10-1. 상세 신청 행 조회

```sql
SELECT *
FROM enrollments e 
where course_id = 301;
```

```text
상세 행 수: 2
상세 recorded_amount를 직접 더한 값: 200000
```

## 10-2. 집계 SQL

```sql
SELECT
    course_id,
    COUNT(*) AS enrollment_count,
    SUM(recorded_amount) AS total_recorded_amount
FROM course_project.enrollments
WHERE course_id = 301
GROUP BY course_id;
```

```text
집계 건수: 2
집계 금액: 200000
```

## 10-3. 비교

```text
상세 행 수와 COUNT 결과 일치 여부: 일치
상세 금액 합과 SUM 결과 일치 여부: 일치
다르다면 원인:
```

---

# 11. 자동 완료 게이트

다음을 실행합니다.

```text
code/chapter08/03_join_aggregation_validation.sql
```

```text
최종 검증 메시지: Chapter 08 join and aggregation validation passed
```

기대 메시지:

```text
Chapter 08 join and aggregation validation passed
```

### 자동 검증이 통과했어도 사람이 SQL 의미를 설명해야 하는 이유

```text
업무 질문 자체가 올바르게 정의되지 않았을 수도 있음, recorded_amount가 올바른 업무 지표로 해석되지 않을 수도 있음
```

---

# 12. 개인 프로젝트 업무 질문 3개 만들기

Chapter 07에서 작성한 개인 프로젝트를 사용합니다.

# 12. 개인 프로젝트 업무 질문 3개 만들기

Chapter 07에서 작성한 `naver-ai-briefing-tracker` 프로젝트를 사용합니다.

> 현재 개인 프로젝트 테이블은 PostgreSQL에서 아직 완성하지 않았으므로
> SQL 초안과 예상 검산 방법까지만 작성하고 실제 결과는 `미실행`으로 기록한다.

| 질문 ID   | 업무 질문                                       | 결과 한 행           | 포함/제외 범위                                                   | JOIN 경로                                    | 집계 대상                   | 검산 방법                                            |
| ------- | ------------------------------------------- | ---------------- | ---------------------------------------------------------- | ------------------------------------------ | ----------------------- | ------------------------------------------------ |
| P08-Q01 | 게시글별로 AI 브리핑에서 인용 사례가 몇 번 발견되었는가?           | 게시글 1개           | `CITED`만 포함, `NOT_CITED`, `NO_BRIEFING`, `CHECK_FAILED` 제외 | `posts → keywords → search_runs`           | `CITED` 검색 실행 건수        | 전체 `CITED` 건수와 게시글별 `cited_count` 합계 비교          |
| P08-Q02 | 게시글별 검색어마다 확인 가능한 검색 중 인용 비율은 얼마인가?         | 게시글-검색어 조합 1개    | `CITED`, `NOT_CITED`만 포함, `NO_BRIEFING`, `CHECK_FAILED` 제외 | `posts → keywords → search_runs`           | 확인 가능 검색 건수와 `CITED` 건수 | 특정 검색어의 상세 실행 건수와 집계값 비교                         |
| P08-Q03 | `CITED`로 기록된 검색 실행에 실제 게시글과 일치하는 출처가 존재하는가? | `CITED` 검색 실행 1개 | `CITED`만 포함                                                | `posts → keywords → search_runs → sources` | 게시글 URL과 일치하는 출처 건수     | `matching_source_count = 0`인 `CITED` 실행이 0건인지 확인 |

## 12-1. 질문 1 SQL

```sql
SELECT
    p.post_id,
    p.post_url,
    COUNT(sr.search_run_id) AS cited_count
FROM posts p
LEFT JOIN keywords k
    ON p.post_id = k.post_id
LEFT JOIN search_runs sr
    ON k.keyword_id = sr.keyword_id
   AND sr.status = 'CITED'
GROUP BY
    p.post_id,
    p.post_url
ORDER BY
    cited_count DESC,
    p.post_id;
```

```text
예상 결과:
게시글 1개당 한 행이 나온다.
각 게시글이 AI 브리핑에서 CITED로 기록된 횟수를 cited_count로 확인한다.
인용 사례가 없는 게시글도 cited_count = 0으로 표시된다.

실제 결과:
미실행

검산 결과:
미실행

예상 검산 방법:
아래 SQL로 전체 CITED 검색 실행 건수를 구한다.

SELECT COUNT(*) AS total_cited_count
FROM search_runs
WHERE status = 'CITED';

위 total_cited_count와
질문 1 결과의 cited_count 전체 합계가 같아야 한다.
```

## 12-2. 질문 2 SQL

```sql
SELECT
    p.post_id,
    p.post_url,
    k.keyword_id,
    k.keyword_text,
    COUNT(sr.search_run_id) AS checked_count,
    COUNT(*) FILTER (
        WHERE sr.status = 'CITED'
    ) AS cited_count,
    ROUND(
        COUNT(*) FILTER (
            WHERE sr.status = 'CITED'
        ) * 100.0
        / NULLIF(COUNT(sr.search_run_id), 0),
        2
    ) AS citation_rate
FROM posts p
JOIN keywords k
    ON p.post_id = k.post_id
LEFT JOIN search_runs sr
    ON k.keyword_id = sr.keyword_id
   AND sr.status IN ('CITED', 'NOT_CITED')
GROUP BY
    p.post_id,
    p.post_url,
    k.keyword_id,
    k.keyword_text
ORDER BY
    citation_rate DESC NULLS LAST,
    checked_count DESC;
```

```text
예상 결과:
게시글-검색어 조합마다 한 행이 나온다.

checked_count는
CITED 또는 NOT_CITED로 정상 판정된 검색 실행 횟수이다.

cited_count는
그중 CITED로 판정된 횟수이다.

citation_rate는
cited_count / checked_count × 100으로 계산한다.

NO_BRIEFING과 CHECK_FAILED는
정상적으로 인용 여부를 판단하지 못한 실행이므로 비율 계산에서 제외한다.

실제 결과:
미실행

검산 결과:
미실행

예상 검산 방법:
특정 keyword_id 하나를 선택하여 아래 SQL을 실행한다.

SELECT
    COUNT(*) AS checked_count,
    COUNT(*) FILTER (
        WHERE status = 'CITED'
    ) AS cited_count
FROM search_runs
WHERE keyword_id = 선택한_keyword_id
  AND status IN ('CITED', 'NOT_CITED');

위 결과와 질문 2의 해당 keyword_id 행에서
checked_count와 cited_count가 같은지 비교한다.

citation_rate도
cited_count / checked_count × 100으로 직접 계산하여 비교한다.
```

## 12-3. 질문 3 SQL

```sql
SELECT
    sr.search_run_id,
    p.post_id,
    p.post_url,
    k.keyword_text,
    sr.checked_at,
    COUNT(s.source_id) FILTER (
        WHERE s.normalized_source_url = p.normalized_url
    ) AS matching_source_count
FROM posts p
JOIN keywords k
    ON p.post_id = k.post_id
JOIN search_runs sr
    ON k.keyword_id = sr.keyword_id
LEFT JOIN sources s
    ON sr.search_run_id = s.search_run_id
WHERE sr.status = 'CITED'
GROUP BY
    sr.search_run_id,
    p.post_id,
    p.post_url,
    p.normalized_url,
    k.keyword_text,
    sr.checked_at
ORDER BY
    sr.checked_at DESC;
```

```text
예상 결과:
CITED로 기록된 검색 실행마다 한 행이 나온다.

각 행의 matching_source_count는
AI 브리핑 출처 중 추적 게시글과 URL이 일치하는 출처의 수이다.

프로젝트 규칙상 CITED라면
matching_source_count는 반드시 1 이상이어야 한다.

실제 결과:
미실행

검산 결과:
미실행

예상 검산 방법:
아래 SQL로
CITED인데 일치하는 출처가 없는 실행을 찾는다.

SELECT COUNT(*) AS invalid_cited_count
FROM (
    SELECT
        sr.search_run_id
    FROM posts p
    JOIN keywords k
        ON p.post_id = k.post_id
    JOIN search_runs sr
        ON k.keyword_id = sr.keyword_id
    LEFT JOIN sources s
        ON sr.search_run_id = s.search_run_id
       AND s.normalized_source_url = p.normalized_url
    WHERE sr.status = 'CITED'
    GROUP BY
        sr.search_run_id
    HAVING COUNT(s.source_id) = 0
) invalid_cited;

예상 검산값:
0

invalid_cited_count = 0이면
모든 CITED 검색 실행에 실제로 일치하는 출처가 존재한다.
```


> 아직 개인 프로젝트 테이블을 PostgreSQL로 완성하지 않았다면 SQL 초안과 예상 검산 방법까지만 작성하고 `미실행`이라고 명시합니다.

---

# 13. AI를 JOIN·집계 리뷰어로 활용

## 13-1. 내가 AI에게 전달한 질문

```text
naver-ai-briefing-tracker 프로젝트에서
게시글별 검색어마다 실제 확인 가능한 검색 중 인용 비율을 구하려고 한다.

테이블 관계는 다음과 같다.

posts 1:N keywords
keywords 1:N search_runs
search_runs 1:N sources

search_runs.status의 허용값은 다음과 같다.

CITED
NOT_CITED
NO_BRIEFING
CHECK_FAILED

내가 원하는 결과 한 행은
게시글-검색어 조합 1개이다.

인용 비율은
CITED / (CITED + NOT_CITED) × 100
으로 계산하려고 한다.

NO_BRIEFING과 CHECK_FAILED는 인용 여부를 정상적으로 판단한 실행이 아니므로
비율 계산에서는 제외하려고 한다.

아직 개인 프로젝트 테이블을 PostgreSQL에 완성하지 않았기 때문에
SQL은 실행하지 않은 초안이다.

아래 항목을 중심으로 내 JOIN과 집계 방식에 문제가 없는지 검토해줘.

1. 결과 한 행의 단위가 맞는지
2. 상태 범위가 맞는지
3. JOIN 경로가 맞는지
4. INNER JOIN과 LEFT JOIN 선택이 적절한지
5. COUNT 대상이 적절한지
6. 1:N JOIN 때문에 과대 집계될 위험이 있는지
7. 나중에 실제 데이터로 어떤 방식으로 상세 검산하면 좋은지
```

## 13-2. 내 SQL과 AI SQL 비교

| 검토 항목         | 내 판단/SQL                                                            | AI 제안                                                            | 최종 선택     | 이유                                                                                   |
| ------------- | ------------------------------------------------------------------- | ---------------------------------------------------------------- | --------- | ------------------------------------------------------------------------------------ |
| 결과 한 행        | 게시글-검색어 조합 1개                                                       | `post_id`, `keyword_id` 기준으로 GROUP BY                            | 내 방식 유지   | 업무 질문의 기준이 게시글별 검색어이므로 한 행 단위와 일치한다.                                                 |
| 상태 범위         | `CITED`, `NOT_CITED`만 포함                                            | `NO_BRIEFING`, `CHECK_FAILED`는 비율 계산에서 제외                        | AI 제안과 동일 | 두 상태는 인용 여부를 정상적으로 판단한 실행이 아니므로 인용 비율의 분모에 넣지 않는다.                                   |
| JOIN 경로       | `posts → keywords → search_runs`                                    | 동일한 경로 사용                                                        | 내 방식 유지   | 인용 비율 계산에는 `sources` 정보가 필요하지 않으므로 불필요한 JOIN을 추가하지 않는다.                              |
| INNER/LEFT 선택 | `posts → keywords`는 INNER JOIN, `keywords → search_runs`는 LEFT JOIN | 검색 실행이 아직 없는 검색어도 표시하려면 `search_runs`는 LEFT JOIN 사용              | AI 제안 수용  | 아직 실행되지 않은 검색어도 결과에서 사라지지 않고 `checked_count = 0`으로 확인할 수 있다.                         |
| COUNT 대상      | `COUNT(sr.search_run_id)`                                           | `COUNT(*)`보다 `COUNT(sr.search_run_id)` 사용 권장                     | AI 제안 수용  | LEFT JOIN에서는 일치하는 `search_runs`가 없어도 결과 행 자체는 존재하므로 `COUNT(*)`를 사용하면 1건으로 잘못 셀 수 있다. |
| 과대 집계 위험      | `sources`를 JOIN하지 않으므로 현재 SQL에서는 낮다고 판단                             | `sources`까지 JOIN하면 검색 실행 1건에 여러 출처가 연결되어 `search_runs`가 반복될 수 있음 | AI 제안 수용  | `search_runs 1:N sources` 관계 때문에 sources를 단순 JOIN하면 검색 실행 건수가 출처 수만큼 증가할 수 있다.       |
| 상세 검산 방법      | 특정 `keyword_id`를 선택해 상세 행과 집계 결과 비교                                 | `CITED`, `NOT_CITED` 상세 행 수와 집계값을 직접 비교                          | AI 제안과 동일 | 집계 결과만 확인하지 않고 원본 상세 행 수와 직접 대조할 수 있다.                                               |

### AI가 만든 SQL에서 발견한 위험 또는 확인한 점

```text
가장 중요하게 확인한 점은 COUNT(*)와 COUNT(sr.search_run_id)의 차이였다.

keywords와 search_runs를 LEFT JOIN하면
아직 검색 실행 기록이 없는 keyword도 결과에는 한 행이 남는다.

이 상태에서 COUNT(*)를 사용하면 실제 search_run이 0건인데도
JOIN 결과 행 자체를 1건으로 계산할 수 있다.

따라서 실제 검색 실행 건수를 세려면
NULL이 될 수 있는 search_runs의 PK인 search_run_id를 기준으로
COUNT(sr.search_run_id)를 사용하는 것이 더 적절하다.

또한 sources 테이블을 인용 비율 계산 SQL에 추가하면
search_runs 1건에 여러 sources가 연결될 수 있기 때문에
동일한 search_run이 여러 행으로 반복되어 COUNT가 과대 집계될 위험이 있다.

따라서 현재 질문에서는 sources를 JOIN하지 않고
posts → keywords → search_runs까지만 사용하는 것이 적절하다고 판단했다.

현재 개인 프로젝트 테이블은 PostgreSQL에 완성하지 않았으므로
실제 실행 및 검산은 미실행 상태이다.
```

### AI SQL이 실행 성공했다고 바로 정답이


---

# 14. 최종 성찰

아래 문장은 본인의 말로 작성합니다.

```text
1. JOIN SQL을 작성하기 전에 가장 먼저 정해야 하는 것은
   조회하고자 하는 목적이다.

2. LEFT JOIN에서 COUNT(*) 대신 COUNT(child.id)를 검토해야 하는 이유는
   count는 전체 행을 세는 반면 count(child.id)는 원하는 행을 세기 때문이다.

3. ON과 WHERE 조건 위치가 중요한 이유는
   위치에 따라 제외되는 위치가 다르기  때문이다.

4. 여러 1:N 관계를 JOIN한 뒤 바로 SUM하면 위험한 이유는
   중복 계산 될 수 있기 때문이다.

5. 집계 결과를 신뢰하기 전에 가장 좋은 검산 방법 중 하나는
   join 하지 않고 계산 해보는 것이다.
```

---

# 15. 제출 체크리스트

- [x] `chapter08_answer.md`를 본인 저장소에 만들었다.
- [x] `00_check_course_project.sql`이 통과했다.
- [x] 업무 질문마다 결과 한 행을 먼저 정의했다.
- [x] INNER JOIN과 다중 JOIN을 실행했다.
- [x] LEFT JOIN에서 0건 부모를 확인했다.
- [x] `COUNT(*)`와 `COUNT(child.id)` 차이를 설명했다.
- [x] ON과 WHERE 조건 위치 차이를 직접 비교했다.
- [x] `LEFT JOIN ... IS NULL`과 `NOT EXISTS`를 비교했다.
- [x] 전체/활성/취소 제외 기준값을 직접 검산했다.
- [x] `GROUP BY`, `HAVING`을 사용했다.
- [x] 과대 집계 오류와 수정 결과를 비교했다.
- [x] 상세 결과와 집계 결과를 교차 검산했다.
- [x] `03_join_aggregation_validation.sql`이 통과했다.
- [x] 개인 프로젝트 업무 질문 3개를 작성했다.
- [x] AI SQL을 실행 성공 여부가 아니라 의미와 검산 결과로 평가했다.
- [x] 핵심 캡처는 3~4장 정도만 사용했다.
- [x] 비밀번호·개인정보·비밀정보가 없다.
- [x] GitHub 웹에서 Markdown과 이미지가 정상적으로 보인다.
- [x] 최종 답안을 commit/push했다.

---

# 16. LMS 제출 URL

아래 형식의 **본인 GitHub 파일 URL**을 LMS에 제출합니다.

```text
https://github.com/<본인-GitHub-ID>/<본인-저장소>/blob/main/assignments/chapter08/chapter08_answer.md
```

내 제출 URL:

```text
https://github.com/sangjae-lee97/kant-axagent-study/blob/main/ai-database-study/assignments/chapter08/chapter08_answer.md
```

> 저장소 메인 URL, 교수자 템플릿 URL, Raw URL이 아니라 **작성 완료된 본인 `chapter08_answer.md` 파일 화면 URL**을 제출합니다.