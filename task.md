# The N Resort Management — 세부 태스크 리스트

> 태스크 ID 규칙: `T-{Step}{Section}-{순번}` (예: `T-1A-01`)
> 상태: ⏳ 미착수 / 🟡 진행 중 / ✅ 완료 / ⛔ 블록 / ❌ 취소

---

## Step 1 — 문서 스캐폴딩

| ID | 태스크 | DoD | 의존 | 상태 |
|---|---|---|---|---|
| T-1A-01 | 원작자 `README.md`, `README.html` 삭제 | 파일 없음 | - | ✅ |
| T-1A-02 | `plan.md` 작성 | 로드맵/마일스톤/사용자/설계 결정 포함 | - | ✅ |
| T-1A-03 | `progress.md` 작성 | 완료/진행 중/미착수/블록 섹션 | T-1A-02 | ✅ |
| T-1A-04 | `task.md` 작성 (이 파일) | Step 1~4 모든 태스크 나열 | T-1A-02 | ✅ |
| T-1A-05 | `lessons.md` 작성 | 1차 플랜 교훈 초기 항목 포함 | - | ✅ |
| T-1A-06 | `README.md` 호텔 발표용 초안 작성 | 8개 목차 섹션 채워짐 | T-1A-02 | ✅ |
| T-1A-07 | `CLAUDE.md` 2차 플랜 상태로 갱신 | Step 1~4 명시, 새 파일 참조 | T-1A-02 | ✅ |
| T-1A-08 | Step 1 커밋 & push | 커밋 메시지 conv commits 규칙, `origin/main` push | 모두 | ⏳ |

---

## Step 2 — R&D 잔재 삭제 (2A/2B 분할)

> **분할**: 참고 가치 낮은 것은 Step 2A(지금), supabase/migrations/, docs/database-schema.md 등 스키마 참고 자료는 Step 3 완료 후 Step 2B에서 삭제.
> **유예 (Step 4로)**: T-2A-06, T-2A-07 (daily_log/task_updates/task_comments) - Tasks 재설계 시 함께 삭제.


### 코드 삭제
| ID | 태스크 | DoD | 의존 | 상태 |
|---|---|---|---|---|
| T-2A-01 | `lib/features/meetings/` 폴더 통째 삭제 | 폴더 부재, `flutter analyze` 통과 | - | ✅ |
| T-2A-02 | `lib/core/services/gemini_service.dart`, `ai_service.dart` 삭제 | 파일 부재 | - | ✅ |
| T-2A-03 | STT 관련 파일 삭제 (`speech_recognition_*.dart`, `speech_service.dart`) | 파일 부재 | - | ✅ |
| T-2A-04 | `recording_provider.dart` 및 관련 provider 삭제 | 파일 부재, 참조 없음 | T-2A-03 | ✅ |
| T-2A-05 | `floating_recording_controller.dart` 삭제 | 파일 부재 | - | ✅ |
| T-2A-06 | `lib/features/tasks/**/daily_log*.dart`, `daily_check_screen.dart` 삭제 | 파일 부재 | - | ✅ |
| T-2A-07 | `lib/features/tasks/**/task_updates*.dart`, `task_comments*.dart` 삭제 | 파일 부재 | - | ✅ |
| T-2A-08 | `.env`에서 `GEMINI_API_KEY` 제거 | 키 부재 | T-2A-02 | ✅ |

### 라우팅/네비게이션
| ID | 태스크 | DoD | 의존 | 상태 |
|---|---|---|---|---|
| T-2B-01 | `router.dart`에서 meeting/record 라우트 제거 | grep `meeting` 시 0, `flutter analyze` 통과 | T-2A-01 | ✅ |
| T-2B-02 | `app_navigation_shell.dart`에서 "회의" 탭 제거 | 탭 4~5개 (대시보드/업무/캘린더/메모/설정) | T-2A-01 | ✅ |
| T-2B-03 | Dashboard의 `_UpcomingMeetingsPreview` 위젯 제거 | 참조 없음 | T-2A-01 | ✅ |

### Provider 정리
| ID | 태스크 | DoD | 의존 | 상태 |
|---|---|---|---|---|
| T-2C-01 | `meetingListProvider`, `recordingProvider` 등 파일 삭제 | 파일 부재 | T-2A-01 | ✅ |
| T-2C-02 | `activity_provider.dart`의 meeting/timeline 처리 제거 | switch/enum에서 해당 case 없음 | - | ✅ |
| T-2C-03 | Import 정리 (orphaned imports) | `flutter analyze` unused import 0 | 모두 | ✅ |

