-- Resolve circular policy evaluation between families and family_members.
-- These helpers live outside the exposed schema, validate the caller identity,
-- and bypass family_members RLS only for the indexed membership lookup.

create function private.is_family_member(target_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.family_members membership
      where membership.family_id = target_family_id
        and membership.user_id = (select auth.uid())
    );
$$;

create function private.is_family_owner(target_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.family_members membership
      where membership.family_id = target_family_id
        and membership.user_id = (select auth.uid())
        and membership.role = 'owner'
    );
$$;

revoke execute on function private.is_family_member(uuid) from public, anon, authenticated, service_role;
revoke execute on function private.is_family_owner(uuid) from public, anon, authenticated, service_role;

drop policy "members can read their families" on public.families;
create policy "members can read their families"
on public.families for select to authenticated
using (
  created_by = (select auth.uid())
  or (select private.is_family_member(id))
);

drop policy "owners can update their family" on public.families;
create policy "owners can update their family"
on public.families for update to authenticated
using ((select private.is_family_owner(id)))
with check ((select private.is_family_owner(id)));

drop policy "members can read children in their family" on public.children;
create policy "members can read children in their family"
on public.children for select to authenticated
using ((select private.is_family_member(family_id)));

drop policy "members can add children to their family" on public.children;
create policy "members can add children to their family"
on public.children for insert to authenticated
with check ((select private.is_family_member(family_id)));

drop policy "members can update children in their family" on public.children;
create policy "members can update children in their family"
on public.children for update to authenticated
using ((select private.is_family_member(family_id)))
with check ((select private.is_family_member(family_id)));

drop policy "members can read paired child devices" on public.child_devices;
create policy "members can read paired child devices"
on public.child_devices for select to authenticated
using (exists (
  select 1 from public.children child
  where child.id = child_devices.child_id
    and (select private.is_family_member(child.family_id))
));

drop policy "members can read family policies" on public.family_policies;
create policy "members can read family policies"
on public.family_policies for select to authenticated
using (exists (
  select 1 from public.children child
  where child.id = family_policies.child_id
    and (select private.is_family_member(child.family_id))
));

drop policy "members can read child activity" on public.activity_events;
create policy "members can read child activity"
on public.activity_events for select to authenticated
using (exists (
  select 1 from public.children child
  where child.id = activity_events.child_id
    and (select private.is_family_member(child.family_id))
));

drop policy "members can read extra time requests" on public.extra_time_requests;
create policy "members can read extra time requests"
on public.extra_time_requests for select to authenticated
using (exists (
  select 1 from public.children child
  where child.id = extra_time_requests.child_id
    and (select private.is_family_member(child.family_id))
));

drop policy "members can read family entitlement" on public.family_entitlements;
create policy "members can read family entitlement"
on public.family_entitlements for select to authenticated
using ((select private.is_family_member(family_id)));
