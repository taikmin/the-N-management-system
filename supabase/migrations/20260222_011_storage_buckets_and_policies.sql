-- ============================================
-- 011: Supabase Storage 버킷 생성 + RLS 정책
--
-- Supabase SQL Editor에서 한번에 실행하세요.
--
-- 버킷 3개: project-files, task-files, meeting-files
-- 정책: 인증 사용자 업로드/다운로드, 본인 or Admin만 삭제
--
-- 파일 경로 규칙 (file_repository.dart 기준):
--   {entity_type}/{entity_id}/{timestamp}_{filename}
--   예: project/abc-123/1708600000000_report.pdf
-- ============================================

-- ─── 1. 버킷 생성 ───

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('project-files', 'project-files', false, 209715200, NULL),
  ('task-files',    'task-files',    false, 209715200, NULL),
  ('meeting-files', 'meeting-files', false, 209715200, NULL)
ON CONFLICT (id) DO NOTHING;
-- file_size_limit = 200MB (209715200 bytes)
-- allowed_mime_types = NULL → 모든 파일 타입 허용

-- ─── 2. 기존 정책 정리 (재실행 안전) ───

DROP POLICY IF EXISTS "Authenticated users can upload"   ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can download" ON storage.objects;
DROP POLICY IF EXISTS "Owner or admin can update"        ON storage.objects;
DROP POLICY IF EXISTS "Owner or admin can delete"        ON storage.objects;

-- 버킷별 정책도 정리 (혹시 이전에 버킷별로 만들었을 경우)
DROP POLICY IF EXISTS "project-files: upload"   ON storage.objects;
DROP POLICY IF EXISTS "project-files: download" ON storage.objects;
DROP POLICY IF EXISTS "project-files: update"   ON storage.objects;
DROP POLICY IF EXISTS "project-files: delete"   ON storage.objects;
DROP POLICY IF EXISTS "task-files: upload"       ON storage.objects;
DROP POLICY IF EXISTS "task-files: download"     ON storage.objects;
DROP POLICY IF EXISTS "task-files: update"       ON storage.objects;
DROP POLICY IF EXISTS "task-files: delete"       ON storage.objects;
DROP POLICY IF EXISTS "meeting-files: upload"    ON storage.objects;
DROP POLICY IF EXISTS "meeting-files: download"  ON storage.objects;
DROP POLICY IF EXISTS "meeting-files: update"    ON storage.objects;
DROP POLICY IF EXISTS "meeting-files: delete"    ON storage.objects;

-- ─── 3. SELECT (다운로드) ───
-- 인증된 사용자는 3개 버킷의 모든 파일을 다운로드 가능

CREATE POLICY "Authenticated users can download"
  ON storage.objects FOR SELECT
  USING (
    bucket_id IN ('project-files', 'task-files', 'meeting-files')
    AND auth.role() = 'authenticated'
  );

-- ─── 4. INSERT (업로드) ───
-- 인증된 사용자는 3개 버킷에 파일 업로드 가능

CREATE POLICY "Authenticated users can upload"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id IN ('project-files', 'task-files', 'meeting-files')
    AND auth.role() = 'authenticated'
  );

-- ─── 5. UPDATE (덮어쓰기) ───
-- 본인이 업로드한 파일만 덮어쓰기 가능, 또는 Admin

CREATE POLICY "Owner or admin can update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id IN ('project-files', 'task-files', 'meeting-files')
    AND (
      auth.uid()::text = (storage.foldername(name))[1]
      OR (SELECT is_admin FROM public.profiles WHERE id = auth.uid())
      OR owner = auth.uid()
    )
  );

-- ─── 6. DELETE (삭제) ───
-- 본인이 업로드한 파일만 삭제 가능, 또는 Admin
-- owner 컬럼은 Supabase가 업로드 시 자동으로 auth.uid()를 기록

CREATE POLICY "Owner or admin can delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id IN ('project-files', 'task-files', 'meeting-files')
    AND (
      owner = auth.uid()
      OR (SELECT is_admin FROM public.profiles WHERE id = auth.uid())
    )
  );
