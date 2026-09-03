# Database Schema - R&D Task Manager

Last updated: 2026-03-07

## ER Diagram (Simplified)
```
profiles ─────────┬──── project_members ──── projects
   │              │                             │
   │              │    ┌────────────────────────┤
   │              │    │                        │
   ├──── tasks ◄──┘    │    meetings ◄──────────┘
   │       │           │       │
   │       ├── daily_logs      ├── meeting_participants
   │       │                   ├── meeting_documents
   │       └── task_comments   ├── meeting_agenda
   │                           └── meeting_timeline
   │
   └──── file_attachments (polymorphic)
```

## Tables

### 1. profiles
사용자 프로필 (auth.users와 1:1 연결, 가입 시 자동 생성)

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | - | PK, FK to auth.users |
| email | TEXT | NO | - | 이메일 |
| full_name | TEXT | NO | '' | 이름 |
| department | TEXT | YES | - | 부서/연구실 |
| position | TEXT | YES | - | 직위 |
| avatar_url | TEXT | YES | - | 프로필 이미지 |
| role | TEXT | NO | 'researcher' | pi/researcher/external_ |
| is_admin | BOOLEAN | NO | false | 사이트 관리자 |
| default_zoom_link | TEXT | YES | - | Zoom 기본 링크 |
| default_zoom_id | TEXT | YES | - | Zoom 기본 회의 ID |
| default_zoom_password | TEXT | YES | - | Zoom 기본 비밀번호 |
| created_at | TIMESTAMPTZ | NO | NOW() | |
| updated_at | TIMESTAMPTZ | NO | NOW() | |

### 2. projects
R&D 과제 관리

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | gen_random_uuid() | PK |
| title | TEXT | NO | - | 과제명 |
| project_number | TEXT | YES | - | 과제번호 (예: 2026-R-001) |
| description | TEXT | YES | - | 설명 |
| status | TEXT | NO | 'planning' | planning/active/completed/on_hold/cancelled |
| start_date | DATE | YES | - | 시작일 |
| end_date | DATE | YES | - | 종료일 |
| lead_institution | TEXT | YES | '한국기계연구원' | 주관기관 |
| co_institutions | TEXT[] | YES | {} | 공동연구기관 |
| total_budget | BIGINT | YES | 0 | 총연구비 (원) |
| owner_id | UUID | NO | - | FK to profiles (책임자/PI) |
| assignee_id | UUID | YES | - | FK to profiles (담당자/실무) |
| created_at | TIMESTAMPTZ | NO | NOW() | |
| updated_at | TIMESTAMPTZ | NO | NOW() | |

### 3. project_members
과제 참여 멤버 (UNIQUE(project_id, user_id))

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | gen_random_uuid() | PK |
| project_id | UUID | NO | - | FK to projects (CASCADE) |
| user_id | UUID | NO | - | FK to profiles (CASCADE) |
| role | TEXT | NO | 'member' | owner/admin/member/viewer |
| joined_at | TIMESTAMPTZ | NO | NOW() | |

### 4. tasks
업무/태스크 (독립 태스크 지원)

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | gen_random_uuid() | PK |
| project_id | UUID | YES | - | FK to projects (CASCADE). NULL=독립 태스크 |
| parent_task_id | UUID | YES | - | FK to tasks (자기참조, SET NULL) |
| title | TEXT | NO | - | 제목 |
| description | TEXT | YES | - | 설명 |
| status | TEXT | NO | 'planned' | planned/in_progress/delayed/completed/blocked |
| priority | TEXT | NO | 'medium' | low/medium/high/urgent |
| plan_type | TEXT | NO | 'A' | A/B/C |
| assignee_id | UUID | YES | - | FK to profiles (SET NULL) |
| created_by | UUID | YES | auth.uid() | FK to profiles. 등록자 |
| planned_start | DATE | YES | - | 계획 시작일 |
| planned_end | DATE | YES | - | 계획 종료일 |
| actual_start | DATE | YES | - | 실제 시작일 |
| actual_end | DATE | YES | - | 실제 종료일 |
| order_index | INT | NO | 0 | 정렬 순서 |
| category | TEXT | YES | - | 독립 태스크 카테고리 |
| color_tag | TEXT | NO | 'none' | red/yellow/blue/none |
| show_in_calendar | BOOLEAN | NO | false | 캘린더 표시 여부 |
| created_at | TIMESTAMPTZ | NO | NOW() | |
| updated_at | TIMESTAMPTZ | NO | NOW() | |

