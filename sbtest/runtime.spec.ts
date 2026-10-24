// Runs Lua specs inside the real SilverBullet's headless client through the
// Runtime API: the pure-core specs (spec/core/, which also run on Lua 5.5.1)
// against the installed library page, and the SilverBullet-only integration
// specs (sbtest/runtime/). One Playwright test per spec file.

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { expect, test } from "@playwright/test";
import { repoRoot } from "./lib/server.ts";
import { runScript } from "./lib/sb.ts";

const shim = readFileSync(join(repoRoot, "sbtest/shim.lua"), "utf8");
const sbApi = readFileSync(join(repoRoot, "tools/sb_api.lua"), "utf8");

function specFiles(dir: string): string[] {
  const abs = join(repoRoot, dir);
  if (!existsSync(abs)) return [];
  return readdirSync(abs)
    .filter((f) => f.endsWith("_spec.lua"))
    .sort()
    .map((f) => join(dir, f));
}

/** One Runtime API script: the shim kept in a local, then the spec in its own
 * block with the busted-subset names bound as locals, so no global changes. */
function bundle(spec: string, withApi: boolean): string {
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

type Results = { passed: number; failures?: { name: string; message: string }[] };

const groups: [string, string, boolean][] = [
  ["core", "spec/core", false],
  ["runtime", "sbtest/runtime", true],
];

for (const [group, dir, withApi] of groups) {
  for (const file of specFiles(dir)) {
    test(`${group}: ${file}`, async () => {
      const source = readFileSync(join(repoRoot, file), "utf8");
      const results = await runScript<Results>(bundle(source, withApi));
      // An empty Lua table may arrive as {} rather than [].
      const failures = Array.isArray(results.failures) ? results.failures : [];
      expect(
        failures.map((f) => `${f.name}\n    ${f.message}`).join("\n\n"),
        `failing specs in ${file}`,
      ).toBe("");
      expect(results.passed, `passing specs in ${file}`).toBeGreaterThan(0);
    });
  }
}
