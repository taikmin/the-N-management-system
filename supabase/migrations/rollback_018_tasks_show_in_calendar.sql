-- Rollback 018: Remove show_in_calendar column from tasks table
ALTER TABLE public.tasks DROP COLUMN IF EXISTS show_in_calendar;
