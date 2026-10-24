import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { repoRoot, startServer } from "./lib/server.ts";

// One real SilverBullet server for the whole run. SB_URL lets a developer
// point the tests at a server they started themselves instead.
export default async function globalSetup(): Promise<void> {
  if (process.env.SB_URL) return;
  const server = await startServer();
  process.env.SB_URL = server.url;
  process.env.SB_SPACE_DIR = server.spaceDir;
  writeFileSync(join(repoRoot, ".sbtest-tmp/server.pid"), String(server.process.pid));
}
