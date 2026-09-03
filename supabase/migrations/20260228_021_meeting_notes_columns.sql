-- 021: 회의록 및 녹음 원문 컬럼 추가
-- meetings 테이블에 meeting_notes, raw_transcript 컬럼 추가

ALTER TABLE meetings
  ADD COLUMN IF NOT EXISTS meeting_notes TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS raw_transcript TEXT DEFAULT NULL;

COMMENT ON COLUMN meetings.meeting_notes IS 'AI가 정리한 회의록';
COMMENT ON COLUMN meetings.raw_transcript IS '음성 인식 원문 텍스트';
