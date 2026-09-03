-- ============================================================
-- Hotel Migration 003: tasks 테이블 재정의
-- ============================================================
-- 기존 R&D 필드 삭제, 호텔 도메인 필드 신규
-- 기존 데이터(테스트용 5건)는 스키마 변경 전 백업 권장
-- ============================================================

-- 참고: 기존 tasks 데이터는 R&D 스키마 기반이므로 호텔 앱과 무관.
-- 필요 시 실행 전 백업:
--   CREATE TABLE tasks_backup_rd AS SELECT * FROM tasks;

-- 1. 기존 R&D 특화 필드 삭제 (CASCADE로 관련 뷰/제약 함께)
ALTER TABLE public.tasks DROP COLUMN IF EXISTS plan_type CASCADE;
ALTER TABLE public.tasks DROP COLUMN IF EXISTS parent_task_id CASCADE;
ALTER TABLE public.tasks DROP COLUMN IF EXISTS color_tag CASCADE;
ALTER TABLE public.tasks DROP COLUMN IF EXISTS actual_start CASCADE;
ALTER TABLE public.tasks DROP COLUMN IF EXISTS actual_end CASCADE;
ALTER TABLE public.tasks DROP COLUMN IF EXISTS planned_start CASCADE;
ALTER TABLE public.tasks DROP COLUMN IF EXISTS planned_end CASCADE;
ALTER TABLE public.tasks DROP COLUMN IF EXISTS order_index CASCADE;
ALTER TABLE public.tasks DROP COLUMN IF EXISTS project_id CASCADE;

-- 2. 신규 컬럼 추가
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS department_id UUID
  REFERENCES public.departments(id) ON DELETE SET NULL;

ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS assigner_id UUID
  REFERENCES public.profiles(id) ON DELETE SET NULL;

-- assignee_id는 기존에 이미 있음, FK만 재확인
-- (기존에 이미 profiles를 참조하고 있음)

ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS due_date DATE;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS due_time TIME;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS completion_note TEXT;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS delay_reason TEXT;

ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS recurrence_pattern TEXT;
-- 형식 예: 'daily', 'weekly:mon,wed,fri', 'monthly:1,15'
-- NULL이면 일회성 업무

ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS recurrence_template_id UUID
  REFERENCES public.tasks(id) ON DELETE SET NULL;
-- 이 필드가 있으면 이 태스크는 템플릿에서 생성된 인스턴스

-- 3. status enum 재설정 (기존 값 매핑)
UPDATE public.tasks SET status = 'assigned'    WHERE status IN ('planned', 'blocked');
UPDATE public.tasks SET status = 'in_progress' WHERE status = 'in_progress';
UPDATE public.tasks SET status = 'completed'   WHERE status = 'completed';
UPDATE public.tasks SET status = 'delayed'     WHERE status = 'delayed';

ALTER TABLE public.tasks DROP CONSTRAINT IF EXISTS tasks_status_check;
ALTER TABLE public.tasks
  ADD CONSTRAINT tasks_status_check
  CHECK (status IN ('assigned', 'in_progress', 'completed', 'incomplete', 'delayed'));

-- 4. priority 재설정
UPDATE public.tasks SET priority = 'normal' WHERE priority = 'medium';
-- low/high/urgent은 그대로

ALTER TABLE public.tasks DROP CONSTRAINT IF EXISTS tasks_priority_check;
ALTER TABLE public.tasks
  ADD CONSTRAINT tasks_priority_check
  CHECK (priority IN ('low', 'normal', 'high', 'urgent'));

ALTER TABLE public.tasks ALTER COLUMN priority SET DEFAULT 'normal';

-- 5. incomplete/delayed 시 delay_reason 필수 CHECK
ALTER TABLE public.tasks DROP CONSTRAINT IF EXISTS tasks_delay_reason_required;
ALTER TABLE public.tasks
  ADD CONSTRAINT tasks_delay_reason_required
  CHECK (
    (status NOT IN ('incomplete', 'delayed'))
    OR (delay_reason IS NOT NULL AND length(trim(delay_reason)) > 0)
  );

-- 6. 인덱스
CREATE INDEX IF NOT EXISTS idx_tasks_assignee_id ON public.tasks(assignee_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assigner_id ON public.tasks(assigner_id);
CREATE INDEX IF NOT EXISTS idx_tasks_department_id ON public.tasks(department_id);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON public.tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_recurrence_template_id ON public.tasks(recurrence_template_id);

-- 7. 유효성 확인 뷰 (선택, 디버깅용)
-- SELECT status, count(*) FROM public.tasks GROUP BY status;

-- ============================================================
-- ROLLBACK (부분적 — 삭제된 컬럼은 원래 값 복구 불가)
-- ============================================================
-- ALTER TABLE public.tasks DROP CONSTRAINT tasks_delay_reason_required;
-- ALTER TABLE public.tasks DROP CONSTRAINT tasks_priority_check;
-- ALTER TABLE public.tasks DROP CONSTRAINT tasks_status_check;
-- ALTER TABLE public.tasks DROP COLUMN recurrence_template_id;
-- ALTER TABLE public.tasks DROP COLUMN recurrence_pattern;
-- ALTER TABLE public.tasks DROP COLUMN delay_reason;
-- ALTER TABLE public.tasks DROP COLUMN completion_note;
-- ALTER TABLE public.tasks DROP COLUMN completed_at;
-- ALTER TABLE public.tasks DROP COLUMN due_time;
-- ALTER TABLE public.tasks DROP COLUMN due_date;
-- ALTER TABLE public.tasks DROP COLUMN assigner_id;
-- ALTER TABLE public.tasks DROP COLUMN department_id;
