-- Rollback 019
ALTER TABLE public.tasks ALTER COLUMN show_in_calendar SET DEFAULT true;
-- NOTE: cannot restore original show_in_calendar values
ALTER TABLE public.projects DROP COLUMN IF EXISTS show_in_calendar;
