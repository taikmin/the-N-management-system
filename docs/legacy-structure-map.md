# Legacy Structure Map — R&D Task Manager → Hotel Management 전환용

> **작성 목적**: 이 리포지토리는 기존 R&D 과제 관리 앱(`rd-task-manager`)을 복사한 것이다. 호텔 관리 앱으로 재구성하기 전에, 무엇을 **재사용/개조/폐기**할지 판단할 근거를 정리한 문서.
>
> **주의**: `reference/project-management-app/` 폴더는 원본 사본으로 이 문서에서 다루지 않음.

---

## 1. 아키텍처 개요

### 부트스트랩
- [lib/main.dart](../lib/main.dart) — `SupabaseConfig.initialize()` → 한국어 로케일 초기화 → `ProviderScope` → `RdTaskManagerApp`
- [lib/app/app.dart](../lib/app/app.dart) — 루트 `MaterialApp.router`, Material 3 라이트/다크, GoRouter 사용
- [lib/app/supabase_config.dart](../lib/app/supabase_config.dart) — `.env`에서 `SUPABASE_URL`, `SUPABASE_ANON_KEY` 로드

### 폴더 구조
```
lib/
├── app/          # router, theme, supabase_config, app
├── core/         # constants, services (AI 등)
├── features/     # activity, auth, calendar, dashboard, meetings, memos, projects, tasks
└── shared/       # widgets (navigation shell, responsive), models, providers, data
```

### 상태 관리 패턴
- **Riverpod** (`flutter_riverpod ^2.6.1`, code-gen 미사용)
- AsyncNotifier: 비동기 CRUD
- StreamProvider: Supabase Realtime 구독 (projects, tasks, meetings)
- StateProvider: UI 필터/정렬/검색 상태
- FutureProvider.family: 상세 조회

---

## 2. 라우팅 (GoRouter)

**Shell 라우트 (하단 네비게이션)**: `/dashboard`, `/projects`, `/tasks`, `/meetings`, `/calendar`, `/memos`, `/settings`

**Standalone**: `/login`, `/register`

**Nested (CRUD)**:
- Projects: `/projects/create`, `/projects/:id`, `/projects/:id/edit`, `/projects/:id/tasks/create`, `/projects/:id/tasks/:taskId`
- Tasks: `/tasks/create`, `/tasks/:id`, `/tasks/:id/edit`
- Meetings: `/meetings/create`, `/meetings/edit/:id`, `/meetings/:id`, `/meetings/:id/record`, `/meetings/:id/minutes-result`
- Memos: `/memos/create`, `/memos/:id`
- Activity: `/activity`

**가드**: `isLoggedInProvider` 기반 로그인 리다이렉트

---

## 3. 테마 / 디자인 시스템

- [lib/app/theme.dart](../lib/app/theme.dart) — Material 3, `ColorScheme.fromSeed(AppColors.primary)`, Google Fonts Noto Sans KR
- [lib/core/constants/app_colors.dart](../lib/core/constants/app_colors.dart)
  - **Primary: KIMM Blue `#1565C0`** ← 브랜딩 변경 대상
  - Secondary: Research Green `#2E7D32`
  - Tertiary: Innovation Orange `#E65100`
- [lib/core/constants/app_sizes.dart](../lib/core/constants/app_sizes.dart) — 브레이크포인트 mobile(600)/tablet(900)/desktop(1200)
- [lib/core/constants/app_strings.dart](../lib/core/constants/app_strings.dart) — 한국어 UI 문자열 (R&D 특화 용어 다수)

---

## 4. Core Services

| 파일 | 역할 | 재사용 가치 |
|------|------|-------------|
| [gemini_service.dart](../lib/core/services/gemini_service.dart) | `gemini-flash-latest` 기반 회의록 생성, 업무 추출, 청킹(80KB→15KB), 재시도, JSON 파싱 폴백 | 높음 (호텔에서도 게스트 요청/유지보수 지시 추출 등에 활용 가능) |
| [ai_service.dart](../lib/core/services/ai_service.dart) | 추상 인터페이스: `MeetingMinutesResult`, `ExtractedTask` | 높음 |

---

## 5. 공용 위젯 / 모델