### 원작자 문서 정리
| ID | 태스크 | DoD | 의존 | 상태 |
|---|---|---|---|---|
| T-2D-01 | `conductor/` 폴더 삭제 | 폴더 부재 | - | ✅ |
| T-2D-02 | `docs/database-schema.md`, `docs/architecture.md`, `docs/activity-digest-setup.md`, `docs/daily-log/` 삭제 | 파일 부재 | - | ⏳ |
| T-2D-03 | `docs/legacy-structure-map.md`는 유지 | 파일 존재 확인 | - | ✅ |
| T-2D-04 | `CHANGELOG.md` 초기화 (신규 시작) | 호텔용 새 이력 | - | ✅ |
| T-2D-05 | `supabase/migrations/` 원작자 SQL 삭제 (Step 3 새 마이그레이션으로 대체) | 폴더 비어있거나 새 파일만 | - | ⏳ |

### Step 2 마무리
| ID | 태스크 | DoD | 의존 | 상태 |
|---|---|---|---|---|
| T-2Z-01 | `flutter analyze` 통과 | 오류 0 | 모든 삭제 | ✅ |
| T-2Z-02 | Step 2 커밋 & push | conv commits | T-2Z-01 | ✅ |
| T-2Z-03 | `progress.md` 갱신 | Step 2 완료 표시 | T-2Z-02 | ⏳ |
| T-2Z-04 | `lessons.md`에 Step 2 교훈 추가 | 최소 1항목 | T-2Z-02 | ⏳ |

---

## Step 3 — 호텔 스키마 (Supabase)

