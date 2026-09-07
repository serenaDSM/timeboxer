import postgres from "npm:postgres@3.4.7";

const databaseURL = Deno.env.get("SUPABASE_DB_URL");
if (!databaseURL) throw new Error("SUPABASE_DB_URL is unavailable");

const sql = postgres(databaseURL, { prepare: false, max: 1 });

type PairingBody = {
  action?: "bootstrap" | "create" | "consume" | "heartbeat" | "updatePolicy" |
    "recordEvent" | "requestExtraTime" | "resolveRequest";
  childId?: string;
  deviceId?: string;
  deviceSecret?: string;
  code?: string;
  installationId?: string;
  displayName?: string;
  appVersion?: string;
  osVersion?: string;
  publicKey?: string;
  expectedRevision?: number;
  policyDocument?: unknown;
  knownPolicyRevision?: number;
  applicationInventory?: unknown;
  event?: unknown;
  clientRequestId?: string;
  requestedMinutes?: number;
  requestId?: string;
  approved?: boolean;
};

type GatewayClaims = {
  sub?: string;
  email?: string;
  role?: "anon" | "authenticated";
};

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function json(data: unknown, status = 200): Response {
  return Response.json(data, { status });
}

function gatewayClaims(request: Request): GatewayClaims | null {
  const authorization = request.headers.get("Authorization") ?? "";
  const token = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const normalized = parts[1].replaceAll("-", "+").replaceAll("_", "/");
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
    return JSON.parse(atob(padded)) as GatewayClaims;
  } catch {
    return null;
  }
}

function randomCode(): string {
  const value = new Uint32Array(1);
  crypto.getRandomValues(value);
  return String(value[0] % 1_000_000).padStart(6, "0");
}

