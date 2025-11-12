-- ==========================================
-- TODOS TABLE CLEANUP / DELETE SCRIPT
-- ==========================================

-- Drop trigger first (must come before dropping function or table)
DROP TRIGGER IF EXISTS update_todos_updated_at ON public.todos;

-- Drop the trigger function
DROP FUNCTION IF EXISTS public.update_updated_at_column();

-- Drop RLS policies
DROP POLICY IF EXISTS "Users can view own todos" ON public.todos;
DROP POLICY IF EXISTS "Users can insert own todos" ON public.todos;
DROP POLICY IF EXISTS "Users can update own todos" ON public.todos;
DROP POLICY IF EXISTS "Users can delete own todos" ON public.todos;

-- Disable Row Level Security (optional cleanup)
ALTER TABLE IF EXISTS public.todos DISABLE ROW LEVEL SECURITY;

-- Revoke permissions from roles (cleanup)
REVOKE SELECT, INSERT, UPDATE, DELETE ON public.todos FROM authenticated;
REVOKE USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public FROM authenticated;
REVOKE ALL ON public.todos FROM anon;

-- Drop index
DROP INDEX IF EXISTS public.idx_todos_user_id;

-- Finally, drop the table
DROP TABLE IF EXISTS public.todos CASCADE;

