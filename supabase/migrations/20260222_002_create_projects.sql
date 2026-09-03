-- ============================================================
-- Migration: projects 테이블 (R&D 과제)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.projects (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  project_number TEXT,                          -- 과제번호 (예: 2026-R-001)
  description TEXT,
  status TEXT NOT NULL DEFAULT 'planning'
    CHECK (status IN ('planning', 'active', 'completed', 'on_hold', 'cancelled')),
  start_date DATE,
  end_date DATE,
  lead_institution TEXT DEFAULT '한국기계연구원', -- 주관기관
  co_institutions TEXT[] DEFAULT '{}',           -- 공동연구기관 목록
  total_budget BIGINT DEFAULT 0,                 -- 총연구비 (원)
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_projects_owner_id ON public.projects(owner_id);
CREATE INDEX idx_projects_status ON public.projects(status);

CREATE TRIGGER projects_updated_at
  BEFORE UPDATE ON public.projects
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- 과제 멤버 테이블
CREATE TABLE IF NOT EXISTS public.project_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member'
    CHECK (role IN ('owner', 'admin', 'member', 'viewer')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(project_id, user_id)
);

CREATE INDEX idx_project_members_user_id ON public.project_members(user_id);
CREATE INDEX idx_project_members_project_id ON public.project_members(project_id);

-- RLS
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_members ENABLE ROW LEVEL SECURITY;

-- 과제: 멤버이거나 owner인 경우 조회 가능
CREATE POLICY "Project members can view projects"
  ON public.projects FOR SELECT
  USING (
    owner_id = auth.uid()
    OR id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid()
    )
  );

-- 과제 생성: 인증된 사용자
CREATE POLICY "Authenticated users can create projects"
  ON public.projects FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

-- 과제 수정: owner 또는 admin
CREATE POLICY "Project owner/admin can update"
  ON public.projects FOR UPDATE
  USING (
    owner_id = auth.uid()
    OR id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid() AND role IN ('owner', 'admin')
    )
  );

-- 과제 삭제: owner만
CREATE POLICY "Project owner can delete"
  ON public.projects FOR DELETE
  USING (owner_id = auth.uid());

-- 멤버: 같은 프로젝트 멤버만 조회
CREATE POLICY "Project members can view members"
  ON public.project_members FOR SELECT
  USING (
    project_id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid()
    )
    OR project_id IN (
      SELECT id FROM public.projects
      WHERE owner_id = auth.uid()
    )
  );

-- 멤버 추가: owner/admin
CREATE POLICY "Project owner/admin can add members"
  ON public.project_members FOR INSERT
  WITH CHECK (
    project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
    OR project_id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid() AND role IN ('owner', 'admin')
    )
  );

-- 멤버 삭제: owner/admin 또는 본인 탈퇴
CREATE POLICY "Project owner/admin can remove members"
  ON public.project_members FOR DELETE
  USING (
    user_id = auth.uid()
    OR project_id IN (
      SELECT id FROM public.projects WHERE owner_id = auth.uid()
    )
    OR project_id IN (
      SELECT project_id FROM public.project_members
      WHERE user_id = auth.uid() AND role IN ('owner', 'admin')
    )
  );
