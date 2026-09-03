-- Rollback 021: meeting_notes, raw_transcript 컬럼 제거
-- 주의: 이 작업은 기존 데이터를 삭제합니다

ALTER TABLE meetings
  DROP COLUMN IF EXISTS meeting_notes,
  DROP COLUMN IF EXISTS raw_transcript;
