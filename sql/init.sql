-- ==========================================
-- TODOS TABLE SETUP (Supabase Safe Version)
-- ==========================================

-- Create table
CREATE TABLE IF NOT EXISTS public.todos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  deadline TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for efficient user filtering
CREATE INDEX IF NOT EXISTS idx_todos_user_id ON public.todos(user_id);

-- Enable Row Level Security
ALTER TABLE public.todos ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- RLS POLICIES
-- ==========================================

-- Drop existing RLS policies to ensure clean recreation
DROP POLICY IF EXISTS "Users can view own todos" ON public.todos;
DROP POLICY IF EXISTS "Users can insert own todos" ON public.todos;
DROP POLICY IF EXISTS "Users can update own todos" ON public.todos;
DROP POLICY IF EXISTS "Users can delete own todos" ON public.todos;

-- View policy
CREATE POLICY "Users can view own todos" ON public.todos
  FOR SELECT
  USING ((SELECT auth.uid()) = user_id);

-- Insert policy
CREATE POLICY "Users can insert own todos" ON public.todos
  FOR INSERT
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- Update policy
CREATE POLICY "Users can update own todos" ON public.todos
  FOR UPDATE
  USING ((SELECT auth.uid()) = user_id);

-- Delete policy
CREATE POLICY "Users can delete own todos" ON public.todos
  FOR DELETE
  USING ((SELECT auth.uid()) = user_id);

-- ==========================================
-- PERMISSIONS
-- ==========================================

-- Grant minimal permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.todos TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Revoke all permissions from anon users
REVOKE ALL ON public.todos FROM anon;

-- ==========================================
-- UPDATED_AT TRIGGER FUNCTION (FIXED)
-- ==========================================

-- Drop existing trigger and function if they exist
DROP TRIGGER IF EXISTS update_todos_updated_at ON public.todos;
DROP FUNCTION IF EXISTS public.update_updated_at_column();

-- Secure function for automatically updating 'updated_at'
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Create trigger for automatic updated_at refresh
CREATE TRIGGER update_todos_updated_at
BEFORE UPDATE ON public.todos
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

