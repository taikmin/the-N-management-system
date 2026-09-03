-- ============================================================
-- Hotel Migration 002: departments 테이블 + 기본 5개 부서 seed
-- ============================================================

-- 1. departments 테이블 생성
CREATE TABLE IF NOT EXISTS public.departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  color TEXT DEFAULT '#0ABAB5',  -- UI 표시용 (기본: Tiffany Blue)
  lead_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_departments_sort_order ON public.departments(sort_order);

-- 2. profiles.department_id에 FK 추가
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_department_id_fkey
  FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;

-- 3. 기본 부서 5개 seed (관리자가 이후 자유롭게 수정/추가 가능)
INSERT INTO public.departments (name, description, color, sort_order)
VALUES
  ('프론트 데스크', '체크인/체크아웃, 게스트 응대', '#0ABAB5', 1),
  ('하우스키핑',   '객실 청소·정비, 어메니티 관리', '#4CAF50', 2),
  ('F&B',        '식음료 서비스, 레스토랑·바 운영', '#FF9800', 3),
  ('시설/유지보수', '건물·설비 유지보수, 안전 관리', '#795548', 4),
  ('경영지원',    '재무·인사·구매 등 백오피스', '#9E9E9E', 5)
ON CONFLICT (name) DO NOTHING;

-- 4. updated_at 자동 갱신 트리거
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS departments_updated_at ON public.departments;
CREATE TRIGGER departments_updated_at
  BEFORE UPDATE ON public.departments
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================
-- ROLLBACK
-- ============================================================
-- ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_department_id_fkey;
-- DROP TABLE IF EXISTS public.departments CASCADE;
