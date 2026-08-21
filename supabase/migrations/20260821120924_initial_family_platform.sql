-- TimeBoxer family platform v1.
-- Parent clients use Supabase Auth. Child Macs never receive a parent JWT or a
-- service-role key; they authenticate to a dedicated Edge Function with a
-- per-device credential whose digest is stored in the private schema.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.account_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  locale text not null default 'en-NZ',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.families (
  id uuid primary key default gen_random_uuid(),
  display_name text not null default 'My family' check (char_length(display_name) between 1 and 80),
  timezone text not null default 'Pacific/Auckland',
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.family_members (
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'guardian')),
  created_at timestamptz not null default now(),
  primary key (family_id, user_id)
);

create table public.children (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 80),
  birth_year integer check (birth_year between 2000 and 2100),
  bedtime_local time not null default '20:30',
  timezone text not null default 'Pacific/Auckland',
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.child_devices (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  installation_id uuid not null unique,
  platform text not null check (platform in ('macos')),
  display_name text not null check (char_length(display_name) between 1 and 120),
  app_version text,
  os_version text,
  last_seen_at timestamptz,
  paired_at timestamptz not null default now(),
  revoked_at timestamptz,
  acknowledged_policy_revision bigint not null default 0 check (acknowledged_policy_revision >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.family_policies (
  child_id uuid primary key references public.children(id) on delete cascade,
  revision bigint not null default 1 check (revision > 0),
  document jsonb not null default jsonb_build_object(
    'version', 1,
    'dayPlans', jsonb_build_object(
      'school', jsonb_build_object('baseMinutes', 20, 'earnCapMinutes', 10),
      'weekend', jsonb_build_object('baseMinutes', 30, 'earnCapMinutes', 20),
      'holiday', jsonb_build_object('baseMinutes', 40, 'earnCapMinutes', 20)
    ),
    'maxSessionMinutes', 20,
    'cooldownMinutes', 10,
    'cooldownTriggerMinutes', 20,
    'bedtimeBufferMinutes', 60,
    'earnTasks', jsonb_build_array(),
    'protectedApplications', jsonb_build_array(),
    'protectedDomains', jsonb_build_array()
  ) check (jsonb_typeof(document) = 'object'),
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

create table public.activity_events (
  id uuid primary key default gen_random_uuid(),
  client_event_id uuid not null,
  child_id uuid not null references public.children(id) on delete cascade,
  device_id uuid not null references public.child_devices(id) on delete cascade,
  event_type text not null check (event_type in (
    'device_online', 'device_offline', 'app_blocked', 'website_blocked',
    'earn_started', 'earn_completed', 'earn_stopped', 'play_started',
    'play_ended', 'request_created', 'request_resolved', 'policy_applied'
  )),
  severity text not null default 'info' check (severity in ('info', 'action', 'violation')),
  subject_label text check (subject_label is null or char_length(subject_label) <= 160),
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  occurred_at timestamptz not null,
  received_at timestamptz not null default now(),
  unique (device_id, client_event_id)
);

create table public.extra_time_requests (
  id uuid primary key default gen_random_uuid(),
  child_id uuid not null references public.children(id) on delete cascade,
  device_id uuid not null references public.child_devices(id) on delete cascade,
  requested_minutes integer not null check (requested_minutes between 1 and 60),
  status text not null default 'pending' check (status in ('pending', 'approved', 'declined', 'expired')),
  requested_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id),
  constraint resolved_request_fields check (
    (status = 'pending' and resolved_at is null and resolved_by is null)
    or (status <> 'pending' and resolved_at is not null)
  )
);

create table public.family_entitlements (
  family_id uuid primary key references public.families(id) on delete cascade,
  plan text not null default 'pilot' check (plan in ('pilot', 'family_monthly', 'family_yearly')),
  status text not null default 'active' check (status in ('active', 'grace_period', 'expired', 'revoked')),
  valid_until timestamptz,
  updated_at timestamptz not null default now()
);

create table private.device_credentials (
  device_id uuid primary key references public.child_devices(id) on delete cascade,
  public_key bytea not null,
  secret_digest bytea not null unique,
  rotated_at timestamptz not null default now(),
  revoked_at timestamptz
);

create table private.device_pairing_sessions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  child_id uuid not null references public.children(id) on delete cascade,
  code_digest bytea not null unique,
  created_by uuid not null references auth.users(id),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint pairing_expiry_after_creation check (expires_at > created_at)
);

create table private.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  app_bundle_id text not null,
  environment text not null check (environment in ('sandbox', 'production')),
  token_ciphertext bytea not null,
  last_registered_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (user_id, app_bundle_id, environment, token_ciphertext)
);

