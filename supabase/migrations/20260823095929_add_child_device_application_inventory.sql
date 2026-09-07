alter table public.child_devices
  add column application_inventory jsonb not null default '[]'::jsonb,
  add column application_inventory_scanned_at timestamptz,
  add constraint child_devices_application_inventory_is_array
    check (
      jsonb_typeof(application_inventory) = 'array'
      and jsonb_array_length(application_inventory) <= 500
    );

comment on column public.child_devices.application_inventory is
  'Privacy-minimised Mac app snapshot: bundle identifier, display name, category and recommendation only.';

comment on column public.child_devices.application_inventory_scanned_at is
  'Server receipt time for the latest validated Mac application inventory.';

update public.family_policies
set
  document = jsonb_set(
    jsonb_set(
      document,
      '{protectedApplications}',
      case
        when coalesce(document -> 'protectedApplications', '[]'::jsonb) = '[]'::jsonb
          then jsonb_build_array(
            'com.apple.TV',
            'com.bilibili.bilibiliPC',
            'com.iqiyi.player',
            'com.mgtv.pcclientx',
            'com.valvesoftware.steam',
            'com.roblox.Roblox',
            'com.mojang.minecraftlauncher',
            'com.tencent.tenvideo'
          )
        else document -> 'protectedApplications'
      end,
      true
    ),
    '{protectedDomains}',
    case
      when coalesce(document -> 'protectedDomains', '[]'::jsonb) = '[]'::jsonb
        then jsonb_build_array(
          'youtube.com', 'tiktok.com', 'twitch.tv', 'netflix.com', 'disneyplus.com',
          'bilibili.com', 'iqiyi.com', 'v.qq.com', 'mgtv.com', 'youku.com',
          'roblox.com', 'poki.com', 'crazygames.com', 'miniclip.com', 'now.gg'
        )
      else document -> 'protectedDomains'
    end,
    true
  ),
  revision = revision + 1,
  updated_at = now()
where coalesce(document -> 'protectedApplications', '[]'::jsonb) = '[]'::jsonb
   or coalesce(document -> 'protectedDomains', '[]'::jsonb) = '[]'::jsonb;

alter table public.family_policies
  alter column document set default jsonb_build_object(
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
    'protectedApplications', jsonb_build_array(
      'com.apple.TV',
      'com.bilibili.bilibiliPC',
      'com.iqiyi.player',
      'com.mgtv.pcclientx',
      'com.valvesoftware.steam',
      'com.roblox.Roblox',
      'com.mojang.minecraftlauncher',
      'com.tencent.tenvideo'
    ),
    'protectedDomains', jsonb_build_array(
      'youtube.com', 'tiktok.com', 'twitch.tv', 'netflix.com', 'disneyplus.com',
      'bilibili.com', 'iqiyi.com', 'v.qq.com', 'mgtv.com', 'youku.com',
      'roblox.com', 'poki.com', 'crazygames.com', 'miniclip.com', 'now.gg'
    )
  );
