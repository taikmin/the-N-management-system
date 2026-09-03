-- Rollback 017: Remove created_by column from tasks table
ALTER TABLE public.tasks DROP COLUMN IF EXISTS created_by;
