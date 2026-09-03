# The N Resort Management — 진행 현황

> 마지막 업데이트: 2026-09-03 (Step 4 C-2 완료)

---

## 완료 (✅)

### 1차 플랜 (파악 + 원작자 리소스 단절)
- ✅ 2026-09-03 — **구조 파악** 완료 → `docs/legacy-structure-map.md`
- ✅ 2026-09-03 — **Git remote 분리** (원작자 `parkch-meca/project-management-app` → `taikmin/the-N-management-system`)
- ✅ 2026-09-03 — **Git 히스토리 완전 초기화** (orphan branch, 커밋 `08eb007` → 이후 amend)
- ✅ 2026-09-03 — **Supabase 새 프로젝트 연결** (`bnnxymiotbinzhjqwjgf` → `pxkgtciulauiruxsopcg`)
- ✅ 2026-09-03 — **하드코딩된 원작자 시크릿 제거** (Resend 키, `parkch@kimm.re.kr`)
- ✅ 2026-09-03 — **브랜딩/식별자 완전 교체** (커밋 `059cf11`)
  - 패키지명: `rd_task_manager` → `hotel_management`
  - 클래스: `RdTaskManagerApp` → `HotelManagementApp`
  - 앱 식별자: `kr.re.kimm.rd_task_manager` → `com.taikmin.hotel_management`
  - 브랜드 컬러: `#1565C0` → `#0ABAB5` (Tiffany Blue)
  - 표시명: "The N Resort Management"
- ✅ 2026-09-03 — **CLAUDE.md 1차 재작성** (호텔 프로젝트 상태)

### 2차 플랜 준비
- ✅ 2026-09-03 — **2차 플랜 설계 완료** (호텔 도메인 재설계)
  - 사용자 요구 확정 (역할 3단계, 업무 유형, 보고 방식, 이메일 정책 등)

---

## 진행 중 (🟡)

- ✅ **Step 4 C-2: Departments 신설** (2026-09-03)
  - `lib/features/projects/` → `lib/features/departments/` 폴더 및 파일 rename (git mv)
  - Department 모델 신규 작성 (id/name/description/color/leadId/sortOrder)
  - DepartmentRepository CRUD + getMembers/getTaskStats
  - DepartmentListNotifier (Realtime 구독), detail/members/taskStats providers
  - DepartmentListScreen (관리자만 FAB 노출), DepartmentDetailScreen (팀장·통계·소속직원 카드 + 관리자만 편집/삭제), DepartmentCreateScreen (색상 팔레트 8종)
  - DepartmentCard 위젯 재작성
  - router.dart: /projects → /departments 라우트, 중첩 projects/tasks 라우트 제거
  - calendar_provider: project 소스 제거, 임시 stub 유지 (Task 재구성 후 C-5에서 정리)
  - dashboard_screen: _ProjectsPreview 삭제, _DashboardStats에서 "진행중 과제" 카드 제거
  - test/widget_test.dart: Project 그룹 삭제
  - dart analyze: 에러 0

- ✅ **Step 4 C-1: Auth 역할 교체 완료** (2026-09-03, 커밋 `d88b155`)
  - UserRole enum: `pi/researcher/external_` → `ceo/manager/staff`
  - AppUser에 `isSuperadmin/isCeoOrAbove/isManagement` 헬퍼 게터 추가
  - Register 화면: role 선택 UI 제거, phone 필드 추가
  - Settings 화면: Zoom 섹션 완전 삭제
  - Auth Repository/Provider: signUp에 phone 파라미터, isCeoOrAboveProvider/isManagementProvider 추가
  - app_strings: 호텔 역할 라벨 (대표/관리자/직원/시스템 관리자)
  - test/widget_test.dart의 AppUser/UserRole 그룹 삭제 (Step 4 완료 후 재작성 예정)
  - dart analyze: 에러 0

- ✅ **Step 3 — 호텔 스키마 구축 완료** (2026-09-03)
  - hotel_001~010 (총 10개 마이그레이션) Supabase Dashboard에서 실행 완료
  - 실행 중 발견/해결:
    - 신 프로젝트라 R&D 스키마가 없어 hotel_003을 ALTER→CREATE로 재작성 (`hotel_003_tables_create.sql`)
    - hotel_005/006은 삭제할 R&D 테이블 없어 스킵
    - profiles.is_admin 컬럼 누락 → hotel_001에 추가
    - Admin/CEO/Manager/Staff 4단계 권한 분리 (`hotel_010_admin_separation.sql` 신규 작성)
    - `prevent_privilege_escalation` 트리거에 SQL Editor bypass 로직 추가
  - lee.taikmin@gmail.com 계정을 `is_admin=true, role='manager'`로 승격
  - 헬퍼 함수 검증 완료 (is_superadmin/is_ceo_or_above/is_management 모두 true)
  - ⏳ 남은 후속 (Step 4 진행 중 또는 완료 후):
    - Resend API 키 실제 값으로 교체 (Dashboard에서)
    - 다이제스트 수신자 등록
    - 이메일 발송 테스트

