-- Rollback 023: Activity Logs
DROP TRIGGER IF EXISTS trg_activity_tasks ON public.tasks;
DROP TRIGGER IF EXISTS trg_activity_projects ON public.projects;
DROP TRIGGER IF EXISTS trg_activity_meetings ON public.meetings;
DROP TRIGGER IF EXISTS trg_activity_memos ON public.memos;
DROP TRIGGER IF EXISTS trg_activity_timeline ON public.meeting_timeline;
DROP FUNCTION IF EXISTS log_activity();
DROP TABLE IF EXISTS public.activity_logs;
