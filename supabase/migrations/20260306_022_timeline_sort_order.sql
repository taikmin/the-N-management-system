-- Migration 022: Add sort_order to meeting_timeline
-- Enables drag-and-drop reordering of timeline items

ALTER TABLE public.meeting_timeline
  ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;

-- Initialize sort_order based on existing due_date order
WITH ranked AS (
  SELECT id, ROW_NUMBER() OVER (
    PARTITION BY meeting_id ORDER BY due_date
  ) - 1 AS rn
  FROM public.meeting_timeline
)
UPDATE public.meeting_timeline
SET sort_order = ranked.rn
FROM ranked
WHERE public.meeting_timeline.id = ranked.id;
