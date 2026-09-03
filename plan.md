# The N Resort Management — 프로젝트 플랜

## 프로젝트 비전
The N Resort의 대표·관리자·직원이 **매일의 업무를 한 곳에서 지시·수행·보고**하고, 대표는 **한 달에 한 번만 방문**해도 앱 화면과 매일 오는 이메일 요약만으로 **호텔 전반의 운영 상태를 파악**할 수 있는 웹앱.

기존 R&D 과제 관리 앱(`rd-task-manager`)의 코드 구조를 재활용하되, 원작자 리소스와는 완전히 단절된 상태에서 호텔 도메인으로 재설계한다.

---

## 핵심 사용자 (3가지 페르소나)

### 1. 대표 (CEO)
- **현실**: 한 달에 한 번만 리조트 방문. 항상 바쁨.
- **니즈**: 매일 이메일로 하루 요약만 봐도 전체 파악. 필요할 때 앱으로 세부 확인.
- **핵심 사용 화면**: 대시보드(요약), 이메일 다이제스트, (필요 시) 부서별/직원별 조회.

### 2. 관리자 (Manager)
- **현실**: 현장에서 직접 업무를 배정하고 진행을 확인. PC와 폰 모두 사용.
- **니즈**: 빠른 업무 지시, 진행 상태 파악, 지연/미완료 즉시 인지, 반복 업무 자동화.
- **핵심 사용 화면**: 업무 지시(생성), 부서별 업무 뷰, 오늘 완료율.

### 3. 직원 (Staff)
- **현실**: 대부분 폰으로 확인/보고. 현장 이동 중.
- **니즈**: 오늘 내가 할 일 확인, 완료 보고(메모+사진), 미완료 시 사유 입력.
- **핵심 사용 화면**: 내 업무 리스트, 보고 시트(하단 팝업), 반복 업무 알림.

---

## 마일스톤

### M1 — Foundation (문서 + 정리)
- Step 1: 문서 스캐폴딩 완료 (`plan/progress/task/lessons/README/CLAUDE`)
- Step 2: R&D 잔재 코드/스키마 삭제 완료

### M2 — Backend (스키마 + 이메일)
- Step 3: 호텔 스키마 SQL 작성 + Supabase에 수동 적용
- `send_daily_digest()` 함수 동작 확인 (수신자 설정 화면 포함)
- `generate_recurring_tasks()` cron 등록

### M3 — Frontend MVP
- Step 4의 C-1 ~ C-4:
  - Auth 역할 3단계 반영
  - Departments (부서) 관리 화면
  - Tasks 재정의 (일회성, 완료 보고, 사진, 지연 사유)
  - Dashboard 역할별 뷰
- **End-to-End 검증**: 관리자 로그인 → 업무 지시 → 직원 로그인 → 완료 보고 → 대표 이메일 수신

### M4 — Frontend 완성
- Step 4의 C-5 ~ C-9:
  - Calendar/Memos/Activity/Navigation 정리
  - 반복 업무 UI (관리자용 반복 패턴 설정 화면)
  - 문자열 최종 정리

### M5 — Polish + 발표 준비
- README.md 최종 갱신 (실제 구현된 것 반영)
- Vercel 배포
- 스크린샷 촬영 (`docs/screenshots/`)
- The N Resort 방문 발표

---

## Step별 요약

| Step | 이름 | 세부 | 완료 기준(DoD) | 상태 |
|---|---|---|---|---|
| 1 | 문서 스캐폴딩 | plan/progress/task/lessons/README/CLAUDE | 6개 파일 존재, 커밋됨 | 진행 중 |
| 2 | R&D 잔재 삭제 | Meetings/AI/STT/daily_logs 등 코드 삭제, 원작자 문서 정리 | grep으로 잔재 확인 시 0, `flutter analyze` 통과 | 미착수 |
| 3 | 호텔 스키마 (Supabase) | departments/tasks 재정의, 신규 함수/cron, RLS | Supabase Dashboard에서 마이그레이션 완료, 기본 5개 부서 삽입 | 미착수 |
| 4 | Flutter 코드 재구성 | Auth/Dept/Tasks/Dashboard/Calendar/Memos/Activity/Nav | End-to-end 시나리오 통과, `flutter build web` 성공 | 미착수 |

각 Step의 세부 태스크는 `task.md`, 진행 상태는 `progress.md`에서 관리.

---

## 확정된 설계 결정 (요약)

| 항목 | 결정 |
|---|---|
| 사용자 역할 | 3단계: 대표(CEO) + 관리자(Manager) + 직원(Staff) |
| 업무 유형 | 일회성 + 반복 (매일/매주 반복 패턴 지원) |
| 보고 방식 | 완료 체크 + 짧은 메모 + 사진 첨부(선택) + 미완료/지연 시 사유 필수 |
| "프로젝트" 개념 | **부서/팀**으로 재정의 (프론트/하우스키핑/F&B/시설/경영지원) |
| 이메일 | 매일 1회, 발송 시각은 관리자가 설정 화면에서 조정 |
| 이메일 수신자 | 설정 화면에서 관리 (`digest_recipients` 테이블) |
| 반복 업무 인스턴스 생성 | 매일 자정 KST 자동 (`generate_recurring_tasks`) |
| 부서 초기 데이터 | 기본 5개 seed (프론트/하우스키핑/F&B/시설/경영지원), 이후 CRUD |
| 사용 환경 | PC + 폰 모두 (반응형) |
| 유지할 R&D 기능 | Calendar, Memos, File Attachments |
| 폐기 | Meetings 전체, AI/STT/Gemini, 회의록, daily_logs, task_updates |

---

## 스코프 밖 (별도 논의)
- 이메일 발신 도메인 커스텀 (`noreply@thenresort.com` 등) — 도메인 확보 후
- Supabase Vault로 Resend 키 이관 — 보안 강화, 필수 아님
- Push 알림 (FCM) — 이메일이 우선
- 게스트/객실/예약 관리 — 이 앱은 "업무/직원" 중심
- 다국어 (i18n) — 한국어 우선

---

## 참고 문서
- `progress.md` — 진행 상황
- `task.md` — 세부 태스크
- `lessons.md` — 진행 중 배운 교훈
- `README.md` — 발표 자료 참조용 프로그램 소개
- `CLAUDE.md` — AI 세션용 지침
- `docs/legacy-structure-map.md` — 원본 R&D 구조 분석 (1차 플랜 산출물)