- 🟡 **Step 1 + Step 2A** — 문서 스캐폴딩 + R&D 잔재 부분 삭제 완료, 커밋 대기 중
  - Step 1: `plan/progress/task/lessons/README/CLAUDE.md` 6개 완료
  - Step 2A: meetings/ 삭제, gemini/ai_service.dart 삭제, conductor/ 삭제, CHANGELOG.md 삭제
    - 라우터/네비/대시보드에서 meeting 참조 정리
    - `calendar_provider.dart` meeting 이벤트 소스 제거
    - `CalendarEventType` enum 축소 (project, task만)
    - `test/widget_test.dart` Meeting 5개 그룹 삭제
    - `.env`에서 `GEMINI_API_KEY` 제거
    - `dart analyze` 통과 (에러 0, info 2개 잔존은 기존 이슈)
  - Step 2A 유예: `daily_log/task_updates/task_comments` (Step 4에서 tasks 재설계 시 함께)
  - Step 2B: `docs/`, `supabase/migrations/`, `supabase/functions/`는 Step 3 참고용으로 유지 → Step 3 완료 후 삭제
  - ⏳ 커밋 & push

---

## 미착수 (⏳)

### Step 2: R&D 잔재 삭제 (우선순위 상)
- ⏳ `lib/features/meetings/` 전체 폴더 삭제
- ⏳ Gemini/AI/STT 관련 코드 삭제 (`gemini_service.dart`, `ai_service.dart`, `speech_recognition_*.dart`, `recording_provider.dart`, `floating_recording_controller.dart`)
- ⏳ `daily_log*.dart`, `daily_check_screen.dart` 삭제
- ⏳ `task_updates*.dart`, `task_comments*.dart` 삭제
- ⏳ 라우터에서 meeting/record 라우트 제거
- ⏳ 하단 네비게이션 "회의" 탭 제거
- ⏳ Dashboard `_UpcomingMeetingsPreview` 제거
- ⏳ `activity_provider`의 `meetings/meeting_timeline` 처리 제거
- ⏳ 원작자 문서 정리: `conductor/`, `docs/database-schema.md`, `docs/architecture.md`, `docs/activity-digest-setup.md`, `docs/daily-log/` 삭제
- ⏳ `supabase/migrations/` 대부분 삭제

### Step 3: 호텔 스키마 SQL (우선순위 상)
- ⏳ 신규 마이그레이션 파일 작성 (`supabase/migrations/hotel_001_*.sql` ~)
  - profiles 수정 (role enum 교체, department_id 추가, Zoom 필드 제거)
  - departments 신규 (+ 5개 기본 seed)
  - tasks 재정의
  - app_settings, digest_recipients 신규
  - activity_logs entity_type 조정
  - 삭제: projects/meetings/*/daily_logs/task_updates/task_comments
- ⏳ 함수/트리거: `handle_new_user`, `log_activity`, `send_daily_digest`, `generate_recurring_tasks`
- ⏳ RLS 정책 (역할별)
- ⏳ pg_cron 잡 등록 (`0 * * * *` for digest, `0 15 * * *` for recurring)
- ⏳ Supabase Dashboard에서 수동 실행 및 검증

### Step 4: Flutter 코드 재구성 (우선순위 중)
- ✅ C-1: Auth (역할 enum 교체, 그리팅 수정)
- ✅ C-2: Departments (projects 폴더 rename + 재정의)
- ⏳ C-3: Tasks 핵심 개조 (모델, 화면, 보고 시트)
- ⏳ C-4: Dashboard 역할별 뷰
- ⏳ C-5: Calendar (이벤트 소스 정리)
- ⏳ C-6: Memos (문자열만 확인)
- ⏳ C-7: Activity Logs (entity_type 매핑)
- ⏳ C-8: Navigation Shell (탭 재구성)
- ⏳ C-9: 문자열 최종 정리

### Polish + 발표 준비
- ⏳ Vercel 새 프로젝트 배포
- ⏳ 스크린샷 촬영 (`docs/screenshots/`)
- ⏳ README.md 최종 갱신 (실제 구현 반영)
- ⏳ 로컬 폴더명 오타 수정 (`magnagement` → `management`, 세션 종료 후 수동)

---

## 블록/이슈

*현재 없음*

---

## 알려진 향후 처리 사항
- **이메일 발신 도메인**: 현재 `onboarding@resend.dev` (Resend 기본). 나중에 호텔 도메인 확보 시 교체
- **Resend 키 관리**: 현재 SQL 함수에 하드코딩. 나중에 Supabase Vault로 이관 권장
- **테스트 코드**: `test/widget_test.dart`가 R&D 도메인 기반. Step 4 완료 후 호텔용으로 재작성 필요
