// Starts the pinned SilverBullet server (scripts/bootstrap.sh installs it to
// .tools/bin) on a scratch copy of the fixture space, with the committed
// library page installed, and waits until its headless Runtime API client has
// booted, indexed the space and loaded the library.

import { spawn, type ChildProcess } from "node:child_process";
import { cpSync, existsSync, mkdirSync, mkdtempSync, openSync } from "node:fs";
import { createServer } from "node:net";
import { dirname, join, resolve } from "node:path";
import { chromium } from "@playwright/test";

export const repoRoot = resolve(import.meta.dirname, "../..");
export const pagePath = join(repoRoot, "dist/Library/JMR-dev/Kanban.md");
const fixtureSpace = join(repoRoot, "sbtest/space");
const serverBinary = join(repoRoot, ".tools/bin/silverbullet");

export type RunningServer = { url: string; spaceDir: string; process: ChildProcess };

/** The Chrome the Runtime API should drive: SB_CHROME_PATH if set, else the
 * headless shell that matches Playwright's Chromium, else that Chromium. */
export function chromePath(): string {
  if (process.env.SB_CHROME_PATH) return process.env.SB_CHROME_PATH;
  const full = chromium.executablePath();
  const shell = full.replace(
    /chromium-(\d+)\/chrome-linux64\/chrome$/,
    "chromium_headless_shell-$1/chrome-headless-shell-linux64/chrome-headless-shell",
  );
  return existsSync(shell) ? shell : full;
}

function freePort(): Promise<number> {
  return new Promise((resolvePort, reject) => {
    const srv = createServer();
    srv.unref();
    srv.on("error", reject);
    srv.listen(0, "127.0.0.1", () => {
      const address = srv.address();
      srv.close(() => {
        if (address && typeof address === "object") resolvePort(address.port);
        else reject(new Error("no port"));
      });
    });
  });
}

async function waitFor<T>(
  what: string,
  timeoutMs: number,
  probe: () => Promise<T | undefined>,
): Promise<T> {
  const deadline = Date.now() + timeoutMs;
  let lastError: unknown;
  while (Date.now() < deadline) {
    try {
      const value = await probe();
      if (value !== undefined) return value;
    } catch (e) {
      lastError = e;
    }
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error(`timed out after ${timeoutMs} ms waiting for ${what}: ${lastError ?? ""}`);
}

async function lua(url: string, expr: string): Promise<unknown> {
  const res = await fetch(`${url}/.runtime/lua`, { method: "POST", body: expr });
  const body = (await res.json()) as { result?: unknown; error?: string };
  if (body.error) throw new Error(body.error);
  return body.result;
}

export async function startServer(): Promise<RunningServer> {
  if (!existsSync(serverBinary)) {
    throw new Error(`${serverBinary} is missing: run scripts/bootstrap.sh silverbullet`);
  }
  if (!existsSync(pagePath)) throw new Error(`${pagePath} is missing: run make build`);

  const tmpRoot = join(repoRoot, ".sbtest-tmp");
  mkdirSync(tmpRoot, { recursive: true });
  const runDir = mkdtempSync(join(tmpRoot, "run-"));
  const spaceDir = join(runDir, "space");
  cpSync(fixtureSpace, spaceDir, { recursive: true });
  const installed = join(spaceDir, "Library/JMR-dev/Kanban.md");
  mkdirSync(dirname(installed), { recursive: true });
  cpSync(pagePath, installed);

  const port = await freePort();
  const url = `http://127.0.0.1:${port}`;
  const log = openSync(join(runDir, "server.log"), "a");
  const child = spawn(serverBinary, ["-L", "127.0.0.1", "-p", String(port), spaceDir], {
    env: { ...process.env, SB_CHROME_PATH: chromePath() },
    stdio: ["ignore", log, log],
    detached: true,
  });
  child.unref();

  const server = { url, spaceDir, process: child };
  try {
    await waitFor("HTTP", 30_000, async () => ((await fetch(url)).ok ? true : undefined));
    // The first Runtime API call also waits for the headless client to boot.
    await waitFor("the Runtime API", 120_000, async () =>
      (await lua(url, "1 + 1")) === 2 ? true : undefined,
    );
    await waitFor("the initial index", 120_000, async () => {
      const res = await fetch(`${url}/.runtime/logs?limit=1000`);
      const { logs } = (await res.json()) as { logs: { text: string }[] };
      return logs.some((l) => l.text.includes("Initial index complete")) ? true : undefined;
    });
    await waitFor("the kanban library to load", 60_000, async () =>
      (await lua(url, "kanban and kanban.apiVersion")) != null ? true : undefined,
    );
  } catch (e) {
    stopServer(server);
    throw new Error(`${e}\n(server log: ${join(runDir, "server.log")})`);
  }
  return server;
}

export function stopServer(server: { process: ChildProcess } | { pid: number }): void {
  const pid = "pid" in server ? server.pid : server.process.pid;
  if (!pid) return;
  try {
    // The server and its headless Chrome share the process group.
    process.kill(-pid, "SIGTERM");
  } catch {
    // Already gone.
  }
}
