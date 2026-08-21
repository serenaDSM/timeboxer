grant insert (child_id, updated_by) on public.family_policies to authenticated;

create policy "members can create the initial child policy"
on public.family_policies for insert to authenticated
with check (
  updated_by = (select auth.uid())
  and exists (
    select 1 from public.children child
    where child.id = family_policies.child_id
      and (select private.is_family_member(child.family_id))
  )
);

grant update (status, resolved_at, resolved_by)
on public.extra_time_requests to authenticated;

create policy "members can resolve pending extra time requests"
on public.extra_time_requests for update to authenticated
using (
  status = 'pending'
  and exists (
    select 1 from public.children child
    where child.id = extra_time_requests.child_id
      and (select private.is_family_member(child.family_id))
  )
)
with check (
  status in ('approved', 'declined')
  and resolved_at is not null
  and resolved_by = (select auth.uid())
  and exists (
    select 1 from public.children child
    where child.id = extra_time_requests.child_id
      and (select private.is_family_member(child.family_id))
  )
);
