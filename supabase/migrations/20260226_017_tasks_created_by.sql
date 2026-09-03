-- Migration 017: Add created_by column to tasks table
-- Purpose: Track who created each task (게시자 표시)

-- Add created_by column with auth.uid() default
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.profiles(id) DEFAULT auth.uid();

-- Backfill existing tasks: set created_by = assignee_id where null
UPDATE public.tasks
  SET created_by = assignee_id
  WHERE created_by IS NULL AND assignee_id IS NOT NULL;
