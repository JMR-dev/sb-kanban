---
name: Library/JMR-dev/Kanban
tags: meta/library
description: Kanban boards for SilverBullet tasks, with drag-and-drop and cross-page blockers.
author: JMR-dev
license: AGPL-3.0-or-later
website: https://github.com/JMR-dev/sb-kanban
version: "{{version}}"
---
Kanban boards for your tasks. A board is a view: cards are your ordinary
markdown tasks, wherever they live, and moving a card changes the task's state
in its page. Tasks can block other tasks across pages.

> **note** Generated page
> This page is generated from the [sb-kanban repository](https://gitea.jasonmross.dev/JMR-dev/sb-kanban) (version {{version}}). Edit the sources there, not here: updating the library replaces this page. Requires SilverBullet 2.12.

# Boards
Installing this library adds no board by itself: a board appears on any page
where you put a `kanban` block. For example, on a new page:

    # My board

    * [ ] A task
    * [x] A finished task

    ```kanban
    page: My board
    ```

Put a `kanban` block on any page:

    ```kanban
    title: Website
    pagePrefix: Projects/Website/
    ```

Move the cursor out of the block to see the board (a board right at the top of a page shows as source until you click below it, so give the page a heading first).

* **Drag a card** to another column, or use its **Move to…** menu, to change the task's state (`* [TODO] …` becomes `* [DOING] …`).
* Click the page name on a card to open the task.
* Boards update by themselves when tasks change anywhere in the space.

## Options
All options are optional; with none, the board shows every task in the space.

| Option | Meaning |
|---|---|
| `title` | Shown above the board. |
| `page` | Only tasks on this page (or any page in a list). |
| `pagePrefix` | Only tasks on pages starting with this (or any prefix in a list), e.g. `Projects/`. |
| `tag` | Only tasks with this tag (or any tag in a list). |
| `includeDone` | `false` hides done tasks and the Done column. Default `true`. |
| `columns` | Which columns to show, in order (see below). Default: one per task state. |
| `rules.blockDone` | `true` refuses moving a card into a done column while it has open blockers. |

Filters combine: `pagePrefix: Projects/` with `tag: urgent` shows urgent tasks under `Projects/`.

## Columns
By default there is a **To do** column (`[ ]`), one column per state you defined with [[^Library/Std/APIs/Task State|taskState.define]] (in their `order`), and one **Done** column holding every done state (`[x]` and states defined with `done = true`). Cards dropped on Done become `[x]`.

To choose columns yourself, list states, or tables:

    ```kanban
    page: Projects/Website
    columns:
      - TODO
      - state: DOING
        title: In progress
      - states: [x, SHIPPED]
        title: Done
        dropState: SHIPPED
    ```

A column with several `states` shows all of them; dropping a card on it writes its `dropState` (default: the first state). Tasks in states that no column takes are counted under the board.

# Blockers
A task names the tasks it waits for in a `blockedBy` attribute, by [anchor](https://silverbullet.md/Markdown/Anchor):

    * [DOING] Ship the API $api-v2
    * [TODO] Build the web client [blockedBy: "[[$api-v2]]"]
    * [TODO] Launch [blockedBy: ["[[$api-v2]]", "[[$docs]]"]]

Blockers can be on any page, so they work across boards. Cards show:

* **Blocked by N**: open blockers (click to open one).
* **Blocks N**: tasks waiting for this one (click to open one).
* **Missing blocker**, **Bad blockedBy**, **Dependency cycle**: links to anchors that don't exist, values that aren't anchor links, and tasks that end up blocking themselves.

Use **+ Blocker** on a card to pick the task it waits for; a task without an anchor gets one (`$ship-the-api-3f2a`). **− Blocker** removes one. With `rules.blockDone: true` a blocked card can't be moved to Done.

# Lua API
The same options work from [Space Lua](https://silverbullet.md/Space%20Lua), which also lets you pick the tasks with a query:

    ${kanban.board {
      title = "Due this week",
      tasks = query[[from t = index.tasks() where t.due and t.due < "2026-11-01"]],
    }}

`tasks` replaces the `page`/`pagePrefix`/`tag` filters; blockers still resolve against every task.

## Extensions
Other Space Lua code (at the default priority) can add card badges and move rules:

    kanban.defineDecorator {
      name = "my.due",
      decorate = function(card, ctx)
        if card.task.name:find("urgent") then
          return { { kind = "urgent", text = "Urgent", tone = "warn" } }
        end
      end,
    }

    kanban.defineMoveGuard {
      name = "my.noFriday",
      check = function(move, ctx)
        if move.to.done and os.date("%A") == "Friday" then
          return false, "No shipping on Fridays."
        end
        return true
      end,
    }

### From a plug or a service
Code that isn't Space Lua (such as a TypeScript plug) extends boards through SilverBullet [services](https://silverbullet.md/API/service). Discovery data is `{ apiVersion }`, so a provider can decline versions it doesn't know.

* `kanban:decorator` is invoked once per board with a plain snapshot `{ apiVersion, title, columns, cards }` (`cards` keyed by card id). It returns `{ [cardId] = { badge, ... } }`.
* `kanban:moveGuard` is invoked once per move with `{ card, from, to, targetState }`. It returns `{ allowed = false, reason = "..." }` to refuse.

From Space Lua that is `service.define { selector = "kanban:decorator", match = { priority = 1 }, run = function(snapshot) ... end }`. A plug answers the `discover:kanban:decorator` event with `{ id = "<its id>", priority = 1 }` and handles `service:<its id>`.

A badge is `{ kind, text, title?, tone?, refs? }` (`tone` is `info`, `warn`, `error` or `ok`; `refs` are task refs the badge opens). A card has `id`, `title`, `page`, `done`, `task` (`state`, `name`, `tags`, `anchor`, `blockedBy`) and `deps` (`blockers`, `blocks`, `openBlockers`, `missing`, `inCycle`). Decorators run by `priority` (highest first); a failing one is reported on the board instead of breaking it. `kanban.apiVersion` changes only when this API breaks.

# Implementation
{{implementation}}
