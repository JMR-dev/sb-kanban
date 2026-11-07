---
name: Library/JMR-dev/Kanban
tags: meta/library
description: Kanban boards for SilverBullet tasks, with drag-and-drop and cross-page blockers.
author: JMR-dev
license: Apache-2.0
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
where you put a `kanban` block. The quickest way is to type `/kanban` on an
empty line (or run **Kanban: Insert board**), which inserts a board for the
current page with its columns written out:

    ```kanban
    page: My board
    columns:
      - Backlog
      - Ready for Development
      - In Progress
      - Blocked
      - Cancelled
      - Done
    ```

Move the cursor out of the block to see the board (a board right at the top of a page shows as source until you click below it, so give the page a heading first).

* **Drag a card** to another column, or use its **Move to…** menu, to change the task's state (`* [Backlog] …` becomes `* [In Progress] …`).
* Click the page name on a card to open the task.
* Boards update by themselves when tasks change anywhere in the space.

## Options
All options are optional; with none, the board shows every task in the space, in the default columns.

| Option | Meaning |
|---|---|
| `title` | Shown above the board. |
| `page` | Only tasks on this page (or any page in a list). |
| `pagePrefix` | Only tasks on pages starting with this (or any prefix in a list), e.g. `Projects/`. |
| `tag` | Only tasks with this tag (or any tag in a list). |
| `includeDone` | `false` hides done tasks, and the Cancelled and Done columns. Default `true`. |
| `columns` | Which columns to show, in order (see below). Default: the default columns. |
| `rules.blockDone` | `true` refuses moving a card into a done column while it has open blockers. |

Filters combine: `pagePrefix: Projects/` with `tag: urgent` shows urgent tasks under `Projects/`.

## Columns
The default columns follow the task states (see below): **Backlog** (which also holds plain `[ ]` tasks), **Ready for Development**, **In Progress**, **Blocked**, **Cancelled**, and **Done** (`[x]`, plus any other done state without a column of its own). Cards dropped on Backlog become `[Backlog]`; on Done, `[x]`.

In a board's `columns` list, a name means that default column, so **deleting a name from the list removes that column** from the board. Reorder the names to reorder the columns. For anything else, describe a column as a table:

    ```kanban
    page: Projects/Website
    columns:
      - In Progress
      - state: Blocked
        title: Waiting
      - states: [x, Cancelled]
        title: Closed
        dropState: x
    ```

A name that isn't a default column means a column for that state. A column with several `states` shows all of them; dropping a card on it writes its `dropState` (default: the first state). Tasks in states that no column takes are counted under the board.

# Task states
The library gives every space these task states (Done, `[x]`, is built into SilverBullet):

| State | `order` | Notes |
|---|---|---|
| Backlog | 0 | Its column also holds plain `[ ]` tasks (`todo = true`). |
| Ready for Development | 1 | |
| In Progress | 2 | |
| Blocked | 3 | |
| Cancelled | 4 | Counts as done (so it unblocks tasks waiting on it), but keeps its own column (`done = true, column = true`). |

To change them, run **Kanban: Customize task states**. It adds the current list to your CONFIG, ready to edit:

    kanban.taskStates {
      { name = "Backlog", order = 0, todo = true },
      { name = "Ready for Development", order = 1 },
      ...
    }

That list is then the complete set of task states. **Deleting a line removes the state**, and once you run **System: Reload**, tasks still in it go back to `[ ]` (also available as **Kanban: Move tasks in removed states to [ ]**). Add lines for your own states. An empty list (`kanban.taskStates {}`) goes back to the defaults. Run **System: Reload** after editing CONFIG.

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