### 5. daily_logs
일일 수행 기록

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | gen_random_uuid() | PK |
| task_id | UUID | NO | - | FK to tasks (CASCADE) |
| author_id | UUID | NO | - | FK to profiles (CASCADE) |
| log_date | DATE | NO | CURRENT_DATE | 기록 날짜 |
| content | TEXT | NO | - | 수행내용 |
| issues | TEXT | YES | - | 이슈사항 |
| next_plan | TEXT | YES | - | 다음 계획 |
| created_at | TIMESTAMPTZ | NO | NOW() | |
| updated_at | TIMESTAMPTZ | NO | NOW() | |

### 6. task_comments
태스크 댓글

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | gen_random_uuid() | PK |
| task_id | UUID | NO | - | FK to tasks (CASCADE) |
| author_id | UUID | NO | - | FK to profiles (CASCADE) |
| content | TEXT | NO | - | 댓글 내용 |
| created_at | TIMESTAMPTZ | NO | NOW() | |
| updated_at | TIMESTAMPTZ | NO | NOW() | |

### 7. meetings
회의 관리 (대면/비대면/하이브리드)

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | gen_random_uuid() | PK |
| project_id | UUID | NO | - | FK to projects (CASCADE) |
| title | TEXT | NO | - | 회의명 |
| meeting_type | TEXT | NO | 'progress_check' | progress_check/kickoff/mid_presentation/final_presentation/other |
| meeting_mode | TEXT | NO | 'in_person' | in_person/online/hybrid |
| meeting_date | TIMESTAMPTZ | NO | - | 회의 일시 |
| location | TEXT | YES | - | 장소 |
| room_name | TEXT | YES | - | 회의실 |
| status | TEXT | NO | 'preparing' | preparing/notified/in_progress/completed |
| meal_reservation | BOOLEAN | YES | false | 식사 예약 |
| meal_location | TEXT | YES | - | 식사 장소 |
| expected_attendees | INT | YES | 0 | 예상 참석인원 |
| description | TEXT | YES | - | 비고 |
| online_platform | TEXT | YES | - | Zoom/Google Meet/Teams/Webex/기타 |
| online_link | TEXT | YES | - | 회의 링크 URL |
| online_meeting_id | TEXT | YES | - | 회의 ID |
| online_password | TEXT | YES | - | 회의 비밀번호 |
| meeting_notes | TEXT | YES | - | AI 생성 회의록 |
| raw_transcript | TEXT | YES | - | 음성인식 원문 |
| creator_id | UUID | NO | - | FK to profiles |
| created_at | TIMESTAMPTZ | NO | NOW() | |
| updated_at | TIMESTAMPTZ | NO | NOW() | |

### 8. meeting_participants
회의 참석자 (UNIQUE(meeting_id, user_id))

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | gen_random_uuid() | PK |
| meeting_id | UUID | NO | - | FK to meetings (CASCADE) |
| user_id | UUID | NO | - | FK to profiles (CASCADE) |
| institution | TEXT | YES | - | 소속 기관 |
| attendance | TEXT | NO | 'pending' | pending/confirmed/declined |
| role | TEXT | NO | 'attendee' | organizer/presenter/attendee |
| created_at | TIMESTAMPTZ | NO | NOW() | |

### 9. meeting_documents
회의 문서 추적

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | gen_random_uuid() | PK |
| meeting_id | UUID | NO | - | FK to meetings (CASCADE) |
| doc_type | TEXT | NO | 'other' | template/submission/compiled/minutes/other |
| title | TEXT | NO | - | 문서 제목 |
| file_url | TEXT | YES | - | 파일 URL |
| file_name | TEXT | YES | - | 파일명 |
| file_size | BIGINT | YES | 0 | 파일 크기 |
| uploader_id | UUID | NO | - | FK to profiles |
| target_user_id | UUID | YES | - | FK to profiles |
| due_date | TIMESTAMPTZ | YES | - | 제출 마감일 |
| submit_status | TEXT | NO | 'not_submitted' | not_submitted/submitted/revision_requested |
| created_at | TIMESTAMPTZ | NO | NOW() | |
| updated_at | TIMESTAMPTZ | NO | NOW() | |

