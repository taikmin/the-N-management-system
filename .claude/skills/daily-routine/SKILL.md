---
name: daily-routine
description: 매일 작업 시작 시 자동 루틴을 실행합니다.
  "오늘 작업 시작", "daily start", "일일 루틴" 키워드 시 사용합니다.
---

# 일일 작업 시작 루틴

## 수행 절차
1. git pull origin main 으로 최신 코드 동기화
2. conductor:status로 전체 진도 확인
3. 어제 일일 보고서(docs/daily-log/) 확인
4. 오늘 수행할 태스크 목록 정리 및 우선순위 결정
5. 가장 높은 우선순위 태스크부터 구현 시작
6. 구현 → 테스트 → 리뷰 → 커밋 사이클 반복
7. 작업 종료 시:
   - docs/daily-log/YYYY-MM-DD.md에 일일 보고서 생성
   - CHANGELOG.md 업데이트
   - git push origin main
8. 나에게 묻지 말고 자율적으로 진행
9. 블로커 발생 시 Plan B 전환 후 기록
10. 완료되면 오늘의 성과를 요약 보고
