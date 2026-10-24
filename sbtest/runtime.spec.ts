// Runs Lua specs inside the real SilverBullet's headless client through the
// Runtime API: the pure-core specs (spec/core/, which also run on Lua 5.5.1)
// against the installed library page, and the SilverBullet-only integration
// specs (sbtest/runtime/). One Playwright test per spec file.

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { expect, test } from "@playwright/test";
import { bundle, type SpecResults } from "./lib/bundle.ts";
import { repoRoot } from "./lib/server.ts";
import { eventually, readFile, runScript } from "./lib/sb.ts";

function specFiles(dir: string): string[] {
  const abs = join(repoRoot, dir);
  if (!existsSync(abs)) return [];
  return readdirSync(abs)
    .filter((f) => f.endsWith("_spec.lua"))
    .sort()
    .map((f) => join(dir, f));
}

const groups: [string, string, boolean][] = [
  ["core", "spec/core", false],
  ["runtime", "sbtest/runtime", true],
];

for (const [group, dir, withApi] of groups) {
  for (const file of specFiles(dir)) {
    test(`${group}: ${file}`, async () => {
      const source = readFileSync(join(repoRoot, file), "utf8");
      const results = await runScript<SpecResults>(bundle(source, withApi));
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

// CONFIG (sbtest/space/CONFIG.md) sets the complete list of task states, and
// Migrate/Runtime.md has a task in a state outside it: SilverBullet's own
// startup (once the scripts load) must have written it back to [ ], without touching
// the task whose state is listed.
test("startup: tasks in states CONFIG doesn't list go back to [ ]", async () => {
  const text = await eventually("Migrate/Runtime.md rewritten", async () => {
    const t = await readFile("Migrate/Runtime.md");
    return t.includes("* [ ] Lost at startup") ? t : undefined;
  });
  expect(text).toContain("* [TODO] Stays put");
});
