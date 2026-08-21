import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';

const statePath = join(homedir(), 'Library', 'Application Support', 'TimeBoxer', 'family-state.json');
const heartbeatPath = join(homedir(), 'Library', 'Application Support', 'TimeBoxer', 'mac-heartbeat.json');
const maxBodyBytes = 1_000_000;

async function readEnvelope() {
  try {
    return JSON.parse(await readFile(statePath, 'utf8'));
  } catch (error) {
    if (error?.code === 'ENOENT') return { schemaVersion: 1, revision: 0, state: null };
    throw error;
  }
}

async function readMacHeartbeat() {
  try {
    const heartbeat = JSON.parse(await readFile(heartbeatPath, 'utf8'));
    return Number(heartbeat.macHeartbeatAt) || 0;
  } catch (error) {
    if (error?.code === 'ENOENT') return 0;
    throw error;
  }
}

async function writeEnvelope({ sourceId, state }) {
  const current = await readEnvelope();
  const envelope = {
    schemaVersion: 1,
    revision: Math.max(0, Number(current.revision) || 0) + 1,
    updatedAt: Date.now(),
    sourceId: String(sourceId || 'parent-web'),
    state,
  };
  await mkdir(dirname(statePath), { recursive: true });
  const temporaryPath = `${statePath}.tmp-${process.pid}`;
  await writeFile(temporaryPath, `${JSON.stringify(envelope, null, 2)}\n`, 'utf8');
  await rename(temporaryPath, statePath);
  return envelope;
}

function sendJson(response, status, value) {
  response.statusCode = status;
  response.setHeader('Content-Type', 'application/json; charset=utf-8');
  response.setHeader('Cache-Control', 'no-store');
  response.end(JSON.stringify(value));
}

async function readJsonBody(request) {
  let body = '';
  for await (const chunk of request) {
    body += chunk;
    if (Buffer.byteLength(body) > maxBodyBytes) throw new Error('Family state payload is too large');
  }
  return JSON.parse(body || '{}');
}

export function localFamilyStateApi() {
  const handler = async (request, response, next) => {
    if (request.url?.split('?')[0] !== '/api/family-state') return next();
    try {
      if (request.method === 'GET') {
        sendJson(response, 200, {
          ...(await readEnvelope()),
          macHeartbeatAt: await readMacHeartbeat(),
        });
        return;
      }
      if (request.method === 'PUT') {
        const payload = await readJsonBody(request);
        if (!payload.state || typeof payload.state !== 'object') {
          sendJson(response, 400, { error: 'A family state object is required.' });
          return;
        }
        sendJson(response, 200, await writeEnvelope(payload));
        return;
      }
      sendJson(response, 405, { error: 'Method not allowed.' });
    } catch (error) {
      sendJson(response, 500, { error: error.message || 'Could not sync family state.' });
    }
  };

  return {
    name: 'timeboxer-local-family-state-api',
    configureServer(server) {
      server.middlewares.use(handler);
    },
    configurePreviewServer(server) {
      server.middlewares.use(handler);
    },
  };
}
