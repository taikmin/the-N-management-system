-- ============================================
-- 009: 파일 첨부 시스템
-- file_attachments 테이블 + Storage 버킷 정책
-- ============================================

-- 파일 첨부 테이블
CREATE TABLE IF NOT EXISTS public.file_attachments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  file_name TEXT NOT NULL,
  file_size BIGINT NOT NULL DEFAULT 0,
  mime_type TEXT,
  storage_path TEXT NOT NULL,
  bucket_name TEXT NOT NULL,
  entity_type TEXT NOT NULL CHECK (entity_type IN ('project', 'task', 'daily_log', 'meeting', 'meeting_document')),
  entity_id UUID NOT NULL,
  uploader_id UUID NOT NULL REFERENCES auth.users(id),
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_file_attachments_entity
  ON public.file_attachments(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_file_attachments_uploader
  ON public.file_attachments(uploader_id);

-- RLS 활성화
ALTER TABLE public.file_attachments ENABLE ROW LEVEL SECURITY;

-- RLS 정책
CREATE POLICY "file_attachments_select"
  ON public.file_attachments FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    OR is_admin()
  );

CREATE POLICY "file_attachments_insert"
  ON public.file_attachments FOR INSERT
  WITH CHECK (
    auth.uid() = uploader_id
  );

CREATE POLICY "file_attachments_update"
  ON public.file_attachments FOR UPDATE
  USING (
    auth.uid() = uploader_id
    OR is_admin()
  );

CREATE POLICY "file_attachments_delete"
  ON public.file_attachments FOR DELETE
  USING (
    auth.uid() = uploader_id
    OR is_admin()
  );

-- updated_at 트리거
CREATE TRIGGER set_file_attachments_updated_at
  BEFORE UPDATE ON public.file_attachments
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

-- ============================================
-- Storage 버킷 생성 (Supabase Dashboard에서 수동 생성 필요)
-- 아래는 참고용 SQL (supabase CLI 또는 Dashboard에서 실행)
-- ============================================
-- INSERT INTO storage.buckets (id, name, public)
-- VALUES
--   ('project-files', 'project-files', false),
--   ('task-files', 'task-files', false),
--   ('meeting-files', 'meeting-files', false)
-- ON CONFLICT (id) DO NOTHING;

-- Storage RLS 정책 (각 버킷에 대해)
-- 인증된 사용자는 업로드/다운로드 가능, 본인 파일만 삭제 가능
-- Dashboard > Storage > Policies에서 설정 권장
