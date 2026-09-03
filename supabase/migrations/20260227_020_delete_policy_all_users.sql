-- ============================================================================
-- 020: DELETE 정책 변경 — 인증된 사용자 모두 삭제 가능
--
-- 변경 내용:
--   - 모든 공용 테이블의 DELETE 정책을 is_admin()에서 auth.uid() IS NOT NULL로 변경
--   - memos는 기존 유지 (user_id = auth.uid() 본인 것만)
--   - file_attachments는 인증된 사용자 모두 삭제 가능으로 변경
--
-- Supabase SQL Editor에서 실행하세요.
-- ============================================================================


-- ╔══════════════════════════════════════════════════════════════╗
-- ║  기존 DELETE 정책 삭제                                        ║
-- ╚══════════════════════════════════════════════════════════════╝

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


-- ╔══════════════════════════════════════════════════════════════╗
-- ║  새 DELETE 정책 — 인증된 사용자 모두 허용                       ║
-- ╚══════════════════════════════════════════════════════════════╝

-- projects
CREATE POLICY "projects_delete" ON public.projects FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- project_members
CREATE POLICY "pm_delete" ON public.project_members FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- tasks
CREATE POLICY "tasks_delete" ON public.tasks FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- daily_logs
CREATE POLICY "daily_logs_delete" ON public.daily_logs FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- task_comments
CREATE POLICY "task_comments_delete" ON public.task_comments FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- meetings
CREATE POLICY "meetings_delete" ON public.meetings FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- meeting_participants
CREATE POLICY "mp_delete" ON public.meeting_participants FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- meeting_documents
CREATE POLICY "md_delete" ON public.meeting_documents FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- meeting_agenda
CREATE POLICY "ma_delete" ON public.meeting_agenda FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- meeting_timeline
CREATE POLICY "mt_delete" ON public.meeting_timeline FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- file_attachments (기존: uploader OR admin → 변경: 인증된 사용자 모두)
CREATE POLICY "file_attachments_delete" ON public.file_attachments FOR DELETE
  USING (auth.uid() IS NOT NULL);

-- ※ memos는 변경 없음 (기존 유지: user_id = auth.uid())

-- ╔══════════════════════════════════════════════════════════════╗
-- ║  완료! 인증된 사용자 모두 삭제 가능 (메모만 본인 것만)            ║
-- ╚══════════════════════════════════════════════════════════════╝
