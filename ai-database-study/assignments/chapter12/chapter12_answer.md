# Chapter 12 확장 실습 답안 템플릿

> **과제:** 조회 패턴으로 RDBMS와 NoSQL 선택하기  
> **사용 방법:** 이 파일을 내려받아 본인의 GitHub 저장소에 `chapter12_answer.md`라는 이름으로 저장한 뒤 실습하면서 바로 작성합니다.  
> **제출 방법:** LMS에는 파일을 직접 업로드하지 않고, **본인 GitHub 저장소의 `chapter12_answer.md` 파일 URL**을 제출합니다.

---

## 제출 전 주의

이 파일과 캡처 화면에는 실제 비밀번호, 전체 DB 접속 URL, API Key, 개인정보를 기록하지 않습니다.

```text
GitHub 계정 또는 별칭:
과제 작성일:
PostgreSQL 버전:
사용한 AI 도구:
```

> 이번 장에서는 MongoDB, Redis, Cassandra, Graph DB 같은 별도 서버를 반드시 설치하지 않습니다.  
> 제공된 PostgreSQL `nosql_lab`을 이용해 **원본·파생·캐시·문서·저장소 선택 기준**을 실습합니다.

---

# 1. 시작 환경과 Chapter 07 기준 상태 확인

다음을 실행합니다.

```sql
SELECT current_database();
SELECT current_user;
SELECT current_schema();
SHOW search_path;
```

| 확인 항목 | 실제 결과 | 의미 |
| --- | --- | --- |
| `current_database()` |  |  |
| `current_user` |  |  |
| `current_schema()` |  |  |
| `search_path` |  |  |

Chapter 07·08 기준 상태도 확인합니다.

```text
students = 3
instructors = 2
courses = 3
enrollments = 5

전체 recorded_amount = 590000
활성 = 3건 / 340000
취소 제외 = 4건 / 440000
```

### 기준 상태를 유지한 채 별도 `nosql_lab`에서 실습하는 이유

```text

```

---

# 2. 온라인 강의 데이터의 시스템 역할 분류

다음 데이터를 분류합니다.

| 데이터 | 시스템 역할 | Source of Truth 여부 | 잃어버리면 재구축 가능? | 이유 |
| --- | --- | --- | --- | --- |
| 수강신청 |  |  |  |  |
| 신청 당시 금액 |  |  |  |  |
| 로그인 세션 |  |  |  |  |
| 인기 강의 TOP 3 |  |  |  |  |
| 강의 태그/옵션 |  |  |  |  |
| 학습 행동 이벤트 |  |  |  |  |
| 추천 관계 |  |  |  |  |

사용 가능한 역할 예:

```text
Source of Truth
Derived Cache
Ephemeral State
Flexible Metadata
Event Log
Relationship Index
```

### Source of Truth와 파생 저장소를 구분해야 하는 이유

```text

```

---

# 3. 저장소보다 먼저 조회·쓰기 패턴 정의

최소 6개의 읽기/쓰기 문장을 작성합니다.

| ID | 읽기/쓰기 문장 | 키/조건 | 정렬/범위 | 예상 빈도 | 일관성 요구 | 함께 원자적으로 맞아야 하는 데이터 |
| --- | --- | --- | --- | --- | --- | --- |
| Q01 |  |  |  |  |  |  |
| Q02 |  |  |  |  |  |  |
| Q03 |  |  |  |  |  |  |
| Q04 |  |  |  |  |  |  |
| Q05 |  |  |  |  |  |  |
| Q06 |  |  |  |  |  |  |

### 기술 이름보다 조회 패턴을 먼저 작성해야 하는 이유

```text

```

---

# 4. `nosql_lab` 생성과 기준 데이터 확인

다음 파일을 순서대로 실행합니다.

```text
code/chapter12/01_nosql_lab_schema.sql
code/chapter12/02_nosql_lab_seed.sql
```

## 4-1. 기준 행 수

| 테이블 | 기대 행 수 | 실제 행 수 | 일치? |
| --- | ---: | ---: | --- |
| `nosql_lab.course_documents` | 3 |  |  |
| `nosql_lab.key_value_cache_examples` | 4 |  |  |
| `nosql_lab.storage_choice_cases` | 6 |  |  |

## 4-2. 원본 매핑 확인

