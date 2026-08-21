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
});
