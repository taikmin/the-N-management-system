# CLAUDE.md - The N Resort Management

## Project Overview
**The N Resort** 호텔·리조트 통합 관리 웹앱.

이 리포지토리는 R&D 과제 관리 앱(`rd-task-manager`, 원작자: parkch-meca)의 코드 구조를 기반으로, 호텔·리조트 운영 관리용 앱으로 재구성 중이다. 원작자의 GitHub/Supabase/Resend/브랜딩 리소스와는 완전히 단절된 상태이며, 도메인 로직(과제·업무·회의 등)은 호텔 도메인(객실·예약·게스트·하우스키핑 등)으로 재설계 예정.

- **GitHub**: github.com/taikmin/the-N-management-system
- **Package name (pubspec)**: `hotel_management`
- **App identifier**: `com.taikmin.hotel_management`

## Status
- ✅ Step 1: 기존 코드 구조 파악 완료 → `docs/legacy-structure-map.md`
- ✅ Step 2: 원작자 리소스 단절 완료 (Git, Supabase, Resend, 브랜딩, 식별자)
- ⏳ Step 3 (예정): 2차 플랜 — 호텔 도메인 재설계 (엔티티/스키마/화면 매핑)

## Tech Stack
- **Framework**: Flutter 3.38 (Dart 3.10)
- **UI**: Material 3, **Tiffany Blue `#0ABAB5`** (브랜드 primary)
- **State Management**: Riverpod (flutter_riverpod, code-gen 미사용)
- **Routing**: GoRouter (go_router)
- **Backend**: Supabase (PostgreSQL, Auth, Realtime, Storage) — 새 프로젝트 `pxkgtciulauiruxsopcg`
- **Email**: Resend API (활동 요약 이메일)
- **Scheduler**: pg_cron + pg_net (DB 내 스케줄링)
- **Deploy**: Vercel (미배포, 예정)

## AI/STT 관련 (폐기 예정)
`gemini_service.dart`, `ai_service.dart`, `recording_provider.dart`, Web Speech API 기반 STT, 회의 녹음/AI 회의록 관련 코드는 호텔 앱에서 사용하지 않기로 결정됨. 2차 플랜 실행 시 제거 예정. 현재는 코드에 남아있으나 새 Supabase에는 관련 스키마가 없어 동작하지 않는다.

## Architecture (현재 = R&D 원본 구조, 호텔용으로 재설계 예정)
```
lib/
├── app/                    # router.dart, theme.dart, app.dart (HotelManagementApp)
├── core/                   # constants/, services/
├── features/
│   ├── activity/           # 활동 로그 (재사용)
│   ├── auth/               # 인증 (역할 enum만 호텔용 교체 예정)
│   ├── calendar/           # 캘린더 (재사용)
│   ├── dashboard/          # 대시보드 (재사용, 위젯 매핑만 교체)
│   ├── meetings/           # 회의 (일부 재사용, R&D 워크플로 폐기)
│   ├── memos/              # 개인 메모 (재사용)
│   ├── projects/           # → 호텔 도메인 엔티티로 재설계 예정
│   └── tasks/              # → 하우스키핑/유지보수 티켓 등으로 재정의
└── shared/                 # 공유 위젯, 모델
```

자세한 재사용 판정: `docs/legacy-structure-map.md` 참조.

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
- **원격**: `origin` = `github.com/taikmin/the-N-management-system`
- **주의**: 원작자 저장소(`parkch-meca/project-management-app`)와 연결되지 않도록 remote 확인 필수

## Commands
- `flutter run -d chrome`: 웹 실행
- `flutter test`: 유닛 테스트 (참고: 다수 테스트가 R&D 도메인 기반으로 실패할 수 있음. 호텔 도메인 재설계 시 재작성 필요)
- `flutter analyze`: 정적 분석
- `flutter build web --release`: 웹 빌드
- `flutter pub get`: 의존성 설치

