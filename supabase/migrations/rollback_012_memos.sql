-- ============================================
-- ROLLBACK: 012 개인 메모 시스템
-- 주의: 이 파일은 자동 실행되지 않습니다.
-- 롤백이 필요한 경우에만 수동으로 실행하세요.
-- ============================================

DROP POLICY IF EXISTS "memos_select" ON public.memos;
DROP POLICY IF EXISTS "memos_insert" ON public.memos;
DROP POLICY IF EXISTS "memos_update" ON public.memos;
DROP POLICY IF EXISTS "memos_delete" ON public.memos;

DROP TRIGGER IF EXISTS set_memos_updated_at ON public.memos;

DROP INDEX IF EXISTS idx_memos_user_id;
DROP INDEX IF EXISTS idx_memos_user_status;
DROP INDEX IF EXISTS idx_memos_user_pinned;

DROP TABLE IF EXISTS public.memos;
