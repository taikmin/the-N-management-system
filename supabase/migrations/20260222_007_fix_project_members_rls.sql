-- ============================================================
-- Fix: project_members 무한 재귀 RLS 수정 (PostgreSQL 42P17)
--
-- 원인: project_members SELECT 정책이 자기 자신을 서브쿼리로 참조
--       → projects/tasks/meetings 등이 project_members 참조 시 무한 재귀
--
-- 핵심: SELECT 정책을 서브쿼리 없이 단순화하여 재귀 체인 차단
--       user_id = auth.uid()  →  서브쿼리 없음  →  재귀 불가능
-- ============================================================

-- 1. 기존 project_members 정책 모두 삭제 (원본 + 이전 수정 시도 포함)
DROP POLICY IF EXISTS "Project members can view members" ON public.project_members;
DROP POLICY IF EXISTS "Project owner/admin can add members" ON public.project_members;
DROP POLICY IF EXISTS "Project owner/admin can remove members" ON public.project_members;
DROP POLICY IF EXISTS "View project members" ON public.project_members;
DROP POLICY IF EXISTS "Add project members" ON public.project_members;
DROP POLICY IF EXISTS "Remove project members" ON public.project_members;

-- 2. SELECT: 단순화 — 본인 멤버십 + 사이트 관리자 (서브쿼리 없음!)
CREATE POLICY "View project members"
  ON public.project_members FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.is_admin()
  );

-- 3. INSERT: 과제 소유자 또는 사이트 관리자
--    (projects 참조하지만 → projects SELECT → project_members SELECT
--     → user_id = auth.uid() 에서 종료. 재귀 없음)
CREATE POLICY "Add project members"
  ON public.project_members FOR INSERT
  WITH CHECK (
    public.is_admin()
    OR project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
  );

-- 4. DELETE: 본인 탈퇴 + 과제 소유자 + 사이트 관리자
CREATE POLICY "Remove project members"
  ON public.project_members FOR DELETE
  USING (
    user_id = auth.uid()
    OR public.is_admin()
    OR project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
  );
