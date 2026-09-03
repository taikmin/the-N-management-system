# 활동 요약 이메일 설정 가이드

## 개요
팀원이 과제/업무/회의/메모를 생성·수정·삭제·완료하면, 3시간마다 변경 요약을 이메일로 받습니다.

**방식**: Edge Function 없이 PostgreSQL에서 직접 Resend API 호출 (pg_net + pg_cron)

## 구성 요소
1. **activity_logs 테이블** — DB 트리거가 자동으로 변경사항 기록 (migration 023)
2. **send_activity_digest()** — SQL 함수가 미발송 로그를 HTML 이메일로 발송 (migration 024)
3. **pg_cron** — 3시간마다 자동 실행 (migration 024)

## 현재 설정
- **발신자**: `noreply@sartexo.com` (Resend 커스텀 도메인)
- **수신자**: `parkch@kimm.re.kr`
- **주기**: 3시간 (`0 */3 * * *`)
- **이메일 서비스**: [Resend](https://resend.com) (무료: 100통/일)

---

## 1단계: Extensions 활성화

Supabase Dashboard → Database → Extensions에서:

1. `pg_cron` 검색 → Enable
2. `pg_net` 검색 → Enable

---

## 2단계: Migration 023 실행 (활동 로그)

Supabase Dashboard → SQL Editor에서 실행:

```
supabase/migrations/20260307_023_activity_logs.sql
```

생성되는 항목:
- `activity_logs` 테이블 + 인덱스 + RLS
- `log_activity()` 트리거 함수 (SECURITY DEFINER)
- 5개 테이블 트리거: tasks, projects, meetings, memos, meeting_timeline
- 연계업무 생성 시 상위 독립업무 제목 자동 기록 (`details.parent_task_title`)

실행 후 바로 활동 기록이 시작됩니다 (앱 대시보드 "최근 팀 활동" 패널에서 확인).

---

## 3단계: Resend 계정 설정

1. [Resend](https://resend.com) 가입 (무료: 100통/일, 3,000통/월)
2. Dashboard → API Keys → Create API Key
3. API 키 복사 (`re_`로 시작)

### 커스텀 도메인 설정 (현재: sartexo.com)
1. Resend → Domains → Add Domain → `sartexo.com`
2. DNS 레코드 추가 (MX, SPF, DKIM)
3. 인증 완료 후 `noreply@sartexo.com`에서 발송 가능

---

## 4단계: Migration 024 실행 (이메일 발송 + 스케줄)

Supabase Dashboard → SQL Editor에서 실행:

```
supabase/migrations/20260307_024_activity_digest_cron.sql
```

> **주의**: 실행 전 SQL 파일 내 Resend API 키를 실제 값으로 확인하세요.

생성되는 항목:
- `send_activity_digest()` 함수 (pg_net으로 Resend API 직접 호출)
- pg_cron 스케줄: `activity-digest` (3시간마다)

---

## 수동 테스트

```sql
-- 수동 실행 (미발송 활동이 있을 때)
SELECT send_activity_digest();

-- 미발송 활동 수 확인
SELECT COUNT(*) FROM activity_logs WHERE notified = false;

-- 최근 활동 확인
SELECT * FROM activity_logs ORDER BY created_at DESC LIMIT 10;
```

---

## 주기 변경

```sql
-- 기존 스케줄 삭제
SELECT cron.unschedule('activity-digest');

-- 새 주기로 등록
SELECT cron.schedule(
  'activity-digest',
  '0 */6 * * *',  -- 원하는 주기로 변경
  'SELECT send_activity_digest()'
);
```

| 설정 | Cron 표현식 |
|------|-------------|
| 1시간마다 | `0 * * * *` |
| 3시간마다 | `0 */3 * * *` |
| 6시간마다 | `0 */6 * * *` |
| 매일 오전 9시 | `0 9 * * *` |
| 평일 오전 9시 | `0 9 * * 1-5` |

---

## 수신자/발신자 변경

`send_activity_digest()` 함수 내에서 직접 수정:

```sql
CREATE OR REPLACE FUNCTION send_activity_digest()
RETURNS void AS $$
...
  -- 발신자 변경
  'from', 'R&D Task Manager <noreply@sartexo.com>',
  -- 수신자 변경 (배열)
  'to', jsonb_build_array('new-email@example.com'),
...
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 트러블슈팅

### 활동이 기록되지 않는 경우
```sql
-- 트리거 확인
SELECT tgname FROM pg_trigger WHERE tgname LIKE 'trg_activity%';

-- 최근 활동 확인
SELECT * FROM activity_logs ORDER BY created_at DESC LIMIT 10;
```

### 이메일이 발송되지 않는 경우
```sql
-- pg_net 요청 로그 확인
SELECT * FROM net._http_response ORDER BY created DESC LIMIT 5;

-- 미발송 레코드 확인
SELECT COUNT(*) FROM activity_logs WHERE notified = false;

-- pg_cron 작업 확인
SELECT * FROM cron.job;

-- pg_cron 실행 이력 확인
SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 5;
```

### Resend API 키 변경
SQL Editor에서 `send_activity_digest()` 함수의 `Authorization` 헤더 값을 업데이트하세요.