create index family_members_user_id_idx on public.family_members(user_id);
create index families_created_by_idx on public.families(created_by);
create index children_family_id_idx on public.children(family_id);
create index child_devices_child_id_idx on public.child_devices(child_id);
create index child_devices_last_seen_at_idx on public.child_devices(last_seen_at desc);
create index family_policies_updated_by_idx on public.family_policies(updated_by) where updated_by is not null;
create index activity_events_child_occurred_idx on public.activity_events(child_id, occurred_at desc);
create index activity_events_device_received_idx on public.activity_events(device_id, received_at desc);
create index extra_time_requests_child_status_idx on public.extra_time_requests(child_id, status, requested_at desc);
create index extra_time_requests_device_id_idx on public.extra_time_requests(device_id);
create index extra_time_requests_resolved_by_idx on public.extra_time_requests(resolved_by) where resolved_by is not null;
create index pairing_sessions_family_id_idx on private.device_pairing_sessions(family_id);
create index pairing_sessions_child_id_idx on private.device_pairing_sessions(child_id);
create index pairing_sessions_created_by_idx on private.device_pairing_sessions(created_by);
create index pairing_sessions_expiry_idx on private.device_pairing_sessions(expires_at) where consumed_at is null;
create index push_tokens_user_active_idx on private.push_tokens(user_id) where revoked_at is null;

create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger account_profiles_set_updated_at before update on public.account_profiles
for each row execute function private.set_updated_at();
create trigger families_set_updated_at before update on public.families
for each row execute function private.set_updated_at();
create trigger children_set_updated_at before update on public.children
for each row execute function private.set_updated_at();
create trigger child_devices_set_updated_at before update on public.child_devices
for each row execute function private.set_updated_at();
create trigger family_entitlements_set_updated_at before update on public.family_entitlements
for each row execute function private.set_updated_at();

alter table public.account_profiles enable row level security;
alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.children enable row level security;
alter table public.child_devices enable row level security;
alter table public.family_policies enable row level security;
alter table public.activity_events enable row level security;
alter table public.extra_time_requests enable row level security;
alter table public.family_entitlements enable row level security;
alter table private.device_credentials enable row level security;
alter table private.device_pairing_sessions enable row level security;
alter table private.push_tokens enable row level security;

create policy "account owners can read their profile"
on public.account_profiles for select to authenticated
using ((select auth.uid()) is not null and (select auth.uid()) = id);

create policy "account owners can create their profile"
on public.account_profiles for insert to authenticated
with check ((select auth.uid()) is not null and (select auth.uid()) = id);

create policy "account owners can update their profile"
on public.account_profiles for update to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy "members can read their families"
on public.families for select to authenticated
using (
  created_by = (select auth.uid())
  or exists (
    select 1 from public.family_members membership
    where membership.family_id = families.id
      and membership.user_id = (select auth.uid())
  )
);

create policy "parents can create a family"
on public.families for insert to authenticated
with check ((select auth.uid()) is not null and created_by = (select auth.uid()));

create policy "owners can update their family"
on public.families for update to authenticated
using (exists (
  select 1 from public.family_members membership
  where membership.family_id = families.id
    and membership.user_id = (select auth.uid())
    and membership.role = 'owner'
))
with check (exists (
  select 1 from public.family_members membership
  where membership.family_id = families.id
    and membership.user_id = (select auth.uid())
    and membership.role = 'owner'
));

create policy "members can read their own membership"
on public.family_members for select to authenticated
using ((select auth.uid()) is not null and user_id = (select auth.uid()));

create policy "family creators can claim owner membership"
on public.family_members for insert to authenticated
with check (
  user_id = (select auth.uid())
  and role = 'owner'
  and exists (
    select 1 from public.families family
    where family.id = family_members.family_id
      and family.created_by = (select auth.uid())
  )
);

