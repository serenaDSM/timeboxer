alter table public.extra_time_requests
  add column client_request_id uuid not null default gen_random_uuid();

alter table public.extra_time_requests
  alter column client_request_id drop default;

with duplicate_pending as (
  select id,
         row_number() over (
           partition by device_id
           order by requested_at desc, id desc
         ) as pending_rank
  from public.extra_time_requests
  where status = 'pending'
)
update public.extra_time_requests as request
set status = 'expired', resolved_at = now()
from duplicate_pending
where request.id = duplicate_pending.id
  and duplicate_pending.pending_rank > 1;

create unique index extra_time_requests_device_client_id_idx
  on public.extra_time_requests(device_id, client_request_id);

create unique index extra_time_requests_one_pending_per_device_idx
  on public.extra_time_requests(device_id)
  where status = 'pending';

alter table public.activity_events
  add constraint activity_events_payload_size
    check (octet_length(payload::text) <= 4096);

-- Decisions must go through the authenticated Edge Function so approval and
-- policy bonus updates stay atomic. Parents retain read-only RLS access.
revoke update on public.extra_time_requests from authenticated;

comment on column public.extra_time_requests.client_request_id is
  'Mac-generated idempotency key; unique per child device.';
