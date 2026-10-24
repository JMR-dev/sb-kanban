// Builds the Runtime API script that runs one Lua spec inside SilverBullet:
// the shim (sbtest/shim.lua) kept in a local, optionally the parsed
// tools/sb_api.lua as `sbApi`, then the spec in its own block with the busted
// subset bound as locals, so no global of the live client changes.

import { readFileSync } from "node:fs";
import { join } from "node:path";
import { repoRoot } from "./server.ts";

const shim = readFileSync(join(repoRoot, "sbtest/shim.lua"), "utf8");
const sbApi = readFileSync(join(repoRoot, "tools/sb_api.lua"), "utf8");

export type SpecResults = { passed: number; failures?: { name: string; message: string }[] };

export function bundle(spec: string, withApi: boolean): string {
  return [
    "local __h = (function()",
    shim,
    "end)()",
    withApi ? `local sbApi = (function()\n${sbApi}\nend)()` : "",
    "do",
    "local describe, it, before_each, assert = __h.describe, __h.it, __h.before_each, __h.assert",
    spec,
    "end",
    "return __h.results()",
  ].join("\n");
}