create policy "members can read children in their family"
on public.children for select to authenticated
using (exists (
  select 1 from public.family_members membership
  where membership.family_id = children.family_id
    and membership.user_id = (select auth.uid())
));

create policy "members can add children to their family"
on public.children for insert to authenticated
with check (exists (
  select 1 from public.family_members membership
  where membership.family_id = children.family_id
    and membership.user_id = (select auth.uid())
));

create policy "members can update children in their family"
on public.children for update to authenticated
using (exists (
  select 1 from public.family_members membership
  where membership.family_id = children.family_id
    and membership.user_id = (select auth.uid())
))
with check (exists (
  select 1 from public.family_members membership
  where membership.family_id = children.family_id
    and membership.user_id = (select auth.uid())
));

create policy "members can read paired child devices"
on public.child_devices for select to authenticated
using (exists (
  select 1
  from public.children child
  join public.family_members membership on membership.family_id = child.family_id
  where child.id = child_devices.child_id
    and membership.user_id = (select auth.uid())
));

create policy "members can read family policies"
on public.family_policies for select to authenticated
using (exists (
  select 1
  from public.children child
  join public.family_members membership on membership.family_id = child.family_id
  where child.id = family_policies.child_id
    and membership.user_id = (select auth.uid())
));

create policy "members can read child activity"
on public.activity_events for select to authenticated
using (exists (
  select 1
  from public.children child
  join public.family_members membership on membership.family_id = child.family_id
  where child.id = activity_events.child_id
    and membership.user_id = (select auth.uid())
));

create policy "members can read extra time requests"
on public.extra_time_requests for select to authenticated
using (exists (
  select 1
  from public.children child
  join public.family_members membership on membership.family_id = child.family_id
  where child.id = extra_time_requests.child_id
    and membership.user_id = (select auth.uid())
));

create policy "members can read family entitlement"
on public.family_entitlements for select to authenticated
using (exists (
  select 1 from public.family_members membership
  where membership.family_id = family_entitlements.family_id
    and membership.user_id = (select auth.uid())
));

revoke all on public.account_profiles from anon, authenticated;
revoke all on public.families from anon, authenticated;
revoke all on public.family_members from anon, authenticated;
revoke all on public.children from anon, authenticated;
revoke all on public.child_devices from anon, authenticated;
revoke all on public.family_policies from anon, authenticated;
revoke all on public.activity_events from anon, authenticated;
revoke all on public.extra_time_requests from anon, authenticated;
revoke all on public.family_entitlements from anon, authenticated;
revoke all on private.device_credentials from public, anon, authenticated;
revoke all on private.device_pairing_sessions from public, anon, authenticated;
revoke all on private.push_tokens from public, anon, authenticated;

grant select, insert, update (display_name, locale) on public.account_profiles to authenticated;
grant select, insert, update (display_name, timezone) on public.families to authenticated;
grant select, insert on public.family_members to authenticated;
grant select, insert, update (display_name, birth_year, bedtime_local, timezone, archived_at) on public.children to authenticated;
grant select on public.child_devices to authenticated;
grant select on public.family_policies to authenticated;
grant select on public.activity_events to authenticated;
grant select on public.extra_time_requests to authenticated;
grant select on public.family_entitlements to authenticated;

grant select, insert, update, delete on public.account_profiles to service_role;
grant select, insert, update, delete on public.families to service_role;
grant select, insert, update, delete on public.family_members to service_role;
grant select, insert, update, delete on public.children to service_role;
grant select, insert, update, delete on public.child_devices to service_role;
grant select, insert, update, delete on public.family_policies to service_role;
grant select, insert, update, delete on public.activity_events to service_role;
grant select, insert, update, delete on public.extra_time_requests to service_role;
grant select, insert, update, delete on public.family_entitlements to service_role;
grant usage on schema private to service_role;
grant select, insert, update, delete on private.device_credentials to service_role;
grant select, insert, update, delete on private.device_pairing_sessions to service_role;
grant select, insert, update, delete on private.push_tokens to service_role;
grant execute on function private.set_updated_at() to service_role;
revoke execute on function private.set_updated_at() from public, anon, authenticated;