function randomSecret(): Uint8Array {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return bytes;
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function bytesToBase64URL(bytes: Uint8Array): string {
  const binary = Array.from(bytes, (byte) => String.fromCharCode(byte)).join("");
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

function base64ToBytes(value: string): Uint8Array | null {
  try {
    const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
    return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
  } catch {
    return null;
  }
}

function objectValue(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function integerInRange(value: unknown, minimum: number, maximum: number): boolean {
  return Number.isInteger(value) && Number(value) >= minimum && Number(value) <= maximum;
}

function validPolicyDocument(value: unknown): value is Record<string, unknown> {
  const document = objectValue(value);
  const dayPlans = objectValue(document?.dayPlans);
  if (!document || document.version !== 1 || !dayPlans) return false;

  for (const planName of ["school", "weekend", "holiday"]) {
    const plan = objectValue(dayPlans[planName]);
    if (
      !plan ||
      !integerInRange(plan.baseMinutes, 0, 120) ||
      !integerInRange(plan.earnCapMinutes, 0, 60)
    ) return false;
  }

  if (
    !integerInRange(document.maxSessionMinutes, 1, 60) ||
    !integerInRange(document.cooldownMinutes, 0, 120) ||
    !integerInRange(document.cooldownTriggerMinutes, 1, 120) ||
    !integerInRange(document.bedtimeBufferMinutes, 0, 180)
  ) return false;

  const arrays = [document.earnTasks, document.protectedApplications, document.protectedDomains];
  if (arrays.some((item) => !Array.isArray(item) || item.length > 200)) return false;
  if (!(document.earnTasks as unknown[]).every((item) => {
    const task = objectValue(item);
    return Boolean(
      task &&
      typeof task.id === "string" && task.id.length >= 1 && task.id.length <= 80 &&
      typeof task.title === "string" && task.title.length >= 1 && task.title.length <= 80 &&
      integerInRange(task.durationMinutes, 1, 180) &&
      integerInRange(task.rewardMinutes, 0, 60)
    );
  })) return false;
  if (!(document.protectedApplications as unknown[]).every((item) => typeof item === "string" && item.length <= 255)) {
    return false;
  }
  if (!(document.protectedDomains as unknown[]).every((item) => (
    typeof item === "string" &&
    item.length <= 253 &&
    /^[a-z0-9.-]+$/.test(item) &&
    item.includes(".")
  ))) return false;

  if (document.todayPlan !== undefined && !["school", "weekend", "holiday"].includes(String(document.todayPlan))) {
    return false;
  }
  if (document.todayPlanDate !== undefined && !/^\d{4}-\d{2}-\d{2}$/.test(String(document.todayPlanDate))) {
    return false;
  }
  if (document.parentBonusMinutes !== undefined && !integerInRange(document.parentBonusMinutes, 0, 120)) {
    return false;
  }
  if (document.parentBonusDate !== undefined && !/^\d{4}-\d{2}-\d{2}$/.test(String(document.parentBonusDate))) {
    return false;
  }
  return true;
}

type DeviceApplication = {
  bundleIdentifier: string;
  name: string;
  category?: string;
  recommended: boolean;
};

function validApplicationInventory(value: unknown): value is DeviceApplication[] {
  if (!Array.isArray(value) || value.length > 500) return false;
  const bundleIdentifiers = new Set<string>();
  for (const item of value) {
    const application = objectValue(item);
    if (
      !application ||
      typeof application.bundleIdentifier !== "string" ||
      application.bundleIdentifier.length < 1 ||
      application.bundleIdentifier.length > 255 ||
      !/^[a-z0-9.-]+$/i.test(application.bundleIdentifier) ||
      typeof application.name !== "string" ||
      application.name.trim().length < 1 ||
      application.name.length > 120 ||
      typeof application.recommended !== "boolean" ||
      (application.category !== undefined && (
        typeof application.category !== "string" || application.category.length > 255
      ))
    ) return false;
    if (bundleIdentifiers.has(application.bundleIdentifier)) return false;
    bundleIdentifiers.add(application.bundleIdentifier);
  }
  return true;
}

type DeviceEvent = {
  version: 1;
  clientEventId: string;
  eventType: string;
  severity: string;
  subjectLabel?: string;
  occurredAt: string;
  payload?: Record<string, unknown>;
};

const deviceEventTypes = new Set([
  "device_online", "device_offline", "app_blocked", "website_blocked",
  "earn_started", "earn_completed", "earn_stopped", "play_started",
  "play_ended", "request_created", "policy_applied",
]);
const deviceEventSeverities = new Set(["info", "action", "violation"]);
const invasiveEventTerms = ["screenshot", "keystroke", "pagecontent", "clipboard", "browserhistory"];

function validDeviceEvent(value: unknown): value is DeviceEvent {
  const event = objectValue(value);
  const payload = event?.payload === undefined ? {} : objectValue(event.payload);
  if (
    !event || event.version !== 1 ||
    typeof event.clientEventId !== "string" || !uuidPattern.test(event.clientEventId) ||
    typeof event.eventType !== "string" || !deviceEventTypes.has(event.eventType) ||
    typeof event.severity !== "string" || !deviceEventSeverities.has(event.severity) ||
    typeof event.occurredAt !== "string" ||
    (event.subjectLabel !== undefined && (
      typeof event.subjectLabel !== "string" || event.subjectLabel.length > 160
    )) ||
    !payload || Object.keys(payload).length > 20
  ) return false;

  const occurredAt = Date.parse(event.occurredAt);
  const now = Date.now();
  if (!Number.isFinite(occurredAt) || occurredAt < now - 7 * 86_400_000 || occurredAt > now + 300_000) {
    return false;
  }
  const serialized = JSON.stringify(payload);
  if (new TextEncoder().encode(serialized).length > 4096) return false;
  const normalized = serialized.toLowerCase();
  return invasiveEventTerms.every((term) => !normalized.includes(term));
}

async function authenticatedDevice(body: PairingBody): Promise<{ id: string; childId: string } | null> {
  const deviceID = body.deviceId?.trim() ?? "";
  const installationID = body.installationId?.trim() ?? "";
  const secret = base64ToBytes(body.deviceSecret ?? "");
  if (!uuidPattern.test(deviceID) || !uuidPattern.test(installationID) || !secret || secret.length !== 32) {
    return null;
  }
  const secretDigest = await sha256Hex(secret);
  const devices = await sql`
    select device.id, device.child_id
    from public.child_devices device
    join private.device_credentials credential on credential.device_id = device.id
    where device.id = ${deviceID}::uuid
      and device.installation_id = ${installationID}::uuid
      and device.revoked_at is null
      and credential.revoked_at is null
      and credential.secret_digest = decode(${secretDigest}, 'hex')
    limit 1
  `;
  if (devices.length !== 1) return null;
  return { id: devices[0].id, childId: devices[0].child_id };
}

async function sha256Hex(value: string | Uint8Array): Promise<string> {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  return bytesToHex(new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)));
}

async function bootstrapFamily(userID: string, email?: string): Promise<Response> {
  const suggestedName = (email?.split("@")[0] || "Parent").slice(0, 80);
  const result = await sql.begin(async (transaction) => {
    await transaction`
      insert into public.account_profiles (id, display_name, locale)
      values (${userID}::uuid, ${suggestedName}, 'en-NZ')
      on conflict (id) do nothing
    `;

    let memberships = await transaction`
      select family_id
      from public.family_members
      where user_id = ${userID}::uuid
      order by created_at
      limit 1
    `;
    if (memberships.length === 0) {
      const families = await transaction`
        insert into public.families (display_name, timezone, created_by)
        values ('My family', 'Pacific/Auckland', ${userID}::uuid)
        returning id
      `;
      await transaction`
        insert into public.family_members (family_id, user_id, role)
        values (${families[0].id}::uuid, ${userID}::uuid, 'owner')
      `;
      memberships = [{ family_id: families[0].id }];
    }

    const familyID = memberships[0].family_id;
    let children = await transaction`
      select id, display_name
      from public.children
      where family_id = ${familyID}::uuid and archived_at is null
      order by created_at
      limit 1
    `;
    if (children.length === 0) {
      children = await transaction`
        insert into public.children (family_id, display_name, timezone)
        values (${familyID}::uuid, 'My child', 'Pacific/Auckland')
        returning id, display_name
      `;
    }

    const childID = children[0].id;
    await transaction`
      insert into public.family_policies (child_id, updated_by)
      values (${childID}::uuid, ${userID}::uuid)
      on conflict (child_id) do nothing
    `;
    await transaction`
      insert into public.family_entitlements (family_id, plan, status)
      values (${familyID}::uuid, 'pilot', 'active')
      on conflict (family_id) do nothing
    `;

    return { familyId: familyID, childId: childID, childName: children[0].display_name };
  });
  return json(result);
}

async function createPairing(body: PairingBody, userID: string): Promise<Response> {
  const childID = body.childId?.trim() ?? "";
  if (!uuidPattern.test(childID)) return json({ error: "A valid child is required." }, 400);

  const membership = await sql`
    select child.id
    from public.children child
    join public.family_members member on member.family_id = child.family_id
    where child.id = ${childID}::uuid
      and member.user_id = ${userID}::uuid
      and child.archived_at is null
    limit 1
  `;
  if (membership.length === 0) return json({ error: "The child is not in this family." }, 403);

  for (let attempt = 0; attempt < 5; attempt += 1) {
    const code = randomCode();
    const digest = await sha256Hex(code);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
    try {
      await sql.begin(async (transaction) => {
        await transaction`
          delete from private.device_pairing_sessions
          where child_id = ${childID}::uuid
            and created_by = ${userID}::uuid
            and consumed_at is null
        `;
        await transaction`
          insert into private.device_pairing_sessions (
            family_id, child_id, code_digest, created_by, expires_at
          )
          select child.family_id, child.id, decode(${digest}, 'hex'), ${userID}::uuid, ${expiresAt}
          from public.children child
          where child.id = ${childID}::uuid
        `;
      });
      return json({ code, expiresAt: expiresAt.toISOString() });
    } catch (error) {
      if (attempt === 4) throw error;
    }
  }

  return json({ error: "A pairing code could not be created." }, 500);
}

async function updatePolicy(body: PairingBody, userID: string): Promise<Response> {
  const childID = body.childId?.trim() ?? "";
  if (!uuidPattern.test(childID)) return json({ error: "A valid child is required." }, 400);
  if (!integerInRange(body.expectedRevision, 1, Number.MAX_SAFE_INTEGER)) {
    return json({ error: "Refresh the family rules and try again." }, 409);
  }
  if (!validPolicyDocument(body.policyDocument)) {
    return json({ error: "The family rules are invalid." }, 400);
  }

  const updated = await sql`
    update public.family_policies as policy
    set
      document = ${sql.json(body.policyDocument)},
      revision = policy.revision + 1,
      updated_by = ${userID}::uuid,
      updated_at = now()
    where policy.child_id = ${childID}::uuid
      and policy.revision = ${body.expectedRevision}
      and exists (
        select 1
        from public.children child
        join public.family_members member on member.family_id = child.family_id
        where child.id = policy.child_id
          and child.archived_at is null
          and member.user_id = ${userID}::uuid
      )
    returning policy.revision, policy.document
  `;

  if (updated.length !== 1) {
    return json({ error: "The family rules changed on another device. Refresh and try again." }, 409);
  }
  return json({ revision: Number(updated[0].revision), document: updated[0].document });
}

async function resolveExtraTimeRequest(body: PairingBody, userID: string): Promise<Response> {
  const requestID = body.requestId?.trim() ?? "";
  if (!uuidPattern.test(requestID) || typeof body.approved !== "boolean") {
    return json({ error: "A valid request decision is required." }, 400);
  }

  const result = await sql.begin(async (transaction) => {
    const requests = await transaction`
      select
        request.id,
        request.client_request_id,
        request.child_id,
        request.device_id,
        request.requested_minutes,
        request.status,
        to_char(now() at time zone child.timezone, 'YYYY-MM-DD') as local_date
      from public.extra_time_requests request
      join public.children child on child.id = request.child_id
      join public.family_members member on member.family_id = child.family_id
      where request.id = ${requestID}::uuid
        and member.user_id = ${userID}::uuid
        and child.archived_at is null
      for update of request
    `;
    if (requests.length !== 1) return null;

    const request = requests[0];
    if (request.status !== "pending") {
      return { id: request.id, status: request.status, policy: null };
    }

    const status = body.approved ? "approved" : "declined";
    await transaction`
      update public.extra_time_requests
      set status = ${status}, resolved_at = now(), resolved_by = ${userID}::uuid
      where id = ${request.id}::uuid
    `;

    let policy: Record<string, unknown> | null = null;
    if (body.approved) {
      const policies = await transaction`
        update public.family_policies
        set
          document = jsonb_set(
            jsonb_set(document, '{parentBonusDate}', to_jsonb(${request.local_date}::text), true),
            '{parentBonusMinutes}',
            to_jsonb(least(
              120,
              (
                case
                  when document ->> 'parentBonusDate' = ${request.local_date}
                    then coalesce((document ->> 'parentBonusMinutes')::integer, 0)
                  else 0
                end
              ) + ${Number(request.requested_minutes)}
            )),
            true
          ),
          revision = revision + 1,
          updated_by = ${userID}::uuid,
          updated_at = now()
        where child_id = ${request.child_id}::uuid
        returning revision, document
      `;
      policy = policies[0]
        ? { revision: Number(policies[0].revision), document: policies[0].document }
        : null;
    }

    await transaction`
      insert into public.activity_events (
        client_event_id, child_id, device_id, event_type, severity,
        subject_label, payload, occurred_at
      ) values (
        gen_random_uuid(), ${request.child_id}::uuid, ${request.device_id}::uuid,
        'request_resolved', 'info',
        ${body.approved ? "Extra time approved" : "Extra time declined"},
        ${sql.json({ status, requestedMinutes: Number(request.requested_minutes) })},
        now()
      )
    `;

    return { id: request.id, status, policy };
  });

  if (!result) return json({ error: "The request was not found in this family." }, 404);
  return json(result);
}

async function consumePairing(body: PairingBody): Promise<Response> {
  const code = body.code?.replace(/\s/g, "") ?? "";
  const installationID = body.installationId?.trim() ?? "";
  const displayName = body.displayName?.trim().slice(0, 120) ?? "";
  const publicKey = base64ToBytes(body.publicKey ?? "");

  if (!/^\d{6}$/.test(code)) return json({ error: "Enter the six-digit code." }, 400);
  if (!uuidPattern.test(installationID)) return json({ error: "The Mac identity is invalid." }, 400);
  if (!displayName) return json({ error: "The Mac name is required." }, 400);
  if (!publicKey || publicKey.length !== 32) return json({ error: "The Mac key is invalid." }, 400);

  const codeDigest = await sha256Hex(code);
  const deviceSecret = randomSecret();
  const secretDigest = await sha256Hex(deviceSecret);
  const publicKeyHex = bytesToHex(publicKey);

  try {
    const result = await sql.begin(async (transaction) => {
      const sessions = await transaction`
        select pairing.id, pairing.child_id, child.family_id
        from private.device_pairing_sessions pairing
        join public.children child on child.id = pairing.child_id
        where pairing.code_digest = decode(${codeDigest}, 'hex')
          and pairing.consumed_at is null
          and pairing.expires_at > now()
        for update
      `;
      if (sessions.length !== 1) throw new Error("PAIRING_CODE_INVALID");

      const session = sessions[0];
      const existing = await transaction`
        select id, child_id
        from public.child_devices
        where installation_id = ${installationID}::uuid
        for update
      `;
      if (existing.length > 0 && existing[0].child_id !== session.child_id) {
        throw new Error("MAC_ALREADY_PAIRED");
      }

      const devices = await transaction`
        insert into public.child_devices (
          child_id, installation_id, platform, display_name, app_version,
          os_version, last_seen_at, revoked_at
        ) values (
          ${session.child_id}::uuid, ${installationID}::uuid, 'macos', ${displayName},
          ${body.appVersion ?? null}, ${body.osVersion ?? null}, now(), null
        )
        on conflict (installation_id) do update set
          display_name = excluded.display_name,
          app_version = excluded.app_version,
          os_version = excluded.os_version,
          last_seen_at = now(),
          revoked_at = null,
          updated_at = now()
        returning id, child_id
      `;
      const device = devices[0];

      await transaction`
        insert into private.device_credentials (device_id, public_key, secret_digest)
        values (${device.id}::uuid, decode(${publicKeyHex}, 'hex'), decode(${secretDigest}, 'hex'))
        on conflict (device_id) do update set
          public_key = excluded.public_key,
          secret_digest = excluded.secret_digest,
          rotated_at = now(),
          revoked_at = null
      `;
      await transaction`
        update private.device_pairing_sessions
        set consumed_at = now()
        where id = ${session.id}::uuid
      `;
      const policies = await transaction`
        select revision, document
        from public.family_policies
        where child_id = ${device.child_id}::uuid
      `;

      return {
        deviceId: device.id,
        childId: device.child_id,
        // postgres.js preserves PostgreSQL bigint values as strings so that
        // JavaScript cannot silently lose precision. Policy revisions are
        // constrained to a safe, small positive value in our schema, and the
        // native clients intentionally consume this field as a JSON number.
        policyRevision: Number(policies[0]?.revision ?? 0),
        policy: policies[0]?.document ?? null,
      };
    });

    return json({ ...result, deviceSecret: bytesToBase64URL(deviceSecret) });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (message.includes("PAIRING_CODE_INVALID")) {
      return json({ error: "The code is invalid or has expired." }, 404);
    }
    if (message.includes("MAC_ALREADY_PAIRED")) {
      return json({ error: "This Mac is already paired with another child." }, 409);
    }
    console.error("Pairing failed", error);
    return json({ error: "The Mac could not be paired." }, 500);
  }
}

async function heartbeatDevice(body: PairingBody): Promise<Response> {
  const deviceID = body.deviceId?.trim() ?? "";
  const installationID = body.installationId?.trim() ?? "";
  const secret = base64ToBytes(body.deviceSecret ?? "");

  if (!uuidPattern.test(deviceID) || !uuidPattern.test(installationID)) {
    return json({ error: "The Mac identity is invalid." }, 400);
  }
  if (!secret || secret.length !== 32) {
    return json({ error: "Valid device credentials are required." }, 401);
  }
  const hasApplicationInventory = body.applicationInventory !== undefined;
  if (hasApplicationInventory && !validApplicationInventory(body.applicationInventory)) {
    return json({ error: "The application inventory is invalid." }, 400);
  }

  const secretDigest = await sha256Hex(secret);
  const applicationInventory = hasApplicationInventory
    ? body.applicationInventory as DeviceApplication[]
    : [];
  const devices = await sql`
    update public.child_devices as device
    set
      last_seen_at = now(),
      app_version = coalesce(${body.appVersion ?? null}, device.app_version),
      os_version = coalesce(${body.osVersion ?? null}, device.os_version),
      application_inventory = case
        when ${hasApplicationInventory} then ${sql.json(applicationInventory)}
        else device.application_inventory
      end,
      application_inventory_scanned_at = case
        when ${hasApplicationInventory} then now()
        else device.application_inventory_scanned_at
      end,
      updated_at = now()
    from private.device_credentials as credential
    where device.id = ${deviceID}::uuid
      and device.installation_id = ${installationID}::uuid
      and device.revoked_at is null
      and credential.device_id = device.id
      and credential.revoked_at is null
      and credential.secret_digest = decode(${secretDigest}, 'hex')
    returning device.id, device.child_id, device.last_seen_at
  `;

  if (devices.length !== 1) {
    return json({ error: "Valid device credentials are required." }, 401);
  }

  const policies = await sql`
    select revision, document
    from public.family_policies
    where child_id = ${devices[0].child_id}::uuid
  `;

  const policyRevision = Number(policies[0]?.revision ?? 0);
  const knownPolicyRevision = integerInRange(body.knownPolicyRevision, 0, Number.MAX_SAFE_INTEGER)
    ? Number(body.knownPolicyRevision)
    : 0;
  if (knownPolicyRevision <= policyRevision) {
    await sql`
      update public.child_devices
      set acknowledged_policy_revision = greatest(acknowledged_policy_revision, ${knownPolicyRevision})
      where id = ${devices[0].id}::uuid
    `;
  }

  return json({
    deviceId: devices[0].id,
    lastSeenAt: devices[0].last_seen_at,
    policyRevision,
    policy: policyRevision > knownPolicyRevision ? policies[0]?.document ?? null : null,
    requestUpdates: (await sql`
      select id, client_request_id, requested_minutes, status, requested_at, resolved_at
      from public.extra_time_requests
      where device_id = ${devices[0].id}::uuid
        and requested_at > now() - interval '7 days'
      order by requested_at desc
      limit 20
    `).map((request) => ({
      id: request.id,
      clientRequestId: request.client_request_id,
      requestedMinutes: Number(request.requested_minutes),
      status: request.status,
      requestedAt: request.requested_at,
      resolvedAt: request.resolved_at,
    })),
  });
}

async function recordDeviceEvent(body: PairingBody): Promise<Response> {
  if (!validDeviceEvent(body.event)) return json({ error: "The device event is invalid." }, 400);
  const device = await authenticatedDevice(body);
  if (!device) return json({ error: "Valid device credentials are required." }, 401);
  const event = body.event;
  const rows = await sql`
    insert into public.activity_events (
      client_event_id, child_id, device_id, event_type, severity,
      subject_label, payload, occurred_at
    ) values (
      ${event.clientEventId}::uuid, ${device.childId}::uuid, ${device.id}::uuid,
      ${event.eventType}, ${event.severity}, ${event.subjectLabel ?? null},
      ${sql.json(event.payload ?? {})}, ${event.occurredAt}::timestamptz
    )
    on conflict (device_id, client_event_id) do nothing
    returning id
  `;
  return json({ accepted: rows.length === 1, duplicate: rows.length === 0 });
}

async function requestExtraTime(body: PairingBody): Promise<Response> {
  const clientRequestID = body.clientRequestId?.trim() ?? "";
  if (!uuidPattern.test(clientRequestID) || !integerInRange(body.requestedMinutes, 1, 60)) {
    return json({ error: "The extra-time request is invalid." }, 400);
  }
  const device = await authenticatedDevice(body);
  if (!device) return json({ error: "Valid device credentials are required." }, 401);
  const requestedMinutes = Number(body.requestedMinutes);

  const result = await sql.begin(async (transaction) => {
    await transaction`
      select id from public.child_devices where id = ${device.id}::uuid for update
    `;
    await transaction`
      update public.extra_time_requests
      set status = 'expired', resolved_at = now()
      where device_id = ${device.id}::uuid
        and status = 'pending'
        and requested_at < now() - interval '24 hours'
    `;
    const duplicate = await transaction`
      select id, status, requested_minutes
      from public.extra_time_requests
      where device_id = ${device.id}::uuid
        and client_request_id = ${clientRequestID}::uuid
      limit 1
    `;
    if (duplicate.length === 1) return duplicate[0];

    const pending = await transaction`
      select id, status, requested_minutes
      from public.extra_time_requests
      where device_id = ${device.id}::uuid and status = 'pending'
      limit 1
    `;
    if (pending.length === 1) return pending[0];

    const requests = await transaction`
      insert into public.extra_time_requests (
        client_request_id, child_id, device_id, requested_minutes
      ) values (
        ${clientRequestID}::uuid, ${device.childId}::uuid, ${device.id}::uuid, ${requestedMinutes}
      )
      returning id, status, requested_minutes
    `;
    await transaction`
      insert into public.activity_events (
        client_event_id, child_id, device_id, event_type, severity,
        subject_label, payload, occurred_at
      ) values (
        ${clientRequestID}::uuid, ${device.childId}::uuid, ${device.id}::uuid,
        'request_created', 'action', 'Extra time requested',
        ${sql.json({ requestedMinutes })}, now()
      )
      on conflict (device_id, client_event_id) do nothing
    `;
    return requests[0];
  });

  return json({
    id: result.id,
    status: result.status,
    requestedMinutes: Number(result.requested_minutes),
  });
}

export default {
  fetch: async (request: Request) => {
    if (request.method !== "POST") return json({ error: "Method not allowed." }, 405);

    // The Supabase gateway verifies this JWT before the handler is reached.
    // Claims are decoded here only to route the already-verified caller role.
    const claims = gatewayClaims(request);
    if (!claims?.role) return json({ error: "Valid TimeBoxer credentials are required." }, 401);

    let body: PairingBody;
    try {
      body = await request.json();
    } catch {
      return json({ error: "A JSON body is required." }, 400);
    }

    if (claims.role === "authenticated") {
      const userID = claims.sub;
      if (!userID) return json({ error: "Sign in again." }, 401);
      if (body.action === "bootstrap") {
        return bootstrapFamily(userID, claims.email);
      }
      if (body.action === "create") return createPairing(body, userID);
      if (body.action === "updatePolicy") return updatePolicy(body, userID);
      if (body.action === "resolveRequest") return resolveExtraTimeRequest(body, userID);
      return json({ error: "Parent action required." }, 403);
    }

    if (claims.role !== "anon") {
      return json({ error: "Mac action required." }, 403);
    }
    if (body.action === "consume") return consumePairing(body);
    if (body.action === "heartbeat") return heartbeatDevice(body);
    if (body.action === "recordEvent") return recordDeviceEvent(body);
    if (body.action === "requestExtraTime") return requestExtraTime(body);
    return json({ error: "Mac action required." }, 403);
  },
};
