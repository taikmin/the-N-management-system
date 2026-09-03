# CLAUDE.md - R&D Task Manager

## Project Overview
한국기계연구원(KIMM) R&D 과제 통합 관리 웹앱.
연구 과제의 일정, 업무, 회의, 캘린더, 메모, 팀 활동 추적을 하나의 앱에서 관리한다.

- **배포 URL**: https://rd-task-manager-coral.vercel.app
- **GitHub**: github.com/parkch-meca/project-management-app
- **Org**: kr.re.kimm (한국기계연구원)

## Tech Stack
- **Framework**: Flutter 3.38 (Dart 3.10)
- **UI**: Material 3 (Material You), KIMM Blue #1565C0
- **State Management**: Riverpod (flutter_riverpod, code-gen 미사용)
- **Routing**: GoRouter (go_router)
- **Backend**: Supabase (PostgreSQL, Auth, Realtime, Storage)
- **AI**: Google Gemini 2.5 Pro (회의록 생성, 업무 추출)
- **STT**: Web Speech API (한국어 음성인식, 웹 전용)
- **Email**: Resend API (활동 요약 이메일)
- **Scheduler**: pg_cron + pg_net (DB 내 스케줄링)
- **Deploy**: Vercel (정적 웹 호스팅)

## Architecture
Feature-first 구조:
```
lib/
├── app/                    # router.dart, theme.dart, app.dart
├── core/                   # constants/, services/, extensions/
├── features/
│   ├── activity/           # 팀 활동 추적 + 로그
│   ├── auth/               # 인증 (로그인, 회원가입)
│   ├── calendar/           # 캘린더 뷰
│   ├── dashboard/          # 대시보드 + 설정
│   ├── meetings/           # 회의 관리 + AI 회의록 + 녹음
│   ├── memos/              # 개인 메모
│   ├── projects/           # 과제 관리
│   └── tasks/              # 업무 관리
└── shared/                 # 공유 위젯, 모델
```

## Code Style Rules
- **Language**: Dart (null safety 필수)
- **Naming**: camelCase (변수/함수), PascalCase (클래스/enum), snake_case (파일)
- **Imports**: dart → package → relative 순서
- **Max line length**: 80 characters
- **Trailing commas**: 항상 사용 (widget tree 가독성)
- **const**: 가능한 모든 곳에 const 사용
- **모바일 기준**: 600px 이하 = 모바일 (`ResponsiveLayout.isMobile`)

## Git Convention
- **Commits**: Conventional Commits (feat/fix/docs/refactor/test/chore)
- **Co-Author**: `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

## Commands
- `flutter run -d chrome`: 웹 실행
- `flutter test`: 유닛 테스트
- `flutter analyze`: 정적 분석
- `flutter build web --release`: 웹 빌드
- `flutter pub get`: 의존성 설치

## Environment
- `.env` 파일에 키 저장 (git에 포함하지 않음, `.env.example` 참고)
- 필요 키: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GEMINI_API_KEY`

## Vercel Deployment Rules
배포 시 반드시 다음 절차를 따를 것:
1. `flutter clean`
2. `flutter build web --release`
3. `cd build/web && rm -rf .vercel`
4. `vercel --prod --name rd-task-manager --yes`
5. 배포 URL이 `rd-task-manager-coral.vercel.app` 인지 확인
6. **절대 `vercel --prod`만 실행하지 말 것** (`.vercel` 폴더가 잘못된 프로젝트를 가리킬 수 있음)

## External Services

### Gemini AI
- 모델: `gemini-2.5-pro` (gemini-2.5-flash에서 업그레이드)
- `.env`의 `GEMINI_API_KEY`에 API 키 설정
- 청킹: 80,000자 초과 시 15,000자 단위 분할 → 요약 → 병합
- JSON 파싱: 4단계 폴백 (direct → code block → brace → regex)
- `responseMimeType: 'application/json'`으로 구조화 출력

### Resend (이메일)
- `send_activity_digest()` SQL 함수에서 직접 Resend API 호출
- **발신자: `noreply@sartexo.com`** (커스텀 도메인, 변경 금지)
- 수신자: `parkch@kimm.re.kr`
- 함수 수정 시 발신자 주소 반드시 `noreply@sartexo.com` 유지

