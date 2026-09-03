-- Rollback Migration 026
-- ⚠️ 데이터 손실 주의: assignee_id/show_in_calendar 컬럼 값이 영구 삭제됩니다.

DROP INDEX IF EXISTS public.idx_projects_assignee_id;

ALTER TABLE public.projects
  DROP COLUMN IF EXISTS show_in_calendar;

ALTER TABLE public.projects
  DROP COLUMN IF EXISTS assignee_id;

NOTIFY pgrst, 'reload schema';