### 10. meeting_agenda
회의 안건

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | gen_random_uuid() | PK |
| meeting_id | UUID | NO | - | FK to meetings (CASCADE) |
| order_index | INT | NO | 0 | 순서 |
| title | TEXT | NO | - | 안건 제목 |
| presenter_id | UUID | YES | - | FK to profiles |
| duration_minutes | INT | YES | 10 | 예상 소요시간 |
| related_project_id | UUID | YES | - | FK to projects |
| description | TEXT | YES | - | 설명 |
| created_at | TIMESTAMPTZ | NO | NOW() | |
| updated_at | TIMESTAMPTZ | NO | NOW() | |

### 11. meeting_timeline
회의 준비 타임라인

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | gen_random_uuid() | PK |
| meeting_id | UUID | NO | - | FK to meetings (CASCADE) |
| milestone | TEXT | NO | - | 마일스톤 키 |
| label | TEXT | NO | - | 표시 라벨 |
| due_date | TIMESTAMPTZ | NO | - | 마감일 |
| is_completed | BOOLEAN | YES | false | 완료 여부 |
| completed_at | TIMESTAMPTZ | YES | - | 완료 일시 |
| notification_sent | BOOLEAN | YES | false | 알림 발송 여부 |
| sort_order | INT | YES | 0 | 드래그 앤 드롭 정렬 순서 |
| created_at | TIMESTAMPTZ | NO | NOW() | |

### 12. file_attachments
범용 파일 첨부 (다형성)

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | gen_random_uuid() | PK |
| file_name | TEXT | NO | - | 파일명 |
| file_size | BIGINT | NO | 0 | 파일 크기 (bytes) |
| mime_type | TEXT | YES | - | MIME 타입 |
| storage_path | TEXT | NO | - | Storage 버킷 경로 |
| bucket_name | TEXT | NO | - | project-files/task-files/meeting-files |
| entity_type | TEXT | NO | - | project/task/daily_log/meeting/meeting_document |
| entity_id | UUID | NO | - | 부모 엔티티 ID |
| uploader_id | UUID | NO | - | FK to auth.users |
| description | TEXT | YES | - | 설명 |
| created_at | TIMESTAMPTZ | YES | now() | |
| updated_at | TIMESTAMPTZ | YES | now() | |

### 13. memos
개인 메모 (완전 개인 영역, Admin도 타인 메모 접근 불가)

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | gen_random_uuid() | PK |
| user_id | UUID | NO | - | FK to profiles (CASCADE) |
| title | TEXT | NO | '' | 메모 제목 |
| content | TEXT | YES | '' | 메모 내용 |
| category | TEXT | YES | - | 아이디어/메모/할일/기타 |
| is_pinned | BOOLEAN | NO | false | 상단 고정 |
| priority | TEXT | NO | 'none' | high/medium/low/none |
| status | TEXT | NO | 'active' | active/archived |
| created_at | TIMESTAMPTZ | NO | NOW() | |
| updated_at | TIMESTAMPTZ | NO | NOW() | |

### 14. task_updates
연계 업무 (태스크에 대한 진행 업데이트)

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | gen_random_uuid() | PK |
| task_id | UUID | NO | - | FK to tasks (CASCADE) |
| author_id | UUID | NO | - | FK to profiles (CASCADE) |
| content | TEXT | NO | - | 업데이트 내용 |
| created_at | TIMESTAMPTZ | NO | NOW() | |

### 15. activity_logs
팀원 활동 변경사항 자동 기록 (DB 트리거)

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | gen_random_uuid() | PK |
| user_id | UUID | YES | - | FK to auth.users (SET NULL) |
| user_name | TEXT | YES | - | 사용자 이름 (스냅샷) |
| action | TEXT | NO | - | create/update/delete/complete |
| entity_type | TEXT | NO | - | tasks/projects/meetings/memos/meeting_timeline |
| entity_id | UUID | YES | - | 대상 엔티티 ID |
| entity_title | TEXT | YES | - | 대상 제목 (스냅샷) |
| details | JSONB | YES | - | 변경 상세 (이전값/새값) |
| created_at | TIMESTAMPTZ | YES | now() | |
| notified | BOOLEAN | YES | false | 이메일 발송 여부 |

## Helper Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `update_updated_at()` | TRIGGER | updated_at = NOW() on update |
| `handle_new_user()` | TRIGGER | 가입 시 profiles 자동 생성 (SECURITY DEFINER) |
| `is_admin()` | BOOLEAN | 현재 사용자 admin 여부 (SECURITY DEFINER STABLE) |
| `log_activity()` | TRIGGER | 활동 로그 자동 기록 (SECURITY DEFINER) |
| `send_activity_digest()` | void | 미발송 활동을 HTML 이메일로 발송 (pg_net + Resend, SECURITY DEFINER) |