| source_course_id | 기대 course_code | 실제 title | 원본과 일치? |
| ---: | --- | --- | --- |
| 301 | `COURSE-301` |  |  |
| 302 | `COURSE-302` |  |  |
| 303 | `COURSE-303` |  |  |

### 증거 화면

권장 경로:

```text
assignments/chapter12/images/step04_nosql_lab.png
```

`여기에 nosql_lab 기준 상태 확인 화면을 삽입하세요.`

---

# 5. PostgreSQL JSONB 혼합 문서 실습

다음을 실행합니다.

```text
code/chapter12/03_document_jsonb_queries.sql
```

## 5-1. 일반 컬럼과 JSONB 영역 구분

| 항목 | 일반 컬럼 / JSONB | 그렇게 둔 이유 |
| --- | --- | --- |
| `source_course_id` |  |  |
| `course_code` |  |  |
| `title` |  |  |
| `level` |  |  |
| `document_version` |  |  |
| `tags` |  |  |
| `options` |  |  |
| `instructor_snapshot` |  |  |

### `level`을 JSONB 안에 넣지 않고 일반 컬럼으로 둔 이유

```text

```

### `instructor_snapshot`이 Source of Truth가 아닌 이유

```text

```

## 5-2. JSONB 조회 결과

```text
사용한 JSONB 조건:
예상 결과:
실제 결과:
```

```sql

```

## 5-3. 낙관적 잠금 관찰

```text
읽은 document_version:
UPDATE 조건에 사용한 version:
예상 영향 행 수:
실제 영향 행 수:
```

### 영향 행 수가 0이면 무엇을 의심해야 하나요?

```text

```

### 실습에서 ROLLBACK 후 기준 상태를 유지하는 이유

```text

```

---

# 6. Key-Value 캐시 개념 실습

다음을 실행합니다.

```text
code/chapter12/04_key_value_cache_queries.sql
```

## 6-1. Seed 기준

```text
전체 캐시 = 4
Seed 시점 유효 = 3
Seed 시점 만료 = 1
```

| 항목 | 기대 | 실제 |
| --- | ---: | ---: |
| 전체 | 4 |  |
| Seed 시점 유효 | 3 |  |
| Seed 시점 만료 | 1 |  |

## 6-2. Seed 기준과 현재 시각 기준 차이

```text
현재 유효 캐시 수:
```

### 현재 유효 건수를 고정 정답으로 사용하면 안 되는 이유

```text

```

## 6-3. 정확 키 조회

```text
조회한 키:
결과:
캐시 미스 여부:
```

### Key-Value 제품의 TTL과 eviction을 같은 개념으로 보면 안 되는 이유

```text

```

### 이 PostgreSQL 테이블이 실제 Redis 같은 Key-Value DB가 아닌 이유

```text

```

---

# 7. 캐시 장애 사고 실험

상황:

```text
PostgreSQL 원본에서는 인기 강의 순위가 변경되었다.
캐시에는 이전 TOP 3가 남아 있다.
```

다음에 답합니다.

```text
신뢰해야 할 원본:
사용자에게 오래된 값을 허용할 수 있는 시간:
캐시 갱신 방식:
캐시 삭제 후 재생성 방법:
캐시 서버 장애 시 fallback:
동시 재생성 요청이 몰릴 때의 위험:
```

### 캐시가 Source of Truth가 되어서는 안 되는 이유

```text

```

---

# 8. 저장 방식 선택 사례 검토

다음을 실행합니다.

```text
code/chapter12/05_storage_choice_review.sql
```

각 사례에서 최소 다음 정보를 확인합니다.

| 사례 | system_role | primary_query | 후보 저장소 | consistency | sync 전략 | recovery 전략 | decision_status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 |  |  |  |  |  |  |  |
| 2 |  |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |  |
| 4 |  |  |  |  |  |  |  |
| 5 |  |  |  |  |  |  |  |
| 6 |  |  |  |  |  |  |  |

결정 상태:

```text
candidate
poc_planned
hold
adopted
rejected
```

### 후보 저장소와 실제 채택을 구분해야 하는 이유

```text

```

### 현재 데이터에서 `adopted`가 PostgreSQL 원본 1건뿐인 이유를 자신의 말로 설명

```text

```

---

# 9. 저장 모델 비교표