### pg_cron + pg_net
- Supabase Extensions에서 활성화
- 3시간마다 `send_activity_digest()` 자동 실행
- cron 표현식: `'0 */3 * * *'`

## Database Migration Rules (Data Preservation)
- **절대 금지**: `DROP TABLE`, `DROP COLUMN` (운영 데이터 손실 위험)
- **추가만 허용**: 새 테이블, 새 컬럼, 새 인덱스는 자유롭게 추가
- **IF NOT EXISTS**: 모든 `CREATE TABLE`, `ADD COLUMN`에 반드시 사용
- **DEFAULT 값**: 기존 테이블에 NOT NULL 컬럼 추가 시 반드시 DEFAULT 지정
- **롤백 SQL**: 각 마이그레이션에 대응하는 rollback SQL 파일 작성
- **문서화**: `docs/database-schema.md`에 스키마 변경 반영
- **SQL 제공**: 마이그레이션 SQL은 Supabase Dashboard에서 수동 실행

## Supabase Table Summary

### profiles
`id` (UUID PK), `email`, `full_name`, `department`, `position`, `avatar_url`, `role` (pi/researcher/external_), `is_admin`, `default_zoom_link`, `default_zoom_id`, `default_zoom_password`, `created_at`, `updated_at`

### projects
`id` (UUID PK), `title`, `project_number`, `description`, `status` (planning/active/completed/on_hold/cancelled), `start_date`, `end_date`, `lead_institution`, `co_institutions`, `total_budget`, `owner_id` (FK profiles, 책임자/PI), `assignee_id` (FK profiles, 담당자/실무), `created_at`, `updated_at`

### project_members
`id`, `project_id` (FK projects), `user_id` (FK profiles), `role` (owner/admin/member/viewer), `joined_at`

### tasks
`id` (UUID PK), `project_id` (FK projects, nullable=독립), `parent_task_id` (FK tasks, 자기참조), `title`, `description`, `status` (planned/in_progress/delayed/completed/blocked), `priority` (low/medium/high/urgent), `plan_type` (A/B/C), `assignee_id` (FK profiles), `created_by` (FK profiles), `planned_start`, `planned_end`, `actual_start`, `actual_end`, `order_index`, `category`, `color_tag` (red/yellow/blue/none), `show_in_calendar`, `created_at`, `updated_at`

### meetings
`id` (UUID PK), `project_id` (FK projects), `title`, `meeting_type`, `meeting_mode` (in_person/online/hybrid), `meeting_date`, `location`, `room_name`, `status`, `meal_reservation`, `meal_location`, `expected_attendees`, `description`, `online_platform`, `online_link`, `online_meeting_id`, `online_password`, `meeting_notes` (AI 회의록), `raw_transcript` (음성인식 원문), `creator_id` (FK profiles), `created_at`, `updated_at`

### meeting_timeline
`id`, `meeting_id` (FK meetings), `milestone`, `label`, `due_date`, `is_completed`, `completed_at`, `notification_sent`, `sort_order`, `created_at`

### meeting_participants / meeting_documents / meeting_agenda
회의 관련 테이블 (상세는 `docs/database-schema.md` 참조)

### memos
`id` (UUID PK), `user_id` (FK profiles), `title`, `content`, `category`, `is_pinned`, `priority`, `status`, `created_at`, `updated_at`

### activity_logs
`id` (UUID PK), `user_id` (FK auth.users), `user_name`, `action` (create/update/delete/complete), `entity_type` (tasks/projects/meetings/memos/meeting_timeline), `entity_id`, `entity_title`, `details` (JSONB, parent_task_title 포함 가능), `created_at`, `notified`

### file_attachments (polymorphic)
`id`, `file_name`, `file_size`, `mime_type`, `storage_path`, `bucket_name`, `entity_type`, `entity_id`, `uploader_id`, `description`

### daily_logs / task_comments / task_updates
태스크 관련 기록 테이블 (상세는 `docs/database-schema.md` 참조)

## Key Providers

| Provider | 파일 | 역할 |
|----------|------|------|
| `currentUserProvider` | auth_provider.dart | 로그인 사용자 |
| `projectListProvider` | project_provider.dart | 과제 목록 |
| `allMyTasksProvider` | task_provider.dart | 전체 업무 |
| `filteredTasksProvider` | task_provider.dart | 필터된 업무 |
| `subTasksMapProvider` | task_provider.dart | 하위업무 맵 |
| `meetingListProvider` | meeting_provider.dart | 회의 목록 |
| `activityStreamProvider` | activity_provider.dart | 실시간 활동 (24h) |
| `activityListProvider` | activity_provider.dart | 전체 활동 로그 |
| `recordingStateProvider` | recording_provider.dart | 녹음 상태 |