- [lib/shared/widgets/app_navigation_shell.dart](../lib/shared/widgets/app_navigation_shell.dart) — 반응형 (BottomNav/Rail/Extended), "더보기" 시트, 플로팅 녹음 컨트롤러
- [lib/shared/widgets/responsive_layout.dart](../lib/shared/widgets/responsive_layout.dart)
- [lib/shared/widgets/file_attachment_section.dart](../lib/shared/widgets/file_attachment_section.dart)
- [lib/shared/data/file_repository.dart](../lib/shared/data/file_repository.dart) — Supabase Storage CRUD
- [lib/shared/providers/file_provider.dart](../lib/shared/providers/file_provider.dart)

---

## 6. Feature별 파악 및 재사용 판정

### 6-1. Dashboard — **KEEP AS-IS**
- [dashboard_screen.dart](../lib/features/dashboard/presentation/screens/dashboard_screen.dart), [settings_screen.dart](../lib/features/dashboard/presentation/screens/settings_screen.dart)
- 통계 카드 + 이번 주 일정 + 최근 회의/메모/활동 요약 (도메인 무관 집계 UI)
- 호텔에서는: 오늘 체크인/아웃, 객실 현황, 진행 중인 작업, 최근 활동 등으로 대체

### 6-2. Activity — **KEEP AS-IS**
- [activity_log_screen.dart](../lib/features/activity/presentation/screens/activity_log_screen.dart)
- 엔티티 타입별 필터, 날짜 그루핑, 액션 아이콘 — 완전 도메인 무관
- 다만 `entityType` enum(`tasks/projects/meetings/memos/meeting_timeline`) 및 트리거는 호텔 엔티티에 맞게 재설정 필요

### 6-3. Auth — **ADAPT**
- [login_screen.dart](../lib/features/auth/presentation/screens/login_screen.dart), [register_screen.dart](../lib/features/auth/presentation/screens/register_screen.dart)
- [user_role.dart](../lib/features/auth/domain/models/user_role.dart) — enum `pi/researcher/external_` → 호텔용 (예: `manager`, `frontDesk`, `housekeeping`, `guestService`)로 교체
- Zoom 관련 필드(`default_zoom_link/id/password`)는 필요 없으면 제거
- Supabase Auth 플로우 자체는 완전 재사용

### 6-4. Calendar — **KEEP AS-IS**
- [calendar_screen.dart](../lib/features/calendar/presentation/screens/calendar_screen.dart)
- [calendar_event.dart](../lib/features/calendar/domain/models/calendar_event.dart) — `CalendarEventType` enum만 호텔용으로 교체 (예약/이벤트/청소일정 등)
- 다중 소스 집계 + 지연 표시 + 상세 라우팅 패턴은 그대로

### 6-5. Tasks — **REPLACE (구조 유지, 필드 재정의)**
- [task_list_screen.dart](../lib/features/tasks/presentation/screens/task_list_screen.dart), [task_detail_screen.dart](../lib/features/tasks/presentation/screens/task_detail_screen.dart), [task_create_screen.dart](../lib/features/tasks/presentation/screens/task_create_screen.dart), [daily_check_screen.dart](../lib/features/tasks/presentation/screens/daily_check_screen.dart)
- **폐기 대상 필드**: `planType` (A/B/C), `parentTaskId` (연계업무 계층), `dailyLog` (일일 수행 기록)
- **유지 가능**: 상태(planned/in_progress/delayed/completed), 우선순위, 담당자, 기한, 필터/정렬 인프라
- 호텔에서는: 하우스키핑 작업, 유지보수 티켓, 프론트 요청 등으로 재정의

### 6-6. Projects — **REPLACE (완전 재설계)**
- [project_list_screen.dart](../lib/features/projects/presentation/screens/project_list_screen.dart), [project_detail_screen.dart](../lib/features/projects/presentation/screens/project_detail_screen.dart), [project_create_screen.dart](../lib/features/projects/presentation/screens/project_create_screen.dart)
- **폐기 대상 필드**: `projectNumber`, `leadInstitution` (default: 한국기계연구원), `coInstitutions`, `totalBudget` (억원 단위)
- 호텔의 "프로젝트" 개념 자체가 다름 → **객실(Room)**, **예약(Reservation)**, **게스트(Guest)** 등의 신규 엔티티로 대체 필요
- 리스트/카드/상세/필터 UI 뼈대는 참고