## Storage Buckets

| Bucket | Purpose |
|--------|---------|
| project-files | 과제 관련 첨부 파일 |
| task-files | 태스크/일일기록 첨부 파일 |
| meeting-files | 회의 첨부 파일 |

## RLS Policy Summary

**원칙: 메모만 개인, 나머지는 전부 공용 (인증 사용자 공유)**

- **profiles**: 인증 사용자 전체 조회, 본인 or admin만 수정
- **projects**: 인증 사용자 전체 CRUD, 삭제는 admin만
- **project_members**: 인증 사용자 전체 조회/추가/수정, 삭제는 admin만
- **tasks**: 인증 사용자 전체 CRUD, 삭제는 admin만
- **daily_logs**: 인증 사용자 전체 CRUD, 삭제는 admin만
- **task_comments**: 인증 사용자 전체 CRUD, 삭제는 admin만
- **meetings**: 인증 사용자 전체 CRUD, 삭제는 admin만
- **meeting_participants**: 인증 사용자 전체 CRUD, 삭제는 admin만
- **meeting_documents**: 인증 사용자 전체 CRUD, 삭제는 admin만
- **meeting_agenda**: 인증 사용자 전체 CRUD, 삭제는 admin만
- **meeting_timeline**: 인증 사용자 전체 CRUD, 삭제는 admin만
- **file_attachments**: 인증 사용자 전체 CRUD, 삭제는 admin만
- **task_updates**: 인증 사용자 전체 조회/추가/수정, 삭제는 admin만
- **activity_logs**: 인증 사용자 전체 조회, 삽입은 트리거(SECURITY DEFINER)
- **memos**: user_id = auth.uid()만 CRUD (완전 개인, Admin도 타인 접근 불가)

## Migration History

| # | File | Description |
|---|------|-------------|
| 001 | 20260222_001_create_profiles.sql | profiles 테이블, 트리거 |
| 002 | 20260222_002_create_projects.sql | projects, project_members |
| 003 | 20260222_003_create_tasks.sql | tasks |
| 004 | 20260222_004_create_daily_logs_and_comments.sql | daily_logs, task_comments |
| 005 | 20260222_005_create_meetings.sql | meetings (5개 테이블) |
| 006 | 20260222_006_add_admin_role.sql | Admin 역할 + RLS 전면 수정 |
| 007 | 20260222_007_fix_project_members_rls.sql | project_members RLS 재귀 수정 |
| 008 | 20260222_008_tasks_optional_project.sql | 독립 태스크 (project_id nullable) |
| 009 | 20260222_009_file_attachments.sql | 파일 첨부 시스템 |
| 010 | 20260222_010_meeting_online_mode.sql | 회의 비대면/하이브리드 + Zoom 기본값 |
| 011 | 20260222_011_storage_buckets_and_policies.sql | Storage 버킷 3개 + RLS 정책 |
| 012 | 20260222_012_memos.sql | 개인 메모 시스템 |
| 013 | 20260222_013_fix_profiles_insert_rls.sql | profiles INSERT RLS 정책 추가 |
| 014 | 20260222_014_comprehensive_rls_fix.sql | 전체 RLS 재정비 (비관리자 정상화) |
| 015 | 20260224_015_shared_data_rls.sql | 공용 데이터 RLS (메모만 개인, 나머지 공용) |
| 016 | 20260224_016_task_updates_and_color_tag.sql | 연계 업무 + 색상 태그 |
| 017 | 20260226_017_tasks_created_by.sql | tasks.created_by 컬럼 (등록자 추적) |
| 018 | 20260226_018_tasks_show_in_calendar.sql | tasks.show_in_calendar 컬럼 |
| 019 | 20260226_019_calendar_default_false.sql | show_in_calendar 기본값 false로 변경 |
| 020 | 20260227_020_delete_policy_all_users.sql | DELETE 정책: 인증 사용자 전체 허용 |
| 021 | 20260228_021_meeting_notes_columns.sql | meetings.meeting_notes, raw_transcript |
| 022 | 20260306_022_timeline_sort_order.sql | meeting_timeline.sort_order 컬럼 |
| 023 | 20260307_023_activity_logs.sql | activity_logs 테이블 + DB 트리거 (5테이블) |
| 024 | 20260307_024_activity_digest_cron.sql | send_activity_digest() 함수 + pg_cron 스케줄 |
