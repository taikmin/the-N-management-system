# Supabase 스키마 마이그레이션 가이드

The N Resort Management의 호텔 스키마를 Supabase 프로젝트 `pxkgtciulauiruxsopcg`에 적용하는 절차입니다.

> ⚠️ **주의**: 이 마이그레이션은 기존 R&D 스키마의 테이블/함수/cron을 삭제합니다. 실행 전 백업 권장.

## 사전 준비

### 1. 확장 활성화 확인
Supabase Dashboard → **Database → Extensions** 에서 다음이 활성화되어 있는지 확인:
- `pg_cron` (스케줄러)
- `pg_net` (HTTP 요청, Resend API 호출용)

### 2. 백업 (선택)
Supabase Dashboard → **Database → Backups** 에서 최신 백업 생성 확인. 또는 CLI:
```
supabase db dump --project-ref pxkgtciulauiruxsopcg > backup_pre_hotel.sql
```

## 실행 순서

Supabase Dashboard → **SQL Editor** 에서 다음 파일을 **순서대로** 붙여넣기 → Run.

| 순서 | 파일 | 설명 | 위험도 |
|---|---|---|---|
| 1 | `hotel_001_profiles_alter.sql` | profiles 컬럼 조정 (role 매핑, Zoom 필드 삭제, 신규 필드 추가) | 낮음 |
| 2 | `hotel_002_departments.sql` | departments 테이블 + 5개 기본 부서 seed + profiles FK | 낮음 |
| 3 | `hotel_003_tasks_rebuild.sql` | tasks 필드 재정의 (R&D 컬럼 삭제, 신규 컬럼) | **중간 — 데이터 손실** |
| 4 | `hotel_004_settings.sql` | app_settings + digest_recipients | 낮음 |
| 5 | `hotel_005_activity_logs_alter.sql` | activity_logs entity_type 축소 (기존 projects/meetings 로그 삭제) | 중간 — 로그 손실 |
| 6 | `hotel_006_drop_legacy.sql` | **레거시 테이블 DROP** (projects/meetings/*/daily_logs/task_updates/task_comments) | **높음 — 되돌리기 불가** |
| 7 | `hotel_007_functions.sql` | 함수·트리거 (handle_new_user, log_activity, send_daily_digest, generate_recurring_tasks) | 낮음 |
| 8 | `hotel_008_rls.sql` | RLS 정책 | 낮음 |
| 9 | `hotel_009_cron.sql` | pg_cron 잡 등록 | 낮음 |

## 실행 후 필수 작업

### A. Resend API 키 반영
`hotel_007_functions.sql`의 `send_daily_digest()` 함수에 `Bearer YOUR_RESEND_API_KEY_HERE`가 하드코딩되어 있습니다. 실제 키로 교체:

**방법 1 (Dashboard UI)**:
1. Database → Functions → `send_daily_digest` → Edit
2. 함수 body의 `YOUR_RESEND_API_KEY_HERE` 부분을 실제 키(예: `re_CeMNv...`)로 교체
3. Save

**방법 2 (SQL Editor)**:
`hotel_007_functions.sql` 전체를 복사 → `YOUR_RESEND_API_KEY_HERE`를 실제 키로 치환 → SQL Editor에서 실행

**향후 개선** (Step 4 이후 권장):
- Supabase Vault 또는 `pg_settings`에 키 저장 → 함수는 참조만 (하드코딩 회피)

### B. 다이제스트 수신자 등록
SQL Editor에서:
```sql
INSERT INTO public.digest_recipients (email, label, is_active)
VALUES ('대표이메일@example.com', '대표', true);
```
또는 앱 배포 후 관리자 설정 화면에서 등록.

### C. 발송 시각 확인
기본값은 KST 18시. 변경 시:
```sql
UPDATE public.app_settings SET digest_send_hour = 20 WHERE id = 1;
```
(0~23 정수, KST 기준)

### D. Storage 버킷 확인/생성
현재 사용 중인 버킷 유지 (task-files, meeting-files, project-files) 또는 새 이름으로 생성:
- Supabase Dashboard → **Storage** → New bucket
- 권장: `task-photos` (task 완료 사진 저장용) 또는 기존 `task-files` 재사용

### E. 현재 사용자를 관리자로 설정
```sql
UPDATE public.profiles
SET role = 'manager', is_admin = true
WHERE email = 'lee.taikmin@gmail.com';
```

## 검증

### 1. 스키마 확인
Supabase Dashboard → **Database → Tables** 에서 다음 테이블 존재 확인:
- `profiles`, `departments`, `tasks`, `memos`, `activity_logs`, `file_attachments`, `app_settings`, `digest_recipients`

없어야 할 테이블: `projects`, `project_members`, `meetings`, `meeting_*`, `daily_logs`, `task_comments`, `task_updates`

### 2. 함수 확인
Database → Functions → 다음이 존재하는지:
- `handle_new_user`, `is_admin`, `log_activity`, `send_daily_digest`, `generate_recurring_tasks`, `update_updated_at`

### 3. Cron 잡 확인
```sql
SELECT jobname, schedule, command, active FROM cron.job WHERE jobname LIKE 'hotel_%';
```
2건 (`hotel_daily_digest`, `hotel_generate_recurring`)이 active=true여야 함.

### 4. 이메일 발송 테스트
```sql
-- 발송 시각을 현재 시각으로 임시 변경
UPDATE public.app_settings
SET digest_send_hour = EXTRACT(HOUR FROM (NOW() AT TIME ZONE 'Asia/Seoul'))::INT
WHERE id = 1;

-- 수동 실행
SELECT public.send_daily_digest();
```
등록한 수신자 이메일함 확인. 성공하면 원래 시각으로 되돌리기.

### 5. 반복 업무 생성 테스트
```sql
-- 반복 템플릿 하나 생성 (관리자 계정으로)
INSERT INTO public.tasks (
  title, department_id, assigner_id, assignee_id,
  recurrence_pattern, status
)
SELECT
  '매일 아침 로비 점검',
  (SELECT id FROM departments WHERE name = '프론트 데스크'),
  auth.uid(), auth.uid(),  -- 임시로 본인에게 할당
  'daily',
  'assigned'
WHERE auth.uid() IS NOT NULL;

-- 인스턴스 생성 함수 실행
SELECT public.generate_recurring_tasks();

-- 오늘자 인스턴스 조회
SELECT title, due_date, recurrence_template_id FROM public.tasks
WHERE recurrence_template_id IS NOT NULL
ORDER BY created_at DESC LIMIT 5;
```

## 문제 해결

### 마이그레이션 실행 중 에러
- `hotel_003`에서 `plan_type` 등 없다는 오류 → `IF EXISTS` 처리되어 있으니 무시 가능
- `hotel_006`에서 FK 오류 → CASCADE 처리되어 있으나 순서 문제일 수 있음. 개별 DROP 재시도.
- `pg_cron` 관련 오류 → Extensions에서 pg_cron/pg_net 활성화 확인

### 이메일이 발송되지 않음
1. `SELECT public.send_daily_digest();` 수동 실행 시 에러 확인
2. Resend Dashboard에서 API 호출 로그 확인 (401 = 키 오류)
3. `SELECT * FROM digest_recipients WHERE is_active;` — 수신자 있는지
4. `SELECT * FROM app_settings;` — digest_send_hour가 현재 시각과 일치하는지

### RLS로 인해 조회 안 됨
- 본인 계정이 `role = 'manager'` 또는 `is_admin = true` 인지 확인
- `SELECT public.is_admin(auth.uid());` — true 반환해야 함

## Step 2B 실행 (마이그레이션 완료 후)

호텔 스키마가 정상 동작하면, 참고용으로 남긴 원작자 SQL/문서 삭제:
- `supabase/migrations/*.sql` (원작자 것, hotel_*.sql만 남김)
- `supabase/functions/send-activity-digest/`
- `docs/database-schema.md`, `docs/architecture.md`, `docs/activity-digest-setup.md`, `docs/daily-log/`
