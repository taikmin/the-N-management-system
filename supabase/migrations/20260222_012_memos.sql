-- ============================================
-- 012: 개인 메모 시스템
--
-- memos 테이블 생성 + RLS (완전 개인 영역)
-- Admin도 타인 메모 접근 불가
--
-- Supabase SQL Editor에서 한번에 실행하세요.
-- ============================================

-- ─── 1. 테이블 생성 ───

CREATE TABLE public.memos (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title       TEXT NOT NULL DEFAULT '',
  content     TEXT DEFAULT '',
  category    TEXT,
  is_pinned   BOOLEAN NOT NULL DEFAULT false,
  priority    TEXT NOT NULL DEFAULT 'none',
  status      TEXT NOT NULL DEFAULT 'active',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── 2. RLS 활성화 ───

ALTER TABLE public.memos ENABLE ROW LEVEL SECURITY;

-- ─── 3. 인덱스 ───

CREATE INDEX idx_memos_user_id
  ON public.memos(user_id);
CREATE INDEX idx_memos_user_status
  ON public.memos(user_id, status);
CREATE INDEX idx_memos_user_pinned
  ON public.memos(user_id, is_pinned DESC, created_at DESC);

-- ─── 4. RLS 정책 (완전 개인 — Admin도 타인 메모 접근 불가) ───

CREATE POLICY "memos_select" ON public.memos
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "memos_insert" ON public.memos
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "memos_update" ON public.memos
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "memos_delete" ON public.memos
  FOR DELETE USING (user_id = auth.uid());

-- ─── 5. updated_at 트리거 ───

CREATE TRIGGER set_memos_updated_at
  BEFORE UPDATE ON public.memos
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();
