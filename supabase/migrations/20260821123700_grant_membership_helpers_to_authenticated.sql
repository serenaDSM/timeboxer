-- RLS policies execute with the requesting database role. Grant only function
-- execution; the private schema itself remains unavailable to the Data API.
grant execute on function private.is_family_member(uuid) to authenticated;
grant execute on function private.is_family_owner(uuid) to authenticated;
