-- ============================================================
-- Hotel Migration 005: activity_logs entity_type 축소
-- ============================================================
-- 기존: tasks, projects, meetings, memos, meeting_timeline
-- 신규: tasks, departments, memos
-- ============================================================

-- 1. 기존 데이터 정리: projects/meetings/meeting_timeline 관련 로그는 삭제
--    (호텔 앱과 무관한 R&D 활동 기록)
DELETE FROM public.activity_logs
WHERE entity_type IN ('projects', 'meetings', 'meeting_timeline');

-- 2. entity_type CHECK 재설정
ALTER TABLE public.activity_logs DROP CONSTRAINT IF EXISTS activity_logs_entity_type_check;
ALTER TABLE public.activity_logs
  ADD CONSTRAINT activity_logs_entity_type_check
  CHECK (entity_type IN ('tasks', 'departments', 'memos'));

-- ============================================================
-- ROLLBACK
-- ============================================================
-- ALTER TABLE public.activity_logs DROP CONSTRAINT activity_logs_entity_type_check;
-- ALTER TABLE public.activity_logs ADD CONSTRAINT activity_logs_entity_type_check
--   CHECK (entity_type IN ('tasks','projects','meetings','memos','meeting_timeline'));
