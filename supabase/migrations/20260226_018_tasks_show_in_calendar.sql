-- Migration 018: Add show_in_calendar column to tasks table
-- Purpose: Allow users to control which tasks appear on the calendar

ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS show_in_calendar BOOLEAN DEFAULT true;
