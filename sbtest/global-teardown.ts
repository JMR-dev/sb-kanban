import { existsSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { repoRoot, stopServer } from "./lib/server.ts";

export default async function globalTeardown(): Promise<void> {
  const pidFile = join(repoRoot, ".sbtest-tmp/server.pid");
  if (!existsSync(pidFile)) return;
  stopServer({ pid: Number(readFileSync(pidFile, "utf8")) });
  rmSync(pidFile);
}
