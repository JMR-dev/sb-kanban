import { defineConfig } from "@playwright/test";

// Every test talks to one real SilverBullet server (sbtest/global-setup.ts).
// Tests share its space and its single headless Runtime API client, so they
// run one at a time, and each spec file works on its own fixture pages.
export default defineConfig({
  testDir: "sbtest",
  globalSetup: "./sbtest/global-setup.ts",
  globalTeardown: "./sbtest/global-teardown.ts",
  workers: 1,
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: 0,
  timeout: 120_000,
  expect: { timeout: 30_000 },
  reporter: process.env.CI ? [["list"], ["html", { open: "never" }]] : [["list"]],
  use: {
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  projects: [
    // Lua specs executed inside SilverBullet through the Runtime API.
    { name: "runtime", testMatch: /runtime\.spec\.ts$/ },
    // Browser tests of the boards.
    { name: "ui", testMatch: /ui\/.*\.spec\.ts$/ },
  ],
});