### 마이그레이션 SQL 작성
| ID | 태스크 | DoD | 의존 | 상태 |
|---|---|---|---|---|
| T-3A-01 | `hotel_001_profiles_alter.sql` — role enum 교체, department_id 추가, Zoom 필드 제거 | SQL 파일 존재, syntax check | - | ✅ |
| T-3A-02 | `hotel_002_departments.sql` — departments 테이블 + 5개 기본 seed | SQL 파일, seed 포함 | T-3A-01 | ✅ |
| T-3A-03 | `hotel_003_tasks_alter.sql` — tasks 필드 재정의 (recurrence, delay_reason 등) | SQL 파일 | - | ✅ |
| T-3A-04 | `hotel_004_settings.sql` — app_settings, digest_recipients | SQL 파일 | - | ✅ |
| T-3A-05 | `hotel_005_activity_logs_alter.sql` — entity_type 축소 | SQL 파일 | - | ✅ |
| T-3A-06 | `hotel_006_drop_legacy.sql` — projects/meetings/*/daily_logs/task_updates/task_comments DROP | SQL 파일 | 위 모두 | ✅ |
| T-3A-07 | `hotel_007_functions.sql` — handle_new_user, log_activity, send_daily_digest, generate_recurring_tasks | SQL 파일 | T-3A-06 | ✅ |
| T-3A-08 | `hotel_008_rls.sql` — 역할별 RLS 정책 | SQL 파일 | T-3A-07 | ✅ |
| T-3A-09 | `hotel_009_cron.sql` — pg_cron 잡 등록 (digest 매시, recurring 매일 자정) | SQL 파일 | T-3A-07 | ✅ |

### Supabase 적용
| ID | 태스크 | DoD | 의존 | 상태 |
|---|---|---|---|---|
| T-3B-01 | 사용자에게 SQL 파일 순차 실행 안내 문서 (`docs/schema-migration-guide.md`) | 문서 존재 | T-3A-01~09 | ✅ |
| T-3B-02 | Supabase Dashboard에서 SQL 순차 실행 (사용자 수행) | 모든 테이블/함수/cron 존재 | T-3B-01 | ✅ |
| T-3B-03 | Storage 버킷 생성 (`task-photos` 또는 재사용) | 버킷 존재 | T-3B-02 | ✅ |
| T-3B-04 | RESEND_API_KEY를 Supabase Vault 또는 SQL 함수에 설정 | send_daily_digest 실행 시 이메일 발송 성공 | T-3B-02 | ✅ |
| T-3B-05 | `send_daily_digest()` 수동 호출 → 이메일 수신 확인 | 대표 이메일 수신 | T-3B-04 | ✅ |
| T-3B-06 | `generate_recurring_tasks()` 수동 호출 → 인스턴스 생성 확인 | 반복 템플릿의 인스턴스 존재 | T-3B-02 | ✅ |

### Step 3 마무리
| ID | 태스크 | DoD | 의존 | 상태 |
|---|---|---|---|---|
| T-3Z-01 | Step 3 커밋 & push | conv commits | 위 모두 | ✅ |
| T-3Z-02 | `progress.md` 갱신 | Step 3 완료 표시 | - | ✅ |
| T-3Z-03 | `lessons.md`에 Step 3 교훈 추가 | - | - | ✅ |

---

## Step 4 — Flutter 코드 재구성

### C-1: Auth
| ID | 태스크 | DoD | 의존 | 상태 |
|---|---|---|---|---|
| T-4A-01 | `user_role.dart` enum 교체 (ceo/manager/staff) | enum 3값, `fromString` 대응 | Step 3 | ✅ |
| T-4A-02 | `app_user.dart` 그리팅 문자열 갱신 | "대표님/관리자님/OO님" | T-4A-01 | ✅ |
| T-4A-03 | `app_strings.dart` 역할 라벨 갱신 | UI 문자열 반영 | T-4A-01 | ✅ |
| T-4A-04 | 회원가입 화면 role 선택 UI 조정 | 3개 옵션 | T-4A-01 | ✅ |

### C-2: Departments (projects 폴더 rename)
| ID | 태스크 | DoD | 의존 | 상태 |
|---|---|---|---|---|
| T-4B-01 | `lib/features/projects/` → `lib/features/departments/` 폴더 rename | 폴더명 변경, 파일명도 department_* 로 변경 | Step 3 | ✅ |
| T-4B-02 | Project 모델 → Department 모델 (필드 단순화) | Department 클래스, 필드: id/name/description/color/leadId | T-4B-01 | ✅ |
| T-4B-03 | Repository/Provider 수정 (departmentListProvider 등) | 새 스키마 반영 | T-4B-02 | ✅ |
| T-4B-04 | DepartmentListScreen, DepartmentDetailScreen, DepartmentCreateScreen 재작성 | UI 최소 CRUD | T-4B-02 | ✅ |
| T-4B-05 | 라우트 추가 `/departments`, `/departments/:id` (관리자 전용) | 라우터 반영, 가드 | T-4B-04 | ✅ |
| T-4B-06 | 모든 `import 'projects/'` → `import 'departments/'` 갱신 | grep 확인 | 위 모두 | ✅ |

### C-3: Tasks 핵심 개조
| ID | 태스크 | DoD | 의존 | 상태 |
|---|---|---|---|---|
| T-4C-01 | `task.dart` 모델 재정의 (신규 필드, 폐기 필드) | 필드 매핑 완료, JSON 파싱 | Step 3 | ✅ |
| T-4C-02 | `TaskStatus` enum 재정의 (assigned/inProgress/completed/incomplete/delayed) | enum 값 5개 | T-4C-01 | ✅ |
| T-4C-03 | Repository/Provider 수정 | 새 스키마 반영 | T-4C-01 | ✅ |
| T-4C-04 | `TaskListScreen` 필터/정렬 재구성 (오늘/이번주/미완료/부서별) | 필터 4종+ 정렬 3종 동작 | T-4C-03 | ✅ |
| T-4C-05 | `TaskCreateScreen` 관리자용 지시 화면 + 반복 패턴 UI | 반복 옵션 (일/주/월) 선택 UI | T-4C-03 | ✅ |
| T-4C-06 | `TaskDetailScreen` 지시 내용 + 보고 상태 + 사진 표시 | 상세 정보/사진 갤러리 | T-4C-03 | ✅ |
| T-4C-07 | `TaskReportSheet` (신규) 하단 시트 — 완료/미완료, 메모/사유, 사진 첨부 | 미완료 선택 시 delay_reason 필수 검증 | T-4C-03 | ✅ |
| T-4C-08 | 사진 첨부: file_attachments 재사용 | 업로드/미리보기 동작 | T-4C-07 | ✅ |

### C-4: Dashboard 역할별 뷰
| ID | 태스크 | DoD | 의존 | 상태 |
|---|---|---|---|---|
| T-4D-01 | Dashboard 역할별 스위칭 로직 | `switch(currentUser.role)` 분기 | T-4A-01 | ✅ |
| T-4D-02 | 대표 뷰: 오늘 완료율, 부서별 상태, 지연 요약 | 위젯 3개 이상 | T-4C-*, T-4B-* | ✅ |
| T-4D-03 | 관리자 뷰: 자기 부서 상태, 지시한 업무 완료율, 신규 지시 CTA | 위젯 + 버튼 | T-4C-* | ✅ |
| T-4D-04 | 직원 뷰: 오늘 내 업무, 이번 주 반복, 미완료 사유 알림 | 위젯 + 알림 배너 | T-4C-* | ✅ |

### C-5 ~ C-9
| ID | 태스크 | DoD | 의존 | 상태 |
|---|---|---|---|---|
| T-4E-01 | Calendar `CalendarEventType` enum 단순화 (task 중심) | enum 조정 | T-4C-01 | ✅ |
| T-4E-02 | Calendar에서 meeting 이벤트 소스 제거 | 참조 없음 | T-4E-01 | ⏳ |
| T-4F-01 | Memos 브랜딩 문자열 확인/조정 | R&D 잔재 0 | - | ⏳ |
| T-4G-01 | Activity Logs entity_type 매핑 갱신 (tasks/departments/memos) | 아이콘/라벨 반영 | T-4C-01 | ✅ |
| T-4H-01 | Navigation Shell 탭 재구성 (5개: 대시보드/업무/캘린더/메모/설정) | 탭 5개 렌더링 | T-2B-02 | ✅ |
| T-4H-02 | 관리자 전용 메뉴 (부서 관리/직원 관리/활동 로그) 위치 결정 및 반영 | 관리자 로그인 시 노출 | T-4A-01 | ✅ |
| T-4H-03 | SettingsScreen: 다이제스트 수신자 관리 + 발송 시각 설정 | CRUD + TimePicker | Step 3 | ⏳ |
| T-4I-01 | 하드코딩 문자열 최종 grep + 정리 | R&D/KIMM/한국기계연구원 0 | 위 모두 | ⏳ |

### Step 4 마무리
| ID | 태스크 | DoD | 의존 | 상태 |
|---|---|---|---|---|
| T-4Z-01 | `flutter analyze` 통과 | 오류 0 | 위 모두 | ⏳ |
| T-4Z-02 | `flutter test` 통과 (테스트는 R&D 잔재이므로 재작성 예상) | 통과 or 재작성 결정 | T-4Z-01 | ⏳ |
| T-4Z-03 | `flutter build web --release` 성공 | 빌드 산출물 존재 | T-4Z-01 | ⏳ |
| T-4Z-04 | End-to-end 시나리오 수동 검증 (관리자 지시 → 직원 보고 → 이메일 수신) | 시나리오 통과 | 위 모두 | ⏳ |
| T-4Z-05 | Step 4 커밋 & push | conv commits | T-4Z-04 | ⏳ |

---

## Polish + 발표 준비 (M5)

| ID | 태스크 | DoD | 의존 | 상태 |
|---|---|---|---|---|
| T-5-01 | Vercel 새 프로젝트 생성 + 배포 | 배포 URL 확보 | Step 4 완료 | ⏳ |
| T-5-02 | 스크린샷 촬영 (`docs/screenshots/hotel_*.png`) | 주요 화면 5장+ | T-5-01 | ⏳ |
| T-5-03 | `README.md` 최종 갱신 (실제 구현 반영, 스크린샷 삽입) | 발표 자료 만들기에 충분한 정보 | T-5-02 | ⏳ |
| T-5-04 | 로컬 폴더명 오타 수정 (`magnagement` → `management`, 세션 종료 후 수동) | 폴더명 정정 | - | ⏳ |
| T-5-05 | The N Resort 방문 발표 자료 준비 (README 참조) | 발표 슬라이드 등 | T-5-03 | ⏳ |

---

## 태스크 진행 원칙
- 태스크 완료 시 이 파일의 상태를 ⏳ → ✅ 로 변경, `progress.md`에도 반영
- 새 태스크 발생 시 여기 추가하되 ID 규칙 유지
- 블록 발생 시 상태 ⛔ + `progress.md` "블록/이슈" 섹션에 상세 기록
- 완료된 태스크의 커밋 해시를 함께 기록하면 추적 용이