제품 이름보다 저장 모델을 비교합니다.

| 후보 | 잘 맞는 접근 패턴 | 트랜잭션/일관성 고려 | 재구축 가능성 | 운영·보안·백업 부담 | 현재 판단 |
| --- | --- | --- | --- | --- | --- |
| PostgreSQL RDBMS |  |  |  |  |  |
| PostgreSQL JSONB |  |  |  |  |  |
| Key-Value |  |  |  |  |  |
| Document |  |  |  |  |  |
| Column-Family |  |  |  |  |  |
| Graph |  |  |  |  |  |

### “NoSQL은 항상 더 빠르다”가 잘못된 설명인 이유

```text

```

### 저장소가 하나 추가될 때 새로 생기는 운영 책임 최소 5개

```text
1.
2.
3.
4.
5.
```

---

# 10. JSONB 인덱스 후보 관찰

다음을 실행합니다.

```text
code/chapter12/06_jsonb_index_candidates.sql
```

본문 후보:

```text
metadata @> ...
→ GIN 후보

metadata #>> '{options,online}' = 'true'
→ 표현식 B-tree 후보
```

## 10-1. 생성된 인덱스

| 인덱스 | 대상 표현식/컬럼 | 대응 조회 | 실제 정의 확인 |
| --- | --- | --- | --- |
|  |  |  |  |
|  |  |  |  |

### 데이터가 3행뿐이라 인덱스가 있어도 Seq Scan이 합리적일 수 있는 이유

```text

```

### `jsonb_ops`와 `jsonb_path_ops`를 무조건 같은 것으로 보면 안 되는 이유

```text

```

---

# 11. 최종 자동 검증

다음을 실행합니다.

```text
code/chapter12/07_nosql_lab_validation.sql
```

기대 메시지:

```text
Chapter 12 nosql_lab validation passed
```

```text
실제 검증 메시지:
```

검증되는 주요 내용:

```text
Chapter 07 기준 상태 유지
nosql_lab = 3 / 4 / 6
강의 301~303 원본 매핑
instructor_snapshot 원본 대조
JSONB 구조와 document_version 기준 유지
Seed 캐시 = 4 / 3 / 1
저장소 선택 근거 공백 0
adopted 사례 1
JSONB 인덱스 정의
```

### 자동 검증이 통과해도 저장소 선택이 자동으로 정답이 되는 것은 아닌 이유

```text

```

### 증거 화면

권장 경로:

```text
assignments/chapter12/images/step11_validation.png
```

`여기에 최종 검증 통과 화면을 삽입하세요.`

---

# 12. 개인 프로젝트의 데이터 역할 분류

Chapter 07부터 발전시킨 개인 프로젝트를 사용합니다.

최소 6개 데이터 항목을 분류합니다.

| 데이터 | 시스템 역할 | Source of Truth? | 대표 조회/쓰기 | 트랜잭션 필요? | 재구축 가능? | 저장소 후보 |
| --- | --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |

---

# 13. 개인 프로젝트 저장 전략 결정

## 13-1. Source of Truth

```text
내 프로젝트의 Source of Truth:
그 이유:
```

## 13-2. PostgreSQL만 유지할지, 다른 저장 모델을 검토할지

```text
현재 결정:
PostgreSQL만 사용 / JSONB 추가 / Key-Value 후보 / Document 후보 / 기타
```

### 결정 근거

```text
주요 조회 패턴:
일관성 요구:
파생 데이터 여부:
재구축 가능 여부:
운영 부담:
백업/복구 부담:
현재 팀 역량:
```

> **“현재는 PostgreSQL만 사용한다”도 충분히 좋은 결론입니다.**  
> 기술을 추가하지 않는 이유를 조회 패턴·일관성·운영 책임으로 설명할 수 있어야 합니다.

---

# 14. 작은 PoC 설계

후보 저장 방식 하나를 골라 실제 도입 전에 확인할 PoC를 설계합니다.

```text
후보 저장 방식:
시스템 역할:
Source of Truth 여부:
키/문서/파티션/관계 구조:
대표 읽기 2개:
대표 쓰기 1개:
원본 동기화 방법:
중복/재시도 시 멱등성 처리:
장애 시 fallback:
재구축 방법:
보안 요구:
백업/복구 방법:
```

## PoC 성공 기준