### 6-7. Meetings — **ADAPT (핵심 개조)**
- 8개 이상의 화면과 5개 도메인 모델로 매우 크게 구현됨
- **폐기 대상**:
  - `meetingType` enum (진도점검/킥오프/중간발표/최종발표) — R&D 리뷰 구조
  - `institution` 필드 (participant) — 다기관 협력용
  - `meeting_document` 워크플로우 (양식배포→제출→취합→검토)
  - `meeting_timeline` 사전 마일스톤 (14/7/3/1일 전) — R&D 그랜트 리뷰용
- **재사용 가능**:
  - 회의 CRUD, 참석자, 안건, 오프라인/온라인/하이브리드 모드
  - AI 회의록 추출 파이프라인 (STT → Gemini → 태스크 자동 등록)
  - 플로팅 녹음 컨트롤러
- 호텔에서는: 스탭 미팅, VIP 게스트 브리핑, 이벤트 조율 미팅 등으로 활용 가능
- 미커밋 변경사항 있음: [meeting_detail_screen.dart](../lib/features/meetings/presentation/screens/meeting_detail_screen.dart), [gemini_service.dart](../lib/core/services/gemini_service.dart)

### 6-8. Memos — **KEEP AS-IS**
- [memo_list_screen.dart](../lib/features/memos/presentation/screens/memo_list_screen.dart), [memo_detail_screen.dart](../lib/features/memos/presentation/screens/memo_detail_screen.dart)
- 개인 메모, 카테고리/우선순위/핀/아카이브 — 완전 도메인 무관

### 재사용 요약표

| Feature | 판정 | 사유 |
|---------|------|------|
| Dashboard | KEEP | 집계 UI 도메인 무관 |
| Activity | KEEP | 감사 로그 패턴 범용 |
| Auth | ADAPT | 역할 enum만 교체, 나머지 재사용 |
| Calendar | KEEP | 다중 소스 집계 범용 |
| Tasks | REPLACE | R&D 특화 필드 폐기, 뼈대 유지 |
| Projects | REPLACE | 완전 재설계 (Room/Reservation/Guest 등으로) |
| Meetings | ADAPT | AI 파이프라인 유지, R&D 워크플로 폐기 |
| Memos | KEEP | 개인 메모는 범용 |

---

## 7. DB 스키마 요약

### 주요 테이블
- **profiles** — `role` (pi/researcher/external_), Zoom 필드, `is_admin`
- **projects** — `project_number`, `lead_institution`, `co_institutions[]`, `total_budget`, `owner_id`, `assignee_id`
- **project_members** — 프로젝트 멤버 role(owner/admin/member/viewer)
- **tasks** — `plan_type` (A/B/C), `parent_task_id`, `color_tag`, `show_in_calendar`
- **daily_logs** — 태스크당 일일 수행 기록 (content/issues/next_plan)
- **meetings** — `meeting_type`, `meeting_mode`, `meeting_notes` (AI), `raw_transcript`, meal reservation, online 자격증명
- **meeting_participants / meeting_documents / meeting_agenda / meeting_timeline** — 회의 상세 워크플로
- **memos** — 개인 소유 (private RLS)
- **activity_logs** — `entity_type` (tasks/projects/meetings/memos/meeting_timeline), `notified` 플래그
- **file_attachments** — polymorphic (`entity_type` + `entity_id`), 3개 버킷
- **task_updates / task_comments** — 태스크 부가 기록

### 트리거 / 함수
- `handle_new_user()` — 가입 시 `profiles` 자동 생성 (SECURITY DEFINER)
- `update_updated_at()` — 여러 테이블 공용
- `is_admin()` — RLS용 STABLE 함수
- `log_activity()` — 5개 테이블 변경 시 `activity_logs`에 자동 기록
- `send_activity_digest()` — pg_cron에서 3시간마다 호출, `pg_net`으로 Resend API 호출

### RLS 원칙
- **memos**: `user_id = auth.uid()` 만 접근 (관리자도 불가)
- **그 외 대부분**: 로그인 사용자면 CRUD 가능, DELETE는 관리자만
- `activity_logs`: 조회 가능, 삽입은 SECURITY DEFINER 트리거만

---

## 8. 외부 서비스 연결

