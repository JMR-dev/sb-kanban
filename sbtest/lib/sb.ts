// Helpers for talking to the SilverBullet server started by global-setup.ts:
// the Runtime API (Lua inside the server's headless client) and the HTTP file
// API (/.fs/).

export function sbUrl(): string {
  const url = process.env.SB_URL;
  if (!url) throw new Error("SB_URL is not set: tests must run through playwright.config.ts");
  return url;
}

export class LuaError extends Error {}

/** Runs a Lua script (with explicit `return`) in the headless client. */
export async function runScript<T = unknown>(script: string): Promise<T> {
  const res = await fetch(`${sbUrl()}/.runtime/lua_script`, {
    method: "POST",
    body: script,
    headers: { "X-Timeout": "120000" },
  });
  const body = (await res.json()) as { result?: T; error?: string };
  if (body.error) throw new LuaError(body.error);
  return body.result as T;
}

/** Evaluates one Lua expression in the headless client. */
export async function runLua<T = unknown>(expr: string): Promise<T> {
  const res = await fetch(`${sbUrl()}/.runtime/lua`, { method: "POST", body: expr });
  const body = (await res.json()) as { result?: T; error?: string };
  if (body.error) throw new LuaError(body.error);
  return body.result as T;
}

function fsUrl(path: string): string {
  return `${sbUrl()}/.fs/${path.split("/").map(encodeURIComponent).join("/")}`;
}

export async function readFile(path: string): Promise<string> {
  const res = await fetch(fsUrl(path));
  if (!res.ok) throw new Error(`GET ${path}: ${res.status}`);
  return res.text();
}

export async function writeFile(path: string, text: string): Promise<void> {
  const res = await fetch(fsUrl(path), { method: "PUT", body: text });
  if (!res.ok) throw new Error(`PUT ${path}: ${res.status}`);
}

/** Polls `probe` until it returns something other than undefined/false.
 * SilverBullet indexes external writes a few seconds later, so tests wait for
 * the state they expect rather than sleeping. */
export async function eventually<T>(
  what: string,
  probe: () => Promise<T | undefined | false>,
  timeoutMs = 30_000,
): Promise<T> {
  const deadline = Date.now() + timeoutMs;
  let last: unknown;
  while (Date.now() < deadline) {
    try {
      const v = await probe();
      if (v !== undefined && v !== false) return v as T;
    } catch (e) {
      last = e;
    }
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error(`timed out waiting for ${what}${last ? `: ${last}` : ""}`);
}
