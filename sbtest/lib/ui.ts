// Browser helpers for the board tests (sbtest/ui/).

import { expect, type Locator, type Page } from "@playwright/test";
import { eventually, readFile, sbUrl } from "./sb.ts";

/** Counts the SilverBullet client's finished boots in `page`: its first load
 * and every reload. The client logs a "[Boot] boot-start=..." summary once a
 * boot is done. Call this before the first navigation; the function it
 * returns waits until that many boots have finished. */
export function countBoots(page: Page): (count: number) => Promise<void> {
  let boots = 0;
  page.on("console", (message) => {
    if (message.text().includes("[Boot] boot-start=")) boots++;
  });
  return async (count) => {
    await expect
      .poll(() => boots, { message: `${count} finished client boot(s)`, timeout: 60_000 })
      .toBeGreaterThanOrEqual(count);
  };
}

/** Opens a page of the test space and waits until a board is drawn. */
export async function openBoard(page: Page, path: string): Promise<void> {
  await page.goto(`${sbUrl()}/${path.split("/").map(encodeURIComponent).join("/")}`);
  await expect(page.locator(".sbk-board").first()).toBeVisible({ timeout: 60_000 });
}

export function column(page: Page, title: string): Locator {
  return page.locator(`.sbk-column[data-column-title="${title}"]`);
}

export function card(page: Page, title: string): Locator {
  return page.locator(`.sbk-card[data-card-title="${title}"]`);
}

/** The card titles in a column, top to bottom. */
export async function titlesIn(page: Page, columnTitle: string): Promise<string[]> {
  return column(page, columnTitle)
    .locator(".sbk-card")
    .evaluateAll((els) => els.map((e) => (e as HTMLElement).dataset.cardTitle ?? ""));
}

/** Waits until a space file satisfies `check`, and returns its text. */
export async function fileWhere(
  path: string,
  what: string,
  check: (text: string) => boolean,
): Promise<string> {
  return eventually(`${path}: ${what}`, async () => {
    const text = await readFile(path);
    return check(text) ? text : undefined;
  });
}

/** Picks an option in SilverBullet's filter box (used by the blocker buttons). */
export async function pickInFilterBox(page: Page, search: string, option: string): Promise<void> {
  const input = page.locator(".sb-filter-input");
  await expect(input).toBeVisible();
  await input.click();
  await page.keyboard.type(search);
  await page.locator(".sb-option", { hasText: option }).first().click();
}

export function errorNotification(page: Page): Locator {
  return page.locator(".sb-notifications .sb-notification-error");
}
