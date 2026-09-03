-- Migration 023: Activity Logs + DB Triggers
-- 팀원 활동 변경사항 자동 기록

-- 1. activity_logs 테이블
CREATE TABLE IF NOT EXISTS public.activity_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  user_name TEXT,
  action TEXT NOT NULL,        -- 'create', 'update', 'delete', 'complete'
  entity_type TEXT NOT NULL,   -- 'tasks', 'projects', 'meetings', 'memos', 'meeting_timeline'
  entity_id UUID,
  entity_title TEXT,
  details JSONB,               -- 변경 상세 (이전값/새값 등)
  created_at TIMESTAMPTZ DEFAULT now(),
  notified BOOLEAN DEFAULT false  -- 이메일 발송 여부
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at
  ON public.activity_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_notified
  ON public.activity_logs(notified) WHERE notified = false;
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id
  ON public.activity_logs(user_id);

-- RLS: 인증 사용자 조회 가능
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "activity_logs_select" ON public.activity_logs;
CREATE POLICY "activity_logs_select" ON public.activity_logs
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "activity_logs_insert" ON public.activity_logs;
CREATE POLICY "activity_logs_insert" ON public.activity_logs
  FOR INSERT WITH CHECK (true);  -- 트리거(SECURITY DEFINER)가 삽입

-- 2. 범용 활동 기록 트리거 함수
CREATE OR REPLACE FUNCTION log_activity()
RETURNS TRIGGER AS $$
DECLARE
  v_user_name TEXT;
  v_action TEXT;
  v_title TEXT;
  v_details JSONB;
  v_uid UUID;
  v_parent_title TEXT;
