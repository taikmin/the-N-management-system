-- ============================================
-- ROLLBACK: 009 파일 첨부 시스템
-- 주의: 이 파일은 자동 실행되지 않습니다.
-- 롤백이 필요한 경우에만 수동으로 실행하세요.
-- ============================================

-- RLS 정책 삭제
DROP POLICY IF EXISTS "file_attachments_select" ON public.file_attachments;
DROP POLICY IF EXISTS "file_attachments_insert" ON public.file_attachments;
DROP POLICY IF EXISTS "file_attachments_update" ON public.file_attachments;
DROP POLICY IF EXISTS "file_attachments_delete" ON public.file_attachments;

-- 트리거 삭제
DROP TRIGGER IF EXISTS set_file_attachments_updated_at ON public.file_attachments;

-- 인덱스 삭제
DROP INDEX IF EXISTS idx_file_attachments_entity;
DROP INDEX IF EXISTS idx_file_attachments_uploader;

-- 테이블 삭제
DROP TABLE IF EXISTS public.file_attachments;

-- Storage 버킷 삭제 (수동 실행 필요)
-- DELETE FROM storage.buckets WHERE id IN ('project-files', 'task-files', 'meeting-files');
