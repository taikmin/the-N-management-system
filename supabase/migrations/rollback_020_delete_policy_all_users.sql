-- ============================================================================
-- ROLLBACK 020: DELETE 정책 원복 — Admin만 삭제 가능
-- ============================================================================

DROP POLICY IF EXISTS "projects_delete" ON public.projects;
DROP POLICY IF EXISTS "pm_delete" ON public.project_members;
DROP POLICY IF EXISTS "tasks_delete" ON public.tasks;
DROP POLICY IF EXISTS "daily_logs_delete" ON public.daily_logs;
DROP POLICY IF EXISTS "task_comments_delete" ON public.task_comments;
DROP POLICY IF EXISTS "meetings_delete" ON public.meetings;
DROP POLICY IF EXISTS "mp_delete" ON public.meeting_participants;
DROP POLICY IF EXISTS "md_delete" ON public.meeting_documents;
DROP POLICY IF EXISTS "ma_delete" ON public.meeting_agenda;
DROP POLICY IF EXISTS "mt_delete" ON public.meeting_timeline;
DROP POLICY IF EXISTS "file_attachments_delete" ON public.file_attachments;

CREATE POLICY "projects_delete" ON public.projects FOR DELETE
  USING (public.is_admin());
CREATE POLICY "pm_delete" ON public.project_members FOR DELETE
  USING (public.is_admin() OR project_id IN (SELECT id FROM public.projects WHERE owner_id = auth.uid()));
CREATE POLICY "tasks_delete" ON public.tasks FOR DELETE
  USING (public.is_admin());
CREATE POLICY "daily_logs_delete" ON public.daily_logs FOR DELETE
  USING (public.is_admin());
CREATE POLICY "task_comments_delete" ON public.task_comments FOR DELETE
  USING (public.is_admin());
CREATE POLICY "meetings_delete" ON public.meetings FOR DELETE
  USING (public.is_admin());
CREATE POLICY "mp_delete" ON public.meeting_participants FOR DELETE
  USING (public.is_admin());
CREATE POLICY "md_delete" ON public.meeting_documents FOR DELETE
  USING (public.is_admin());
CREATE POLICY "ma_delete" ON public.meeting_agenda FOR DELETE
  USING (public.is_admin());
CREATE POLICY "mt_delete" ON public.meeting_timeline FOR DELETE
  USING (public.is_admin());
CREATE POLICY "file_attachments_delete" ON public.file_attachments FOR DELETE
  USING (auth.uid() = uploader_id OR public.is_admin());
