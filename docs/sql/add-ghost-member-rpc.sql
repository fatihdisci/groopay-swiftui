-- =============================================
-- add_ghost_member RPC
-- Supabase SQL Editor'da çalıştır
-- =============================================
-- Hayalet üye (user_id = NULL) eklemek için SECURITY DEFINER RPC.
-- Sadece grup kurucusu çağırabilir. Doğrudan tablo insert'i
-- RLS tarafından engellendiği için bu RPC üzerinden yapılır.
-- =============================================

CREATE OR REPLACE FUNCTION add_ghost_member(
    p_group_id UUID,
    p_display_name TEXT
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_caller_id UUID;
    v_member_id UUID;
BEGIN
    v_caller_id := auth.uid();

    -- Sadece kurucu hayalet üye ekleyebilir
    IF NOT EXISTS (
        SELECT 1 FROM group_members
        WHERE group_id = p_group_id
          AND user_id = v_caller_id
          AND role = 'founder'
    ) THEN
        RAISE EXCEPTION 'Only the group founder can add ghost members.';
    END IF;

    INSERT INTO group_members (group_id, user_id, display_name, role)
    VALUES (p_group_id, NULL, p_display_name, 'member')
    RETURNING id INTO v_member_id;

    RETURN v_member_id;
END;
$$;