## Environment
- `.env` 파일에 키 저장 (git에 포함하지 않음, `.env.example` 참고)
- 필요 키: `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- `GEMINI_API_KEY`: 현재는 `.env`에 남아있으나 폐기 예정

## External Services

### Supabase
- 프로젝트: `pxkgtciulauiruxsopcg` (taikmin's Org, Seoul region)
- Storage 버킷: 호텔 도메인 재설계 시 신규 생성 예정
- 현재 스키마: **없음** (2차 플랜에서 호텔 스키마 신규 구축)

### Resend (이메일)
- **활성 상태**: 사용자 Resend 키 발급, `send_activity_digest()` SQL 함수에서 호출
- **수신자**: `lee.taikmin@gmail.com`
- **발신자**: `onboarding@resend.dev` (Resend 기본; 호텔 브랜드 도메인 준비되면 교체)
- **참고**: Resend 키가 SQL 함수 body에 하드코딩되어 있음 (개선 필요 → Supabase Vault로 이관 권장)

### pg_cron + pg_net
- Supabase Extensions에서 활성화
- 3시간마다 `send_activity_digest()` 자동 실행 (cron: `'0 */3 * * *'`)

## Database Migration Rules (Data Preservation)
- **절대 금지**: `DROP TABLE`, `DROP COLUMN` (운영 데이터 손실 위험) — 단, 초기 호텔 스키마 구축 전 정리 단계에서만 예외
- **추가만 허용**: 새 테이블, 새 컬럼, 새 인덱스는 자유롭게 추가
- **IF NOT EXISTS**: 모든 `CREATE TABLE`, `ADD COLUMN`에 반드시 사용
- **DEFAULT 값**: 기존 테이블에 NOT NULL 컬럼 추가 시 반드시 DEFAULT 지정
- **롤백 SQL**: 각 마이그레이션에 대응하는 rollback SQL 파일 작성
- **SQL 제공**: 마이그레이션 SQL은 Supabase Dashboard에서 수동 실행

## Storage Configuration
호텔 도메인 재설계 시 신규 버킷 생성 예정 (예: `guest-files`, `room-photos`, `document-uploads` 등).

## RLS Policy Summary
2차 플랜에서 호텔 스키마 확정 후 재작성. 원칙은 유지:
- 대부분 테이블: `auth.uid() IS NOT NULL`이면 CRUD 허용
- memos 등 개인 데이터: `user_id = auth.uid()`만 접근

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
- 브라우저 새로고침/닫기 시 beforeunload 경고 (사용자 입력 데이터 있을 때)
- 빈 리스트 상태 처리 (empty state UI)
- 저장 실패 시 데이터 보존 (절대 사용자 입력 삭제 금지)

### 배포 전 체크리스트
1. `flutter analyze` — 정적 분석 통과
2. `flutter test` — 기존 테스트 통과 (2차 플랜 이후 호텔용으로 재작성)
3. `flutter build web --release` — 웹 빌드 성공
4. Vercel 배포 및 GitHub push

## Known Issues & Warnings
- 로컬 폴더명에 오타 있음 (`the-N-magnagement-system` → `management`로 수정 예정, 세션 종료 후)
- 현재 앱 실행 시 새 빈 Supabase에 연결되므로 대부분 화면이 데이터 없음/에러로 나타남 (정상 — 스키마 미구축 상태)
- Gemini API 키가 `.env`에 남아있으나 코드에서 실제 호출 시 유효한 응답 없을 것 (Gemini 폐기 예정)
- Web Speech API: `dart:js_interop_unsafe`로 런타임 프로퍼티 접근 (Gemini와 함께 폐기 예정)
- Conditional imports: `export 'stub.dart' if (dart.library.js_interop) 'web.dart'`
- DropdownButtonFormField: `initialValue` 사용 (Flutter 3.38+)
- Wildcard pattern: `(_, _)` 사용 (not `(_, __)`)
- PlanType: `value` 프로퍼티 사용 (not `label`) — R&D 잔재, 폐기 대상
- FileOptions: `supabase_flutter`에서 import
- Realtime: tasks 채널에 사용자 필터 없음 (전체 변경 구독)

## 참고 문서
- `docs/legacy-structure-map.md` — 원본 R&D 구조와 재사용 판정 상세
- `docs/architecture.md` — 원작자 작성 아키텍처 (참고용, 호텔 재설계 시 업데이트)
- `docs/database-schema.md` — 원작자 작성 스키마 (참고용, 호텔용 재작성 예정)
- `README.md`, `README.html`, `CHANGELOG.md` — 원작자 작성, 아직 호텔용으로 갱신 안 됨
