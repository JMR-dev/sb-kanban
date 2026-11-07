// Boards in a real browser against the real SilverBullet server. Each group
// works on its own fixture pages (sbtest/space/), and checks results in the
// page files themselves, through the server's HTTP file API.

import { expect, test } from "@playwright/test";
import { readFile, writeFile } from "../lib/sb.ts";
import {
  card,
  column,
  errorNotification,
  fileWhere,
  openBoard,
  pickInFilterBox,
  titlesIn,
} from "../lib/ui.ts";

test.describe("a board over several pages", () => {
  test("has a column per task state and a card per selected task", async ({ page }) => {
    await openBoard(page, "Boards/Projects");
    await expect(page.locator(".sbk-title")).toHaveText("Projects");
    await expect(page.locator(".sbk-column-title")).toHaveText(["To do", "TODO", "DOING", "Done"]);
    expect(await titlesIn(page, "To do")).toEqual(["Design the landing page"]);
    expect(await titlesIn(page, "TODO")).toEqual([
      "Write the API docs",
      "Build the web client",
      "Waits on a ghost",
      "Show <b>this</b> **literally**",
    ]);
    expect(await titlesIn(page, "DOING")).toEqual(["Ship the API"]);
    expect(await titlesIn(page, "Done")).toEqual(["Pick a database"]);
    // Four columns fit the editor width without scrolling sideways.
    await expect(column(page, "Done")).toBeInViewport();
  });

  test("shows task text literally", async ({ page }) => {
    await openBoard(page, "Boards/Projects");
    const title = card(page, "Show <b>this</b> **literally**").locator(".sbk-card-title");
    await expect(title).toHaveText("Show <b>this</b> **literally**");
    await expect(title.locator("b, strong")).toHaveCount(0);
  });

  test("badges show blockers, blocked tasks and broken links", async ({ page }) => {
    await openBoard(page, "Boards/Projects");
    await expect(card(page, "Write the API docs").locator('[data-badge="blocked"]')).toHaveText(
      "Blocked by 1",
    );
    // The database task is done, so only the API still blocks the web client.
    await expect(card(page, "Build the web client").locator('[data-badge="blocked"]')).toHaveText(
      "Blocked by 1",
    );
    await expect(card(page, "Ship the API").locator('[data-badge="blocks"]')).toHaveText(
      "Blocks 2",
    );
    await expect(card(page, "Waits on a ghost").locator('[data-badge="missing"]')).toHaveText(
      "Missing blocker",
    );
  });

  test("clicking a blocker badge opens the blocking task", async ({ page }) => {
    await openBoard(page, "Boards/Projects");
    await card(page, "Write the API docs").locator('[data-badge="blocked"]').click();
    await expect(page).toHaveURL(/Projects\/Backend/);
  });

  test("finishing a blocker on another page updates the board without a reload", async ({
    page,
  }) => {
    await openBoard(page, "Boards/Projects");
    const badge = card(page, "Write the API docs").locator('[data-badge="blocked"]');
    await expect(badge).toHaveCount(1);
    const backend = await readFile("Projects/Backend.md");
    await writeFile(
      "Projects/Backend.md",
      backend.replace("* [DOING] Ship the API", "* [x] Ship the API"),
    );
    await expect(badge).toHaveCount(0, { timeout: 45_000 });
    expect(await titlesIn(page, "Done")).toContain("Ship the API");
    await writeFile("Projects/Backend.md", backend);
  });
});

test.describe("moving cards", () => {
  test("dragging a card to another column changes its state in the page", async ({ page }) => {
    await openBoard(page, "Boards/Move");
    await card(page, "Drag me").dragTo(column(page, "DOING"));
    await fileWhere("Move/Tasks.md", "Drag me is DOING", (t) => t.includes("* [DOING] Drag me"));
    await expect(column(page, "DOING").locator('[data-card-title="Drag me"]')).toHaveCount(1, {
      timeout: 45_000,
    });
  });

  test("the Move to menu moves a card without a mouse drag", async ({ page }) => {
    await openBoard(page, "Boards/Move");
    await card(page, "Pick me from the menu").locator("select.sbk-move").selectOption({
      label: "Done",
    });
    await fileWhere("Move/Tasks.md", "picked task is done", (t) =>
      t.includes("* [x] Pick me from the menu"),
    );
  });

  test("a board on the same page as its tasks moves them through the editor", async ({ page }) => {
    await openBoard(page, "Boards/Here");
    await card(page, "Right here").dragTo(column(page, "DOING"));
    await fileWhere("Boards/Here.md", "Right here is DOING", (t) =>
      t.includes("* [DOING] Right here"),
    );
  });

  test("a card whose task moved meanwhile is never written to the wrong line", async ({
    page,
  }) => {
    await openBoard(page, "Boards/Move");
    const target = card(page, "Edited under me");
    await expect(target).toHaveCount(1);
    const before = await readFile("Move/Tasks.md");
    const shifted = before.replace("# Tasks to move\n", "# Tasks to move\n\n* [TODO] Pushed in\n");
    await writeFile("Move/Tasks.md", shifted);
    // Act right away, before the browser has synced the edit.
    await target.locator("select.sbk-move").selectOption({ label: "DOING" });
    const moved = shifted.replace("* [TODO] Edited under me", "* [DOING] Edited under me");
    // Either the move is refused with a notice (the index was stale) or it
    // lands on the right line (the browser had already synced); nothing else.
    await expect
      .poll(
        async () => {
          const text = await readFile("Move/Tasks.md");
          if (text === moved) return "moved";
          if (text === shifted && (await errorNotification(page).count()) > 0) return "refused";
          return text === shifted ? "pending" : `corrupted:\n${text}`;
        },
        { timeout: 30_000 },
      )
      .toMatch(/^(moved|refused)$/);
  });
});