## Key DB Functions & Triggers

| 함수 | 역할 |
|------|------|
| `log_activity()` | 트리거: tasks/projects/meetings/memos/meeting_timeline 변경 시 activity_logs 자동 기록 |
| `send_activity_digest()` | pg_cron: 3시간마다 미발송 활동 요약 이메일 (Resend API, pg_net) |
| `update_updated_at()` | 트리거: updated_at 자동 갱신 |
| `handle_new_user()` | 트리거: 가입 시 profiles 자동 생성 |

## Storage Configuration
Supabase Storage 버킷 (Dashboard에서 수동 생성):
- `project-files`: 과제 관련 파일
- `task-files`: 태스크/일일기록 파일
- `meeting-files`: 회의 관련 파일

## RLS Policy Summary
**원칙: 메모만 개인, 나머지는 전부 공용 (인증 사용자 공유)**
- 대부분 테이블: `auth.uid() IS NOT NULL`이면 CRUD 허용
- memos: `user_id = auth.uid()`만 접근 (완전 개인)
- activity_logs: 인증 사용자 조회, 삽입은 트리거(SECURITY DEFINER)

## Agent Team Roles (단일 에이전트가 순서대로 수행)

### 1. Planner — 모든 작업 시작 전 반드시 수행
- 사용자 요구사항 분석 + 암묵적 기능 포함
- 기능 간 영향도 분석, 완료 기준 정의

### 2. Designer — Planner 이후 수행
- 화면 흐름도, UI 상태 정의 (빈/로딩/성공/에러)
- 모바일과 PC 사용성 고려

### 3. Developer — Designer 이후 수행
- 기획/설계 기반 구현, Provider 생명주기 확인

### 4. Reviewer — Developer 이후 반드시 수행
- happy path + 비정상 플로우 + 엣지 케이스 + 회귀 테스트

### 5. Documenter — 마지막에 수행
- 변경사항 보고 + SQL 안내 + 사용자 테스트 항목 최소화

### 핵심 원칙
- CRUD+검색 기본 세트, 저장↔불러오기 쌍, 기존 기능 비파괴 확인
- 당연히 필요한 것은 묻지 말고 포함

## Quality Verification Rules

### UI 변경 검증
- 모달/BottomSheet/Dialog가 부모 상태에 영향을 주지 않는지 확인
- Scaffold.bottomNavigationBar 사용하여 하단 버튼 가시성 보장
- 화면 전환 시 상태(Provider) 누수/초기화 여부 확인

### 상태 관리 검증
- reset() 호출 시점이 적절한지 (데이터 손실 방지)
- nullable 필드의 copyWith는 `T? Function()?` 패턴 사용

### 엣지 케이스 방어
- 브라우저 새로고침/닫기 시 beforeunload 경고 (녹음 데이터 있을 때)
- 빈 리스트 상태 처리 (empty state UI)
- 저장 실패 시 데이터 보존 (절대 사용자 입력 삭제 금지)

### 배포 전 체크리스트
1. `flutter analyze` — 정적 분석 통과
2. `flutter test` — 기존 테스트 통과
3. `flutter build web --release` — 웹 빌드 성공
4. Vercel 배포 및 GitHub push

## Known Issues & Warnings
- Vercel 배포 시 `.vercel` 폴더 삭제 필수
- `send_activity_digest()` 수정 시 발신자 `noreply@sartexo.com` 유지
- Web Speech API: `dart:js_interop_unsafe`로 런타임 프로퍼티 접근
- Conditional imports: `export 'stub.dart' if (dart.library.js_interop) 'web.dart'`
- DropdownButtonFormField: `initialValue` 사용 (Flutter 3.38+)
- Wildcard pattern: `(_, _)` 사용 (not `(_, __)`)
- PlanType: `value` 프로퍼티 사용 (not `label`)
- FileOptions: `supabase_flutter`에서 import
- Realtime: tasks 채널에 사용자 필터 없음 (전체 변경 구독)
