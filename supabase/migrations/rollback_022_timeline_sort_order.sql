-- Rollback 022: Remove sort_order from meeting_timeline
ALTER TABLE public.meeting_timeline DROP COLUMN IF EXISTS sort_order;