test.describe("the blockDone rule", () => {
  test("refuses moving a blocked card to Done and leaves the page alone", async ({ page }) => {
    await openBoard(page, "Boards/Rule");
    const blocked = card(page, "Not allowed to finish");
    // Wait until the board knows about the blocker: the first index of a
    // space can still be running when the board first appears.
    await expect(blocked.locator('[data-badge="blocked"]')).toHaveText("Blocked by 1", {
      timeout: 45_000,
    });
    const before = await readFile("Rule/Tasks.md");
    await blocked.locator("select.sbk-move").selectOption({ label: "Done" });
    await expect(errorNotification(page)).toContainText("Blocked by 1 open task: Still going");
    expect(await readFile("Rule/Tasks.md")).toBe(before);
  });
});

test.describe("editing blockers from the board", () => {
  test("+ Blocker records the chosen task and gives it an anchor", async ({ page }) => {
    await openBoard(page, "Boards/Deps");
    await card(page, "Needs help").locator(".sbk-add-blocker").click();
    await pickInFilterBox(page, "Helper", "Helper task");
    const text = await fileWhere("Deps/Tasks.md", "Needs help has a blocker", (t) =>
      /\* \[TODO\] Needs help \[blockedBy: "\[\[\$helper-task-[0-9a-f]{4}\]\]"\]/.test(t),
    );
    const anchor = /\* \[TODO\] Helper task \$(helper-task-[0-9a-f]{4})\n/.exec(text)?.[1];
    expect(anchor, "the helper task got an anchor").toBeTruthy();
    expect(text).toContain(`* [TODO] Needs help [blockedBy: "[[$${anchor}]]"]`);
    await expect(card(page, "Needs help").locator('[data-badge="blocked"]')).toHaveText(
      "Blocked by 1",
      { timeout: 45_000 },
    );
  });

  test("− Blocker removes the chosen blocker", async ({ page }) => {
    await openBoard(page, "Boards/Deps");
    await card(page, "Has a blocker to drop").locator(".sbk-remove-blocker").click();
    await pickInFilterBox(page, "First", "First blocker");
    await fileWhere("Deps/Tasks.md", "one blocker left", (t) =>
      t.includes('* [TODO] Has a blocker to drop [blockedBy: "[[$deps-two]]"]'),
    );
  });
});

test.describe("extensions", () => {
  test("Lua decorators and service decorators add badges", async ({ page }) => {
    await openBoard(page, "Boards/Ext");
    const decorated = card(page, "Decorate me");
    await expect(decorated.locator('[data-badge="fromLua"]')).toHaveText("From Lua", {
      timeout: 45_000,
    });
    await expect(decorated.locator('[data-badge="fromService"]')).toHaveText("From a service");
  });

  test("a move-guard service can refuse a move", async ({ page }) => {
    await openBoard(page, "Boards/Ext");
    await expect(card(page, "Decorate me").locator('[data-badge="fromService"]')).toHaveCount(1, {
      timeout: 45_000,
    });
    const before = await readFile("Ext/Tasks.md");
    await card(page, "Guarded task").locator("select.sbk-move").selectOption({ label: "DOING" });
    await expect(errorNotification(page)).toContainText("Guarded by a service.");
    expect(await readFile("Ext/Tasks.md")).toBe(before);
  });
});

test.describe("defaults", () => {
  test("/kanban inserts a board with the columns written out", async ({ page }) => {
    // Load the library in this browser first (a fresh client loads scripts,
    // including the slash command, only after its first full index), then
    // open a page without a board: a board re-rendering on index updates can
    // close the completion popup. The page is created beforehand because
    // typing into a page that doesn't exist yet can lose keystrokes.
    const fence = "```";
    await openBoard(page, "Boards/Projects");
    await writeFile("Scratch/Slash.md", "# Slash board\n\n");
    await page.goto(`${process.env.SB_URL}/Scratch/Slash`);
    await expect(page.locator(".cm-content")).toContainText("Slash board", { timeout: 60_000 });
    await page.locator(".cm-line").last().click();
    await page.keyboard.press("End");
    await page.keyboard.type("/kan", { delay: 50 });
    const option = page.locator(".cm-tooltip-autocomplete li", {
      hasText: "Insert a kanban board with the default columns",
    });
    await option.click();
    await fileWhere("Scratch/Slash.md", "the board block", (t) =>
      t.includes(
        `${fence}kanban\npage: Scratch/Slash\ncolumns:\n  - To do\n  - TODO\n  - DOING\n  - Done\n${fence}`,
      ),
    );
  });

  test("removing a state from CONFIG sends its tasks back to [ ]", async ({ page }) => {
    const config = await readFile("CONFIG.md");
    // Put back afterwards too, so a repeated run starts unmigrated.
    const tasks = await readFile("Migrate/Tasks.md");
    await writeFile(
      "CONFIG.md",
      config.replace('  { name = "Retired", order = 10, done = true },\n', ""),
    );
    try {
      // A fresh start of the client loads the scripts, which runs the check.
      await openBoard(page, "Boards/Projects");
      const text = await fileWhere("Migrate/Tasks.md", "Old task back to [ ]", (t) =>
        t.includes("* [ ] Old task"),
      );
      expect(text).toContain("* [TODO] Still here");
    } finally {
      await writeFile("CONFIG.md", config);
      await writeFile("Migrate/Tasks.md", tasks);
    }
  });
});
