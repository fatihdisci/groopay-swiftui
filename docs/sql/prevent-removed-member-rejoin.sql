-- Prevent removed real users from rejoining the same group with an invite code.
-- Applies to direct inserts, invite edge functions, and ghost-claim updates.
--
-- Policy:
-- - Removing a real member keeps group_members.user_id and sets is_active=false.
-- - Any later attempt to create/reactivate an active membership for the same
--   group_id + user_id is rejected.
-- - Ghost members (user_id is null) are not affected.

CREATE OR REPLACE FUNCTION prevent_removed_member_rejoin()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND OLD.user_id IS NOT NULL
     AND COALESCE(NEW.is_active, FALSE) IS FALSE
     AND NEW.user_id IS NULL THEN
    NEW.user_id := OLD.user_id;
  END IF;

  IF NEW.user_id IS NULL OR COALESCE(NEW.is_active, FALSE) IS FALSE THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM group_members gm
    WHERE gm.group_id = NEW.group_id
      AND gm.user_id = NEW.user_id
      AND gm.is_active = FALSE
      AND gm.id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
  ) THEN
    RAISE EXCEPTION 'You were removed from this group and cannot rejoin with an invite code.'
      USING ERRCODE = 'P0001';
  END IF;

  IF TG_OP = 'UPDATE'
     AND OLD.user_id IS NOT NULL
     AND OLD.user_id = NEW.user_id
     AND OLD.group_id = NEW.group_id
     AND OLD.is_active = FALSE
     AND NEW.is_active = TRUE THEN
    RAISE EXCEPTION 'You were removed from this group and cannot rejoin with an invite code.'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_removed_member_rejoin ON group_members;

CREATE TRIGGER trg_prevent_removed_member_rejoin
BEFORE INSERT OR UPDATE OF user_id, is_active ON group_members
FOR EACH ROW
EXECUTE FUNCTION prevent_removed_member_rejoin();
