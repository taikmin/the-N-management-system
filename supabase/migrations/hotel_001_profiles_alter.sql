-- ============================================================
-- Hotel Migration 001: profiles 테이블 호텔용으로 변경
-- ============================================================
-- 기존 R&D 필드(Zoom, position, department 문자열) 제거
-- 신규: department_id (FK departments), phone
-- role 값: pi/researcher/external_ → ceo/manager/staff 로 매핑
-- ============================================================

-- 1. 기존 데이터 role 값 매핑 (하나뿐인 사용자를 관리자로 가정)
-- pi → manager, researcher → staff, external_ → staff
UPDATE public.profiles SET role = 'manager' WHERE role = 'pi';
UPDATE public.profiles SET role = 'staff'   WHERE role IN ('researcher', 'external_');

-- 2. role CHECK 제약 재설정 (기존 제약이 있다면 삭제 후 재생성)
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('ceo', 'manager', 'staff'));

-- 3. Zoom 관련 필드 삭제 (호텔 앱에서 불필요)
ALTER TABLE public.profiles DROP COLUMN IF EXISTS default_zoom_link;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS default_zoom_id;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS default_zoom_password;

-- 4. R&D 특화 필드 삭제
ALTER TABLE public.profiles DROP COLUMN IF EXISTS position;

-- 5. 신규 필드 추가 (기존 department 문자열은 유지하되 다음 마이그레이션에서 department_id로 이관)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS department_id UUID;
-- FK 제약은 departments 테이블 생성 후 hotel_002에서 추가

-- 6. 기존 department 문자열 컬럼은 마이그레이션 종료 시점에 삭제
-- (호텔 앱은 department_id를 사용, 이전 문자열은 참고용으로 잠시 유지)
-- 삭제는 hotel_002 완료 후 수동으로:
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS department;

-- ============================================================
-- ROLLBACK (참고용)
-- ============================================================
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS phone;
-- ALTER TABLE public.profiles DROP COLUMN IF EXISTS department_id;
-- ALTER TABLE public.profiles ADD COLUMN default_zoom_link TEXT;
-- ALTER TABLE public.profiles ADD COLUMN default_zoom_id TEXT;
-- ALTER TABLE public.profiles ADD COLUMN default_zoom_password TEXT;
-- ALTER TABLE public.profiles ADD COLUMN position TEXT;
-- ALTER TABLE public.profiles DROP CONSTRAINT profiles_role_check;
-- ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check CHECK (role IN ('pi','researcher','external_'));