최소 5개를 작성합니다.

```text
1.
2.
3.
4.
5.
```

---

# 15. AI를 저장소 선택 리뷰어로 활용

## 15-1. 내가 AI에게 제공한 정보

```text
Source of Truth:
반복 조회/쓰기 패턴:
트랜잭션 범위:
허용 가능한 불일치:
재구축 가능 여부:
운영·보안·백업 조건:
```

## 15-2. AI 제안 검토

| AI 제안 | 수용 / 수정 / 보류 / 거절 | 근거 |
| --- | --- | --- |
|  |  |  |
|  |  |  |
|  |  |  |
|  |  |  |

### AI가 기술 이름만 보고 추천한 부분이 있었나요?

```text

```

### AI가 놓친 동기화·복구·운영 비용이 있었나요?

```text

```

### AI 제안보다 내가 최종적으로 다르게 판단한 부분

```text

```

---

# 16. 이번 Chapter에서 알게 된 점

다음 문장을 자신의 말로 완성합니다.

```text
1. Source of Truth란 ________________________________________________ 이다.

2. 파생 저장소를 추가할 때 반드시 생각해야 할 것은 __________________ 이다.

3. NoSQL을 선택해야 하는 가장 좋은 이유는 “최신 기술”이 아니라 __________ 이다.

4. 현재 내 프로젝트에서 가장 적절한 저장 전략은 ________________________ 이다.
```

---

# 17. 핵심 증거 화면

권장 3~4장만 사용합니다.

```text
assignments/chapter12/images/step04_nosql_lab.png
assignments/chapter12/images/step05_jsonb.png
assignments/chapter12/images/step06_cache.png
assignments/chapter12/images/step11_validation.png
```

화면 캡처만 제출하지 않습니다. 반드시 각 결과의 의미를 Markdown에 설명합니다.

---

# 18. GitHub 제출 확인

```bash
git status
git add assignments/chapter12
git commit -m "docs: complete chapter12 assignment"
git push
```

GitHub 웹에서 다음을 확인합니다.

```text
chapter12_answer.md가 정상 표시된다.
이미지가 정상 표시된다.
실제 비밀번호·접속 URL·API Key가 없다.
SQL과 결과 해석이 함께 있다.
개인 프로젝트 저장 전략이 작성되어 있다.
AI 제안에 대한 내 판단이 작성되어 있다.
```

---

# 19. LMS 제출 URL

LMS에는 다음 형태의 **본인 파일 URL 하나**를 제출합니다.

```text
https://github.com/<본인-GitHub-ID>/<본인-저장소>/blob/main/assignments/chapter12/chapter12_answer.md
```

다음을 제출하면 안 됩니다.

```text
교수자 답안 템플릿 URL
본인 저장소 메인 URL
로컬 PC 파일 경로
Raw 파일 주소만 제출
```

---

# 최종 자기 점검

- [ ] PostgreSQL 연결과 Chapter 07 기준 상태를 확인했다.
- [ ] 원본·파생·캐시·이벤트·관계 인덱스를 구분했다.
- [ ] 조회/쓰기 패턴을 최소 6개 작성했다.
- [ ] `nosql_lab` 3/4/6 기준을 확인했다.
- [ ] 일반 컬럼과 JSONB의 역할 차이를 설명했다.
- [ ] 낙관적 잠금의 영향 행 수를 해석했다.
- [ ] Seed 캐시 4/3/1과 현재 시각 기준을 구분했다.
- [ ] 캐시 장애 시 Source of Truth와 복구 흐름을 설명했다.
- [ ] 후보 저장소와 실제 채택을 구분했다.
- [ ] JSONB 인덱스 후보를 조회 패턴과 연결했다.
- [ ] `07_nosql_lab_validation.sql`을 통과했다.
- [ ] 개인 프로젝트의 Source of Truth를 정했다.
- [ ] NoSQL이 필요 없다면 그 이유도 설명했다.
- [ ] PoC 성공 기준을 작성했다.
- [ ] AI 제안을 수용/수정/보류/거절로 판단했다.
- [ ] 핵심 캡처를 3~4장 이내로 정리했다.
- [ ] GitHub 웹에서 Markdown과 이미지를 최종 확인했다.
- [ ] LMS에는 본인 `chapter12_answer.md` URL을 제출한다.