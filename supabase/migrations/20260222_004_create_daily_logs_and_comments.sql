-- ============================================================
-- Migration: daily_logs 테이블 (일일 수행 기록)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.daily_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  log_date DATE NOT NULL DEFAULT CURRENT_DATE,
  content TEXT NOT NULL,                    -- 수행내용
  issues TEXT,                              -- 이슈사항
  next_plan TEXT,                           -- 다음 계획
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_daily_logs_task_id ON public.daily_logs(task_id);
CREATE INDEX idx_daily_logs_author_id ON public.daily_logs(author_id);
CREATE INDEX idx_daily_logs_log_date ON public.daily_logs(log_date);

CREATE TRIGGER daily_logs_updated_at
  BEFORE UPDATE ON public.daily_logs
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- Migration: task_comments 테이블 (태스크 댓글)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.task_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_task_comments_task_id ON public.task_comments(task_id);

CREATE TRIGGER task_comments_updated_at
  BEFORE UPDATE ON public.task_comments
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- RLS Policies
-- ============================================================

ALTER TABLE public.daily_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_comments ENABLE ROW LEVEL SECURITY;

-- daily_logs 조회: 과제 멤버
CREATE POLICY "Project members can view daily logs"
  ON public.daily_logs FOR SELECT
  USING (
    task_id IN (
      SELECT t.id FROM public.tasks t
      WHERE t.project_id IN (
        SELECT pm.project_id FROM public.project_members pm WHERE pm.user_id = auth.uid()
      )
      OR t.project_id IN (
        SELECT p.id FROM public.projects p WHERE p.owner_id = auth.uid()
      )
    )
  );

-- daily_logs 생성: 인증 사용자 (본인 기록)
CREATE POLICY "Users can create own daily logs"
  ON public.daily_logs FOR INSERT
  WITH CHECK (author_id = auth.uid());

-- daily_logs 수정: 본인만
CREATE POLICY "Users can update own daily logs"
  ON public.daily_logs FOR UPDATE
  USING (author_id = auth.uid());

-- daily_logs 삭제: 본인만
CREATE POLICY "Users can delete own daily logs"
  ON public.daily_logs FOR DELETE
  USING (author_id = auth.uid());

-- task_comments 조회: 과제 멤버
CREATE POLICY "Project members can view comments"
  ON public.task_comments FOR SELECT
  USING (
    task_id IN (
      SELECT t.id FROM public.tasks t
      WHERE t.project_id IN (
        SELECT pm.project_id FROM public.project_members pm WHERE pm.user_id = auth.uid()
      )
      OR t.project_id IN (
        SELECT p.id FROM public.projects p WHERE p.owner_id = auth.uid()
      )
    )
  );

-- task_comments 생성: 인증 사용자
CREATE POLICY "Users can create comments"
  ON public.task_comments FOR INSERT
  WITH CHECK (author_id = auth.uid());

-- task_comments 수정: 본인만
CREATE POLICY "Users can update own comments"
  ON public.task_comments FOR UPDATE
  USING (author_id = auth.uid());

-- task_comments 삭제: 본인만
CREATE POLICY "Users can delete own comments"
  ON public.task_comments FOR DELETE
  USING (author_id = auth.uid());
