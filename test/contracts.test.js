import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const loadContract = async (name) => JSON.parse(
  await readFile(new URL(`../contracts/${name}`, import.meta.url), 'utf8'),
);

const loadMigration = async () => readFile(
  new URL('../supabase/migrations/20260821120924_initial_family_platform.sql', import.meta.url),
  'utf8',
);

const loadMembershipMigration = async () => readFile(
  new URL('../supabase/migrations/20260821123535_rls_family_membership_helper.sql', import.meta.url),
  'utf8',
);

const loadApplicationInventoryMigration = async () => readFile(
  new URL('../supabase/migrations/20260823095929_add_child_device_application_inventory.sql', import.meta.url),
  'utf8',
);

const loadDeviceEventsMigration = async () => readFile(
  new URL('../supabase/migrations/20260823102347_device_events_and_extra_time_requests.sql', import.meta.url),
  'utf8',
);

const loadPairingFunction = async () => readFile(
  new URL('../supabase/functions/timeboxer-pairing/index.ts', import.meta.url),
  'utf8',
);

test('family policy contract requires all enforcement fields', async () => {
  const schema = await loadContract('family-policy-v1.schema.json');
  assert.equal(schema.properties.version.const, 1);
  assert.deepEqual(
    new Set(schema.required),
    new Set([
      'version',
      'dayPlans',
      'maxSessionMinutes',
      'cooldownMinutes',
      'cooldownTriggerMinutes',
      'bedtimeBufferMinutes',
      'earnTasks',
      'protectedApplications',
      'protectedDomains',
    ]),
  );
});

test('device event contract excludes invasive monitoring payloads', async () => {
  const schema = await loadContract('device-event-v1.schema.json');
  const serialized = JSON.stringify(schema).toLowerCase();
  assert.equal(serialized.includes('screenshot'), false);
  assert.equal(serialized.includes('keystroke'), false);
  assert.equal(serialized.includes('pagecontent'), false);
});

test('application inventory is bounded and excludes invasive device data', async () => {
  const schema = await loadContract('device-application-inventory-v1.schema.json');
  assert.equal(schema.maxItems, 500);
  assert.equal(schema.items.additionalProperties, false);
  assert.deepEqual(
    new Set(Object.keys(schema.items.properties)),
    new Set(['bundleIdentifier', 'name', 'category', 'recommended']),
  );
  const serialized = JSON.stringify(schema).toLowerCase();
  for (const invasiveField of ['executablepath', 'screenshot', 'keystroke', 'pagecontent', 'usagehistory']) {
    assert.equal(serialized.includes(invasiveField), false);
  }
});

test('every exposed TimeBoxer table enables RLS and revokes anonymous access', async () => {
  const migration = await loadMigration();
  const tables = [...migration.matchAll(/create table public\.([a-z_]+)/g)].map((match) => match[1]);
  assert.ok(tables.length >= 9);

  for (const table of tables) {
    assert.match(migration, new RegExp(`alter table public\\.${table} enable row level security;`));
    assert.match(migration, new RegExp(`revoke all on public\\.${table} from anon, authenticated;`));
  }

  assert.doesNotMatch(migration, /grant [^;]+ to anon;/i);
  assert.doesNotMatch(migration, /security definer/i);
});

test('device secrets, pairing codes and push tokens stay in the private schema', async () => {
  const migration = await loadMigration();
  assert.match(migration, /create table private\.device_credentials/);
  assert.match(migration, /create table private\.device_pairing_sessions/);
  assert.match(migration, /create table private\.push_tokens/);
  assert.match(migration, /revoke all on schema private from public, anon, authenticated;/);
  assert.match(migration, /alter table private\.device_credentials enable row level security/);
  assert.match(migration, /alter table private\.device_pairing_sessions enable row level security/);
  assert.match(migration, /alter table private\.push_tokens enable row level security/);
});

test('family membership helpers stay private and validate the authenticated user', async () => {
  const migration = await loadMembershipMigration();
  assert.match(migration, /create function private\.is_family_member/);
  assert.match(migration, /create function private\.is_family_owner/);
  assert.match(migration, /security definer/);
  assert.match(migration, /auth\.uid\(\)/);
  assert.match(
    migration,
    /revoke execute on function private\.is_family_member\(uuid\) from public, anon, authenticated, service_role/,
  );
  assert.doesNotMatch(migration, /create function public\./);
});

test('application inventory extends the RLS-protected child device row', async () => {
  const initialMigration = await loadMigration();
  const inventoryMigration = await loadApplicationInventoryMigration();

  assert.match(initialMigration, /alter table public\.child_devices enable row level security;/);
  assert.match(initialMigration, /grant select on public\.child_devices to authenticated;/);
  assert.match(inventoryMigration, /add column application_inventory jsonb not null default '\[\]'::jsonb/);
  assert.match(inventoryMigration, /jsonb_array_length\(application_inventory\) <= 500/);
  assert.doesNotMatch(inventoryMigration, /grant\s+(insert|update|delete|all)[^;]+to\s+(anon|authenticated)/i);
});

test('Mac inventory upload is validated after device credential verification', async () => {
  const pairingFunction = await loadPairingFunction();
  const heartbeatStart = pairingFunction.indexOf('async function heartbeatDevice');
  const inventoryValidation = pairingFunction.indexOf('validApplicationInventory(body.applicationInventory)', heartbeatStart);
  const credentialDigest = pairingFunction.indexOf('const secretDigest = await sha256Hex(secret)', heartbeatStart);
  const inventoryWrite = pairingFunction.indexOf('application_inventory = case', heartbeatStart);

  assert.ok(heartbeatStart >= 0);
  assert.ok(inventoryValidation > heartbeatStart);
  assert.ok(credentialDigest > inventoryValidation);
  assert.ok(inventoryWrite > credentialDigest);
  assert.match(pairingFunction, /value\.length > 500/);
  assert.match(pairingFunction, /credential\.secret_digest = decode/);
});

test('extra-time requests have idempotency and one pending request per device', async () => {
  const migration = await loadDeviceEventsMigration();
  assert.match(migration, /add column client_request_id uuid not null/);
  assert.match(migration, /unique index extra_time_requests_device_client_id_idx/);
  assert.match(migration, /unique index extra_time_requests_one_pending_per_device_idx/);
  assert.match(migration, /where status = 'pending'/);
  assert.match(migration, /row_number\(\) over/);
  assert.match(migration, /revoke update on public\.extra_time_requests from authenticated/);
  assert.match(migration, /octet_length\(payload::text\) <= 4096/);
});

test('device events and requests require device credentials and reject invasive payloads', async () => {
  const pairingFunction = await loadPairingFunction();
  assert.match(pairingFunction, /async function authenticatedDevice/);
  assert.match(pairingFunction, /body\.action === "recordEvent"/);
  assert.match(pairingFunction, /body\.action === "requestExtraTime"/);
  assert.match(pairingFunction, /body\.action === "resolveRequest"/);
  assert.match(pairingFunction, /invasiveEventTerms = \["screenshot", "keystroke", "pagecontent"/);
  assert.match(pairingFunction, /on conflict \(device_id, client_event_id\) do nothing/);
  assert.match(pairingFunction, /credential\.secret_digest = decode/);
});