BEGIN
  v_uid := auth.uid();

  -- 사용자 이름 조회
  SELECT full_name INTO v_user_name
  FROM public.profiles WHERE id = v_uid;

  IF TG_OP = 'INSERT' THEN
    v_action := 'create';
    -- title 컬럼이 있는 테이블용
    IF TG_TABLE_NAME IN ('tasks', 'projects', 'meetings', 'memos') THEN
      v_title := NEW.title;
    ELSIF TG_TABLE_NAME = 'meeting_timeline' THEN
      v_title := NEW.label;
    ELSE
      v_title := '';
    END IF;

    v_details := jsonb_build_object('title', v_title);

    -- 연계업무: 부모 업무 제목 조회 (중첩 IF로 분리 - short-circuit 미보장 대응)
    IF TG_TABLE_NAME = 'tasks' THEN
      IF NEW.parent_task_id IS NOT NULL THEN
        SELECT title INTO v_parent_title
        FROM public.tasks WHERE id = NEW.parent_task_id;
        IF v_parent_title IS NOT NULL THEN
          v_details := v_details || jsonb_build_object('parent_task_title', v_parent_title);
        END IF;
      END IF;
    END IF;

    INSERT INTO public.activity_logs
      (user_id, user_name, action, entity_type, entity_id, entity_title, details)
    VALUES
      (v_uid, v_user_name, v_action, TG_TABLE_NAME, NEW.id, v_title, v_details);
    RETURN NEW;

  ELSIF TG_OP = 'UPDATE' THEN
    v_action := 'update';

    IF TG_TABLE_NAME IN ('tasks', 'projects', 'meetings', 'memos') THEN
      v_title := NEW.title;
    ELSIF TG_TABLE_NAME = 'meeting_timeline' THEN
      v_title := NEW.label;
    ELSE
      v_title := '';
    END IF;

    -- 상태 변경 감지 (tasks, projects, meetings)
    IF TG_TABLE_NAME IN ('tasks', 'projects', 'meetings') THEN
      IF OLD.status IS DISTINCT FROM NEW.status THEN
        IF NEW.status = 'completed' THEN
          v_action := 'complete';
        END IF;
        v_details := jsonb_build_object(
          'field', 'status',
          'old_value', OLD.status,
          'new_value', NEW.status
        );
      ELSE
        v_details := jsonb_build_object('title', v_title);
      END IF;
    ELSIF TG_TABLE_NAME = 'meeting_timeline' THEN
      IF OLD.is_completed IS DISTINCT FROM NEW.is_completed THEN
        v_action := CASE WHEN NEW.is_completed THEN 'complete' ELSE 'update' END;
        v_details := jsonb_build_object(
          'field', 'is_completed',
          'old_value', OLD.is_completed,
          'new_value', NEW.is_completed
        );
      ELSE
        v_details := jsonb_build_object('title', v_title);
      END IF;
    ELSE
      v_details := jsonb_build_object('title', v_title);
    END IF;

    -- 연계업무: 부모 업무 제목 조회 (중첩 IF로 분리 - short-circuit 미보장 대응)
    IF TG_TABLE_NAME = 'tasks' THEN
      IF NEW.parent_task_id IS NOT NULL THEN
        SELECT title INTO v_parent_title
        FROM public.tasks WHERE id = NEW.parent_task_id;
        IF v_parent_title IS NOT NULL THEN
          v_details := v_details || jsonb_build_object('parent_task_title', v_parent_title);
        END IF;
      END IF;
    END IF;

    -- updated_at만 변경된 경우는 기록하지 않음
    IF TG_TABLE_NAME IN ('tasks', 'projects', 'meetings', 'memos') THEN
      IF OLD.title = NEW.title
        AND (OLD.status IS NOT DISTINCT FROM NEW.status)
        AND (OLD.description IS NOT DISTINCT FROM NEW.description) THEN
        -- title, status, description 모두 같으면 트리거 자동 업데이트일 수 있으므로 스킵
        RETURN NEW;
      END IF;
    END IF;

    INSERT INTO public.activity_logs
      (user_id, user_name, action, entity_type, entity_id, entity_title, details)
    VALUES
      (v_uid, v_user_name, v_action, TG_TABLE_NAME, NEW.id, v_title, v_details);
    RETURN NEW;

  ELSIF TG_OP = 'DELETE' THEN
    v_action := 'delete';
    IF TG_TABLE_NAME IN ('tasks', 'projects', 'meetings', 'memos') THEN
      v_title := OLD.title;
    ELSIF TG_TABLE_NAME = 'meeting_timeline' THEN
      v_title := OLD.label;
    ELSE
      v_title := '';
    END IF;

    v_details := NULL;

    -- 연계업무: 부모 업무 제목 조회 (중첩 IF로 분리 - short-circuit 미보장 대응)
    IF TG_TABLE_NAME = 'tasks' THEN
      IF OLD.parent_task_id IS NOT NULL THEN
        SELECT title INTO v_parent_title
        FROM public.tasks WHERE id = OLD.parent_task_id;
        IF v_parent_title IS NOT NULL THEN
          v_details := jsonb_build_object('parent_task_title', v_parent_title);
        END IF;
      END IF;
    END IF;

    INSERT INTO public.activity_logs
      (user_id, user_name, action, entity_type, entity_id, entity_title, details)
    VALUES
      (v_uid, v_user_name, v_action, TG_TABLE_NAME, OLD.id, v_title, v_details);
    RETURN OLD;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. 각 테이블에 트리거 연결
-- tasks
DROP TRIGGER IF EXISTS trg_activity_tasks ON public.tasks;
CREATE TRIGGER trg_activity_tasks
  AFTER INSERT OR UPDATE OR DELETE ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION log_activity();

-- projects
DROP TRIGGER IF EXISTS trg_activity_projects ON public.projects;
CREATE TRIGGER trg_activity_projects
  AFTER INSERT OR UPDATE OR DELETE ON public.projects
  FOR EACH ROW EXECUTE FUNCTION log_activity();

-- meetings
DROP TRIGGER IF EXISTS trg_activity_meetings ON public.meetings;
CREATE TRIGGER trg_activity_meetings
  AFTER INSERT OR UPDATE OR DELETE ON public.meetings
  FOR EACH ROW EXECUTE FUNCTION log_activity();

-- memos
DROP TRIGGER IF EXISTS trg_activity_memos ON public.memos;
CREATE TRIGGER trg_activity_memos
  AFTER INSERT OR UPDATE OR DELETE ON public.memos
  FOR EACH ROW EXECUTE FUNCTION log_activity();

-- meeting_timeline
DROP TRIGGER IF EXISTS trg_activity_timeline ON public.meeting_timeline;
CREATE TRIGGER trg_activity_timeline
  AFTER INSERT OR UPDATE OR DELETE ON public.meeting_timeline
  FOR EACH ROW EXECUTE FUNCTION log_activity();
