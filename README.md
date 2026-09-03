# R&D Task Manager

**KIMM(한국기계연구원) R&D 과제 및 업무 통합 관리 웹앱**

연구 과제의 일정, 업무, 회의, 캘린더, 메모를 하나의 앱에서 관리합니다.
팀원 활동을 실시간으로 추적하고, 3시간마다 요약 이메일을 받을 수 있습니다.

**배포 URL**: [https://rd-task-manager-coral.vercel.app](https://rd-task-manager-coral.vercel.app)

---

## 주요 기능

### 과제 관리
- 과제 CRUD (생성/조회/수정/삭제)
- 책임자(PI) + 담당자(실무) 지정
- 팀 멤버 다중 선택
- 상태별 필터 (기획/진행/완료/보류/취소)
- 과제 검색

### 업무 관리
- 독립 업무 + 연계 업무 (과제 소속)
- 하위 업무 (parent_task_id 기반 트리 구조)
- 드래그 앤 드롭 이동 (독립↔연계, 순서 변경)
- 상태별 필터 (계획/진행/지연/완료/진행불가)
- NEW 뱃지 (빨간색, 등록 24시간 이내)
- 완료 뱃지 (초록색, 완료 24시간 이내)
- 완료 탭 필터 (전체 완료 / 부분 완료 포함)
- 업무 검색 (연계업무 포함, 부모 자동 펼침)
- 검색창 클리어(X) 버튼
- 색상 태그 (긴급/중요/일반/없음)

### 회의 관리
- 회의 CRUD + 4탭 상세 (안건/참석자/문서/타임라인)
- 대면/비대면/하이브리드 모드
- 준비 타임라인 자동 생성 + 편집/삭제/추가
- 타임라인 드래그 앤 드롭 순서 변경
- 체크박스 토글 (완료↔해제)
- 이전 회의 불러오기 (생성 시 전체 양식 가져오기)

### 회의 녹음 & AI 회의록
- Web Speech API 실시간 음성인식 (한국어)
- Gemini 2.5 Pro AI 회의록 자동 생성
- AI 업무 자동 추출 (담당자/프로젝트 자동 매칭)
- 외부 오디오 파일 업로드 (m4a/mp3/wav, 최대 2GB, Gemini File API)
- 플로팅 녹음 컨트롤러 (백그라운드 녹음, 다른 화면 이동 가능)
- 회의록 재작성 기능
- 텍스트 청크 분할 (80,000자 초과 시 자동 분할 → 요약 → 병합)
- 이름 교정 + 프로젝트 자동 매칭
- 회의록에서 추출한 업무를 연계업무(하위업무)로 등록 가능

### 팀 활동 추적 & 이메일 알림
- activity_logs 테이블에 모든 변경사항 자동 기록 (DB 트리거)
- 대시보드 "최근 팀 활동" 패널 (Realtime 스트림, 24시간 이내)
- 전체 활동 로그 화면 (/activity, 날짜별 그룹핑, 엔티티 필터)
- 3시간 단위 요약 이메일 (pg_cron + pg_net + Resend API)
- 연계업무 등록 시 상위 독립업무명 함께 표시

### 캘린더
- 월간/주간/일간 뷰 통합
- 4가지 이벤트 유형 (업무/회의/과제/일일기록)

### 메모
- 개인 메모 (완전 비공개, Admin도 타인 접근 불가)
- 카테고리 분류 (아이디어/메모/할일/기타)
- 검색 + 고정(Pin) 기능

### 모바일 최적화
- PWA 지원 (아이폰 홈 화면 추가로 네이티브 앱 경험)
- 모바일 컴팩트 레이아웃 (600px 이하)
- 모바일 5탭 네비게이션 + 더보기 메뉴

### 기타
- Supabase Auth 로그인/회원가입 + 비밀번호 찾기
- 역할 기반 권한 (PI/연구원/외부)
- 로그인 에러 한국어 SnackBar
- 앱 아이콘 (KIMM 블루 + R&D)
- FAB 버튼 플로팅 바 회피
- 드래그 중 자동 스크롤

---

## 기술 스택

| 영역 | 기술 |
|------|------|
| **Framework** | Flutter 3.38 (Dart 3.10) — Web 우선 |
| **UI** | Material 3 (Material You), KIMM Blue #1565C0 |
| **State** | Riverpod (flutter_riverpod) |
| **Routing** | GoRouter (go_router) |
| **Backend** | Supabase (PostgreSQL, Auth, Realtime, Storage) |
| **AI** | Google Gemini 2.5 Pro (회의록 생성, 업무 추출) |
| **STT** | Web Speech API (한국어 음성인식) |
| **Email** | Resend API (활동 요약 이메일) |
| **Scheduler** | pg_cron + pg_net (3시간마다 이메일 발송) |
| **Deploy** | Vercel (정적 웹 호스팅) |

---

## 프로젝트 구조

```
lib/
├── app/                        # 앱 설정
│   ├── router.dart             # GoRouter 라우트 정의
│   ├── theme.dart              # Material 3 테마
│   └── app.dart                # MaterialApp 진입점
├── core/                       # 공유 유틸리티
│   ├── constants/              # 색상, 크기, 문자열 상수
│   ├── services/               # Gemini AI 서비스
│   └── extensions/             # Dart 확장 메서드
├── features/
│   ├── activity/               # 팀 활동 추적
│   ├── auth/                   # 인증 (로그인, 회원가입)
│   ├── calendar/               # 캘린더 뷰
│   ├── dashboard/              # 대시보드 + 설정
│   ├── meetings/               # 회의 관리 + AI 회의록 + 녹음
│   ├── memos/                  # 개인 메모
│   ├── projects/               # 과제 관리
│   └── tasks/                  # 업무 관리
└── shared/                     # 공유 위젯, 모델

supabase/
├── migrations/                 # SQL 마이그레이션 (001~024)
└── functions/                  # Edge Function (참고용)

docs/
├── database-schema.md          # DB 스키마 문서
└── activity-digest-setup.md    # 이메일 설정 가이드
```

각 feature 내부 구조:
```
feature_name/
├── data/repositories/          # Supabase 쿼리 구현
├── domain/models/              # 데이터 모델
├── presentation/screens/       # 화면 위젯
│                └── widgets/   # 하위 위젯
└── providers/                  # Riverpod 프로바이더
```

---

## 라우트 목록

| 경로 | 화면 | 비고 |
|------|------|------|
| `/dashboard` | 대시보드 | 홈, 통계+활동+일정+과제 |
| `/projects` | 과제 목록 | 탭 |
| `/tasks` | 업무 목록 | 탭 |
| `/meetings` | 회의 목록 | 탭 |
| `/calendar` | 캘린더 | 탭 |
| `/memos` | 메모 목록 | 탭 |
| `/settings` | 설정 | 탭 |
| `/activity` | 전체 활동 로그 | 독립 |
| `/projects/create` | 과제 생성 | |
| `/projects/:id` | 과제 상세 | |
| `/projects/:id/edit` | 과제 수정 | |
| `/tasks/create` | 업무 생성 | |
| `/tasks/:id` | 업무 상세 | |
| `/tasks/:id/edit` | 업무 수정 | |
| `/meetings/create` | 회의 생성 | |
| `/meetings/:id` | 회의 상세 (4탭) | |
| `/meetings/edit/:id` | 회의 수정 | |
| `/meetings/:id/record` | 회의 녹음 | |
| `/meetings/:id/minutes-result` | 회의록 결과 | |
| `/memos/:id` | 메모 상세 | |

---

## 환경 변수

`.env` 파일에 다음 키를 설정합니다 (`.env.example` 참고):

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
GEMINI_API_KEY=your-gemini-api-key
```

---

## 실행 방법

```bash
flutter pub get           # 의존성 설치
cp .env.example .env      # 환경변수 설정
flutter run -d chrome     # 개발 실행
flutter analyze           # 정적 분석
flutter test              # 유닛 테스트
```

---

## 배포

```bash
flutter clean
flutter build web --release
cd build/web && rm -rf .vercel
vercel --prod --name rd-task-manager --yes
```

배포 URL: `rd-task-manager-coral.vercel.app`

> `.vercel` 폴더 삭제 필수 — 이전 프로젝트 설정이 남아있으면 잘못된 곳에 배포됨

---

## 외부 서비스 설정

### Supabase
- Dashboard에서 Extensions 활성화: `pg_cron`, `pg_net`
- `supabase/migrations/` 폴더의 SQL을 순서대로 실행
- Storage 버킷 수동 생성: `project-files`, `task-files`, `meeting-files`

### Gemini AI
- Google AI Studio에서 API 키 발급
- `.env`의 `GEMINI_API_KEY`에 설정
- 모델: `gemini-2.5-pro`

### Resend (이메일)
- [resend.com](https://resend.com) 가입 (무료 100통/일)
- API 키 발급 후 `send_activity_digest()` 함수에 설정
- 발신자: `noreply@sartexo.com` (커스텀 도메인)
- 수신자: `parkch@kimm.re.kr`
- 상세 설정: `docs/activity-digest-setup.md` 참조