| 서비스 | 용도 | 설정 위치 | 호텔 전환 시 |
|--------|------|-----------|--------------|
| Supabase | DB, Auth, Storage, Realtime | `.env`의 `SUPABASE_URL`, `SUPABASE_ANON_KEY` | **새 프로젝트 필요** |
| Gemini API (`gemini-flash-latest`) | 회의록/태스크 추출 | `.env`의 `GEMINI_API_KEY`, [gemini_service.dart:19](../lib/core/services/gemini_service.dart#L19) | 키만 신규 발급, 로직 재사용 |
| Resend | 활동 다이제스트 이메일 | SQL 함수 내부 (pg_net) | 발신자 `noreply@sartexo.com`, 수신자 재설정 |
| pg_cron + pg_net | 3시간 간격 자동 이메일 | `'0 */3 * * *'` | 새 Supabase에 재구성 |
| Web Speech API | 한국어 STT (`ko-KR`) | [speech_recognition_web.dart](../lib/features/meetings/data/services/speech_recognition_web.dart) — 웹 전용 | 그대로 재사용 |

### Storage 버킷
- `project-files`, `task-files`, `meeting-files` → 호텔 도메인 이름으로 변경 예정 ([file_repository.dart:14-26](../lib/shared/data/file_repository.dart#L14))

---

## 9. 하드코딩된 값 (단절 시 제거 대상)

| 값 | 위치 | 조치 |
|----|------|------|
| `noreply@sartexo.com` | `supabase/migrations/20260617_025_activity_digest_all_users.sql:158` | 호텔 발신자 도메인으로 교체 검토 |
| `parkch@kimm.re.kr` | `supabase/migrations/20260617_025_activity_digest_all_users.sql:63` | 호텔 관리자 이메일로 교체 |
| `https://rd-task-manager-coral.vercel.app` | 위 SQL 파일:142 | 새 배포 URL로 교체 |
| `gemini-flash-latest` | [gemini_service.dart:19](../lib/core/services/gemini_service.dart#L19) | 모델 정책 재검토 (CLAUDE.md는 gemini-2.5-pro라 되어 있으나 실제는 flash) |
| `@kimm.re.kr` 테스트 계정 | `test/widget_test.dart:25,88` | 호텔 도메인 테스트 계정으로 교체 |
| "KIMM", "한국기계연구원", "R&D" 문자열 | 앱 전반 (특히 [app.dart](../lib/app/app.dart)의 `RdTaskManagerApp`, `app_strings.dart`) | 전수 grep 후 교체 |

---

## 10. 환경변수

| 변수 | 용도 |
|------|------|
| `SUPABASE_URL` | Supabase 엔드포인트 |
| `SUPABASE_ANON_KEY` | Supabase 익명 키 |
| `GEMINI_API_KEY` | Google Generative AI 키 |

- `.env` — 실제 값 (git ignored)
- [.env.example](../.env.example) — 템플릿

---

## 11. 주요 dependencies (pubspec.yaml)

- **State**: `flutter_riverpod`, `riverpod_annotation`
- **Routing**: `go_router ^14.8.1`
- **Backend**: `supabase_flutter ^2.8.4`
- **Codegen**: `freezed`, `json_serializable`, `build_runner`
- **UI**: `google_fonts`, `flutter_svg`, `gap`, `table_calendar`
- **Files**: `file_picker`, `url_launcher`
- **Utility**: `http`, `flutter_dotenv`, `intl`, `shared_preferences`, `web`

---

## 12. Step 2 (단절)로의 전환 힌트

이 파악 결과를 바탕으로, Step 2에서 다음을 우선 처리:
1. **Supabase 프로젝트 신규 생성** — 기존 DB에 절대 쓰기 방지
2. **Git remote 교체** — `taikmin/rd-task-manager` → 신규 저장소
3. **하드코딩 문자열 grep & 치환** — 위 §9 표 기준
4. **앱 식별자 변경** — `kr.re.kimm.*` → 호텔용 도메인
5. **재사용 판정 KEEP/ADAPT 항목은 손대지 않고**, REPLACE 항목만 2차 플랜에서 재설계

## 13. 미해결 사항

- CLAUDE.md의 Gemini 모델 문서(`gemini-2.5-pro`)와 실제 코드(`gemini-flash-latest`)가 불일치 — 어느 쪽이 정본인지 사용자 확인 필요
- `reference/project-management-app/` 폴더의 처리 방침 (참고 유지 vs 삭제)
- 미커밋 변경사항 2건의 처리 방침
