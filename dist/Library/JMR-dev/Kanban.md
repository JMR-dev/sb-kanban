---
name: Library/JMR-dev/Kanban
tags: meta/library
description: Kanban boards for SilverBullet tasks, with drag-and-drop and cross-page blockers.
author: JMR-dev
license: AGPL-3.0-or-later
website: https://gitea.jasonmross.dev/JMR-dev/sb-kanban
version: "0.1.0"
---
Kanban boards for your tasks. A board is a view: cards are your ordinary
markdown tasks, wherever they live, and moving a card changes the task's state
in its page. Tasks can block other tasks across pages.

> **note** Generated page
> This page is generated from the [sb-kanban repository](https://gitea.jasonmross.dev/JMR-dev/sb-kanban) (version 0.1.0). Edit the sources there, not here: updating the library replaces this page. Requires SilverBullet 2.12.

# Boards
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
A task names the tasks it waits for in a `blockedBy` attribute, by [[Markdown/Anchor|anchor]]:

    * [DOING] Ship the API $api-v2
    * [TODO] Build the web client [blockedBy: "[[$api-v2]]"]
    * [TODO] Launch [blockedBy: ["[[$api-v2]]", "[[$docs]]"]]

Blockers can be on any page, so they work across boards. Cards show:

* **Blocked by N**: open blockers (click to open one).
* **Blocks N**: tasks waiting for this one (click to open one).
* **Missing blocker**, **Bad blockedBy**, **Dependency cycle**: links to anchors that don't exist, values that aren't anchor links, and tasks that end up blocking themselves.

Use **+ Blocker** on a card to pick the task it waits for; a task without an anchor gets one (`$ship-the-api-3f2a`). **− Blocker** removes one. With `rules.blockDone: true` a blocked card can't be moved to Done.

# Lua API
The same options work from [[Space Lua]], which also lets you pick the tasks with a query:

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

A badge is `{ kind, text, title?, tone?, refs? }` (`tone` is `info`, `warn`, `error` or `ok`; `refs` are task refs the badge opens). A card has `id`, `title`, `page`, `done`, `task` (`state`, `name`, `tags`, `anchor`, `blockedBy`) and `deps` (`blockers`, `blocks`, `openBlockers`, `missing`, `inCycle`). Decorators run by `priority` (highest first); a failing one is reported on the board instead of breaking it. `kanban.apiVersion` changes only when this API breaks.

# Implementation
### src/core/builtins.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- The built-in decorator and move guard. They use the same extension points
-- as third-party extensions (kanban.defineDecorator / kanban.defineMoveGuard),
-- which register them in src/sb/register.lua.

kanban = kanban or {}
kanban.builtins = kanban.builtins or {}
local builtins = kanban.builtins

local function names(list)
  return table.concat(
    kanban.util.map(list, function(t)
      return t.name
    end),
    ", "
  )
end

local function refs(list)
  return kanban.util.map(list, function(t)
    return t.ref
  end)
end

local function plural(n, one, many)
  if n == 1 then
    return one
  end
  return many
end

---Badges for blockers, blocked tasks, broken links and cycles.
---@type kanban.Decorator
builtins.dependencies = {
  name = "kanban.dependencies",
  priority = 100,
  decorate = function(card, ctx)
    local d = card.deps
    local badges = {}
    local open = kanban.util.filter(d.blockers, function(t)
      return not ctx.isDone(t.state)
    end)
    if #open > 0 then
      badges[#badges + 1] = {
        kind = "blocked",
        tone = "warn",
        text = "Blocked by " .. #open,
        title = "Waiting on: " .. names(open),
        refs = refs(open),
      }
    end
    if #d.blocks > 0 then
      badges[#badges + 1] = {
        kind = "blocks",
        tone = "info",
        text = "Blocks " .. #d.blocks,
        title = "Blocking: " .. names(d.blocks),
        refs = refs(d.blocks),
      }
    end
    if #d.missing > 0 then
      local links = kanban.util.map(d.missing, function(a)
        return "$" .. a
      end)
      badges[#badges + 1] = {
        kind = "missing",
        tone = "error",
        text = "Missing " .. plural(#d.missing, "blocker", "blockers"),
        title = "No task has the anchor " .. table.concat(links, ", "),
      }
    end
    if #d.badLinks > 0 then
      badges[#badges + 1] = {
        kind = "badLink",
        tone = "error",
        text = "Bad blockedBy",
        title = "blockedBy values must be anchor links like [[$name]]: "
          .. table.concat(d.badLinks, ", "),
      }
    end
    if d.inCycle then
      badges[#badges + 1] = {
        kind = "cycle",
        tone = "error",
        text = "Dependency cycle",
        title = "This task is (indirectly) blocked by itself.",
      }
    end
    return badges
  end,
}

---Refuses moving a card into a done column while it has open blockers, when
---the board's `rules.blockDone` is on.
---@type kanban.MoveGuard
builtins.blockDone = {
  name = "kanban.blockDone",
  priority = 100,
  check = function(move, ctx)
    if not (ctx.model.rules.blockDone and move.to.done) then
      return true
    end
    local open = kanban.util.filter(move.card.deps.blockers, function(t)
      return not kanban.states.isDone(t.state, ctx.states)
    end)
    if #open == 0 then
      return true
    end
    return false,
      "Blocked by " .. #open .. " open " .. plural(#open, "task", "tasks") .. ": " .. names(open)
  end,
}
```

### src/core/columns.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- A board's columns: given explicitly in the board options, or derived from
-- the task states (to do, each custom not-done state, then one Done column
-- that collects every done state and receives drops as "x").

kanban = kanban or {}
kanban.columns = kanban.columns or {}
local columns = kanban.columns

---@class kanban.Column
---@field id string
---@field title string
---@field states string[]
---@field dropState string
---@field done boolean every state in the column is a done state

local defaultTitles = { [" "] = "To do", x = "Done", X = "Done" }

local function titleFor(states)
  return defaultTitles[states[1]] or states[1]
end

---@param spec kanban.Spec
---@param normalized kanban.States
---@return kanban.Column[]
function columns.build(spec, normalized)
  local out = {}
  local function add(title, list, dropState)
    local done = true
    for _, s in ipairs(list) do
      if not kanban.states.isDone(s, normalized) then
        done = false
      end
    end
    if done and not spec.includeDone then
      return
    end
    out[#out + 1] = {
      id = tostring(#out + 1),
      title = title,
      states = list,
      dropState = dropState,
      done = done,
    }
  end

  if spec.columns then
    for _, c in ipairs(spec.columns) do
      add(c.title or titleFor(c.states), c.states, c.dropState)
    end
    return out
  end

  local doneStates = {}
  for _, s in ipairs(normalized.list) do
    if s.done then
      doneStates[#doneStates + 1] = s.name
    else
      add(titleFor { s.name }, { s.name }, s.name)
    end
  end
  -- "x" first so that drops into Done write "x". The comparator must be a
  -- strict ordering (cmp(a, a) == false): Space Lua's sort never returns
  -- otherwise.
  table.sort(doneStates, function(a, b)
    if a == b then
      return false
    elseif a == "x" or b == "x" then
      return a == "x"
    end
    return a < b
  end)
  add("Done", doneStates, "x")
  return out
end

---The column a state belongs to, or nil.
---@param list kanban.Column[]
---@param state string
---@return kanban.Column|nil
function columns.forState(list, state)
  for _, c in ipairs(list) do
    if kanban.util.contains(c.states, state) then
      return c
    end
  end
  return nil
end
```

### src/core/config.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- Board options, from a `kanban` fenced block (parsed YAML) or a Lua table
-- passed to `kanban.board`. Validation collects every problem so a board can
-- show them all at once. No option is called `query` or `using`: those are
-- keywords in Space Lua.

kanban = kanban or {}
kanban.config = kanban.config or {}
local config = kanban.config

---@class kanban.ColumnSpec
---@field title string|nil
---@field states string[]
---@field dropState string

---@class kanban.Spec
---@field title string|nil
---@field pages string[]
---@field pagePrefixes string[]
---@field tags string[]
---@field includeDone boolean
---@field columns kanban.ColumnSpec[]|nil nil means "derive from task states"
---@field rules { blockDone: boolean }
---@field tasks table[]|nil Lua API only: rows to use instead of index.tasks()

local known = {
  title = true,
  page = true,
  pagePrefix = true,
  tag = true,
  includeDone = true,
  columns = true,
  rules = true,
  tasks = true,
}

local function stringList(v, name, errors)
  local list = kanban.util.asList(v)
  if type(v) == "table" or v == nil or type(v) == "string" then
    for _, item in ipairs(list) do
      if type(item) ~= "string" then
        errors[#errors + 1] = "`" .. name .. "` must be a string or a list of strings"
        return {}
      end
    end
    return list
  end
  errors[#errors + 1] = "`" .. name .. "` must be a string or a list of strings"
  return {}
end

local function columnSpec(entry, i, errors)
  if type(entry) == "string" then
    return { states = { entry }, dropState = entry }
  elseif type(entry) ~= "table" then
    errors[#errors + 1] = "column " .. i .. " must be a state name or a table"
    return nil
  end
  local list = {}
  if entry.state ~= nil then
    list[#list + 1] = entry.state
  end
  for _, s in ipairs(kanban.util.asList(entry.states)) do
    if not kanban.util.contains(list, s) then
      list[#list + 1] = s
    end
  end
  if #list == 0 then
    errors[#errors + 1] = "column " .. i .. " needs `state` or `states`"
    return nil
  end
  for _, s in ipairs(list) do
    if type(s) ~= "string" then
      errors[#errors + 1] = "column " .. i .. ": states must be strings"
      return nil
    end
  end
  if entry.title ~= nil and type(entry.title) ~= "string" then
    errors[#errors + 1] = "column " .. i .. ": `title` must be a string"
  end
  local dropState = entry.dropState or list[1]
  if not kanban.util.contains(list, dropState) then
    errors[#errors + 1] = "column " .. i .. ": `dropState` must be one of its states"
    dropState = list[1]
  end
  return { title = entry.title, states = list, dropState = dropState }
end

---Validates and normalizes board options.
---@param raw table|nil
---@return kanban.Spec spec
---@return string[] errors
function config.normalize(raw)
  local errors = {}
  if raw ~= nil and type(raw) ~= "table" then
    return config.normalize(nil), { "board options must be a table (YAML mapping)" }
  end
  raw = raw or {}
  for _, key in ipairs(kanban.util.sortedKeys(raw)) do
    if not known[key] then
      errors[#errors + 1] = "unknown option `" .. tostring(key) .. "`"
    end
  end

  local spec = {
    title = nil,
    pages = stringList(raw.page, "page", errors),
    pagePrefixes = stringList(raw.pagePrefix, "pagePrefix", errors),
    tags = stringList(raw.tag, "tag", errors),
    includeDone = true,
    columns = nil,
    rules = { blockDone = false },
    tasks = nil,
  }

  if raw.title ~= nil then
    if type(raw.title) == "string" then
      spec.title = raw.title
    else
      errors[#errors + 1] = "`title` must be a string"
    end
  end
  if raw.includeDone ~= nil then
    if type(raw.includeDone) == "boolean" then
      spec.includeDone = raw.includeDone
    else
      errors[#errors + 1] = "`includeDone` must be true or false"
    end
  end
  if raw.columns ~= nil then
    if type(raw.columns) ~= "table" then
      errors[#errors + 1] = "`columns` must be a list"
    else
      spec.columns = {}
      for i, entry in ipairs(raw.columns) do
        local c = columnSpec(entry, i, errors)
        if c then
          spec.columns[#spec.columns + 1] = c
        end
      end
    end
  end
  if raw.rules ~= nil then
    if type(raw.rules) ~= "table" then
      errors[#errors + 1] = "`rules` must be a table"
    else
      for _, key in ipairs(kanban.util.sortedKeys(raw.rules)) do
        if key ~= "blockDone" then
          errors[#errors + 1] = "unknown rule `" .. tostring(key) .. "`"
        end
      end
      if raw.rules.blockDone ~= nil then
        if type(raw.rules.blockDone) == "boolean" then
          spec.rules.blockDone = raw.rules.blockDone
        else
          errors[#errors + 1] = "`rules.blockDone` must be true or false"
        end
      end
    end
  end
  if raw.tasks ~= nil then
    if type(raw.tasks) == "table" then
      spec.tasks = raw.tasks
    else
      errors[#errors + 1] = "`tasks` must be a list of tasks"
    end
  end
  return spec, errors
end
```

### src/core/deps.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- Dependencies between tasks, across every page (and so across boards): a
-- task's `blockedBy` attribute names other tasks by anchor
-- (`[blockedBy: "[[$api-v2]]"]` or a list of such links).

kanban = kanban or {}
kanban.deps = kanban.deps or {}
local deps = kanban.deps

---@class kanban.Deps
---@field blockers kanban.Task[] tasks this one is blocked by
---@field blocks kanban.Task[] tasks blocked by this one
---@field missing string[] blockedBy anchors that match no task
---@field badLinks string[] blockedBy values that are not anchor links
---@field openBlockers integer blockers not in a done state
---@field inCycle boolean part of a blockedBy cycle

local function empty()
  return {
    blockers = {},
    blocks = {},
    missing = {},
    badLinks = {},
    openBlockers = 0,
    inCycle = false,
  }
end

-- Marks every task on a cycle (Tarjan's strongly connected components; a
-- component of two or more tasks, or a task blocked by itself, is a cycle).
local function markCycles(list, byRef)
  local index, low, onStack, stack = {}, {}, {}, {}
  local counter = 0
  local function connect(task)
    counter = counter + 1
    index[task.ref], low[task.ref] = counter, counter
    stack[#stack + 1] = task
    onStack[task.ref] = true
    for _, blocker in ipairs(byRef[task.ref].blockers) do
      if index[blocker.ref] == nil then
        connect(blocker)
        low[task.ref] = math.min(low[task.ref], low[blocker.ref])
      elseif onStack[blocker.ref] then
        low[task.ref] = math.min(low[task.ref], index[blocker.ref])
      end
    end
    if low[task.ref] == index[task.ref] then
      local component = {}
      while true do
        local t = table.remove(stack)
        onStack[t.ref] = nil
        component[#component + 1] = t
        if t.ref == task.ref then
          break
        end
      end
      local selfLoop = false
      for _, b in ipairs(byRef[task.ref].blockers) do
        if b.ref == task.ref then
          selfLoop = true
        end
      end
      if #component > 1 or selfLoop then
        for _, t in ipairs(component) do
          byRef[t.ref].inCycle = true
        end
      end
    end
  end
  for _, task in ipairs(list) do
    if index[task.ref] == nil then
      connect(task)
    end
  end
end

---Resolves `blockedBy` links over all tasks.
---@param list kanban.Task[] every task in the space
---@param isDone fun(state: string): boolean
---@return table<string, kanban.Deps> by task ref
function deps.resolve(list, isDone)
  local byAnchor, byRef = {}, {}
  for _, task in ipairs(list) do
    byRef[task.ref] = empty()
    if task.anchor then
      byAnchor[task.anchor] = task
    end
  end
  for _, task in ipairs(list) do
    local d = byRef[task.ref]
    for _, link in ipairs(task.badLinks or {}) do
      d.badLinks[#d.badLinks + 1] = link
    end
    for _, anchor in ipairs(task.blockedBy) do
      local blocker = byAnchor[anchor]
      if blocker == nil then
        d.missing[#d.missing + 1] = anchor
      elseif not kanban.util.contains(d.blockers, blocker) then
        d.blockers[#d.blockers + 1] = blocker
        local bd = byRef[blocker.ref]
        bd.blocks[#bd.blocks + 1] = task
        if not isDone(blocker.state) then
          d.openBlockers = d.openBlockers + 1
        end
      end
    end
  end
  markCycles(list, byRef)
  return byRef
end
```

### src/core/edit.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- Pure edits of one task line (`* [STATE] name [key: value] $anchor`):
-- reading and rewriting the `blockedBy` attribute and adding an anchor.
-- SilverBullet 2.12 has no object API for this, so the adapter
-- (src/sb/write.lua) splices these lines into pages after checking that the
-- indexed range still holds the expected line.

kanban = kanban or {}
kanban.edit = kanban.edit or {}
local edit = kanban.edit

local anchorPattern = "%$([%a_][%w_/:%-]*)"

---Splits a task line into the part up to "[", the state, and the rest
---(after "]"), or returns nil for a line that is not a task.
---@param line string
---@return { prefix: string, state: string, rest: string }|nil
function edit.parse(line)
  local prefix, state, rest = string.match(line, "^(%s*[%*%-%+]%s+%[)([^%]]*)%](.*)$")
  if prefix == nil then
    prefix, state, rest = string.match(line, "^(%s*%d+[%.%)]%s+%[)([^%]]*)%](.*)$")
  end
  if prefix == nil then
    return nil
  end
  return { prefix = prefix, state = state, rest = rest }
end

---The start and end index of the `[key: ...]` attribute in `line`, honouring
---nested brackets and quoted strings, or nil.
---@param line string
---@param key string
---@return integer|nil, integer|nil
function edit.attributeSpan(line, key)
  local search = 1
  while true do
    local s, e = string.find(line, "[" .. key .. ":", search, true)
    if s == nil then
      return nil
    end
    -- "[[key:" would be a wiki link, not an attribute.
    if string.sub(line, s - 1, s - 1) ~= "[" then
      local depth, quote, i = 0, nil, s
      while i <= #line do
        local c = string.sub(line, i, i)
        if quote then
          if c == "\\" then
            i = i + 1
          elseif c == quote then
            quote = nil
          end
        elseif c == '"' or c == "'" then
          quote = c
        elseif c == "[" then
          depth = depth + 1
        elseif c == "]" then
          depth = depth - 1
          if depth == 0 then
            return s, i
          end
        end
        i = i + 1
      end
      return nil
    end
    search = e + 1
  end
end

---The anchor names in the line's `blockedBy` attribute, in order.
---@param line string
---@return string[]
function edit.blockedByOf(line)
  local s, e = edit.attributeSpan(line, "blockedBy")
  local out = {}
  if s then
    for name in string.gmatch(string.sub(line, s, e), anchorPattern) do
      out[#out + 1] = name
    end
  end
  return out
end

---The task's own anchor (`$name` outside brackets), or nil.
---@param line string
---@return string|nil
function edit.anchorOf(line)
  local parsed = edit.parse(line)
  local rest = parsed and parsed.rest or line
  -- Drop wiki links and attributes, which may contain `$name` themselves.
  local outside = string.gsub(rest, "%b[]", " ")
  return string.match(" " .. outside, "%s" .. anchorPattern)
end

---@param anchors string[]
---@return string
function edit.renderBlockedBy(anchors)
  local links = kanban.util.map(anchors, function(a)
    return '"[[$' .. a .. ']]"'
  end)
  if #links == 1 then
    return "[blockedBy: " .. links[1] .. "]"
  end
  return "[blockedBy: [" .. table.concat(links, ", ") .. "]]"
end

-- Inserts `text` at the end of the line, before a trailing `$anchor` if any.
local function insertBeforeTrailingAnchor(line, text)
  local body, anchor = string.match(line, "^(.-)(%s+%$[%a_][%w_/:%-]*)%s*$")
  if body then
    return body .. " " .. text .. anchor
  end
  return (string.gsub(line, "%s+$", "")) .. " " .. text
end

---Sets the line's `blockedBy` attribute to exactly `anchors` (removing it
---when the list is empty).
---@param line string
---@param anchors string[]
---@return string
function edit.setBlockedBy(line, anchors)
  local s, e = edit.attributeSpan(line, "blockedBy")
  if s == nil then
    if #anchors == 0 then
      return line
    end
    return insertBeforeTrailingAnchor(line, edit.renderBlockedBy(anchors))
  end
  local before, after = string.sub(line, 1, s - 1), string.sub(line, e + 1)
  if #anchors > 0 then
    return before .. edit.renderBlockedBy(anchors) .. after
  end
  before = string.gsub(before, "%s+$", "")
  if after == "" or string.match(after, "^%s") then
    return before .. after
  end
  return before .. " " .. after
end

---Adds ` $id` unless the line already has an anchor. Returns the new line and
---the anchor the task now has.
---@param line string
---@param id string
---@return string, string
function edit.addAnchor(line, id)
  local existing = edit.anchorOf(line)
  if existing then
    return line, existing
  end
  return (string.gsub(line, "%s+$", "")) .. " $" .. id, id
end
```

### src/core/ids.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- Anchor names for tasks that get linked from the board: a readable slug of
-- the task name plus a short random suffix (`ship-the-api-3f2a`). Anchors must
-- be unique across the whole space.

kanban = kanban or {}
kanban.ids = kanban.ids or {}
local ids = kanban.ids

---Whether `name` is a valid SilverBullet anchor name.
---@param name any
---@return boolean
function ids.isValid(name)
  return type(name) == "string" and string.match(name, "^[%a_][%w_/:%-]*$") ~= nil
end

---A lower-case, dash-separated slug of a task name (at most 24 characters,
---starting with a letter).
---@param name string|nil
---@return string
function ids.slug(name)
  local s = string.lower(name or "")
  s = string.gsub(s, "[^%w]+", "-")
  s = string.gsub(s, "^%-+", "")
  s = string.sub(s, 1, 24)
  s = string.gsub(s, "%-+$", "")
  if s == "" then
    return "task"
  elseif not string.match(s, "^%a") then
    return "t-" .. s
  end
  return s
end

---A new anchor name for a task called `name` that is not in `taken`.
---@param name string|nil
---@param taken table<string, boolean>
---@param random (fun(m: integer, n: integer): integer)|nil defaults to math.random
---@return string
function ids.new(name, taken, random)
  random = random or math.random
  local hex = "0123456789abcdef"
  local base = ids.slug(name)
  for _ = 1, 100 do
    local digits = {}
    for i = 1, 4 do
      local k = random(1, 16)
      digits[i] = string.sub(hex, k, k)
    end
    local id = base .. "-" .. table.concat(digits)
    if not taken[id] then
      return id
    end
  end
  error("could not find a free anchor name for " .. base)
end
```

### src/core/model.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- The board model: columns holding cards, built from all tasks in the space
-- (dependencies cross pages, and so boards) and a normalized board spec.
-- Decorators then add badges to cards; the built-in dependency badges are one
-- (src/core/builtins.lua), and extensions add more.

kanban = kanban or {}
kanban.model = kanban.model or {}
local model = kanban.model

---@class kanban.Badge
---@field kind string
---@field text string
---@field title string|nil tooltip
---@field tone "info"|"warn"|"error"|"ok"|nil
---@field refs string[]|nil task refs the badge points at (for click-through)

---@class kanban.Card
---@field id string the task ref
---@field task kanban.Task
---@field title string
---@field page string
---@field done boolean
---@field deps kanban.Deps
---@field column string|nil column id; nil when no column takes its state
---@field badges kanban.Badge[]

---@class kanban.Decorator
---@field name string
---@field priority number|nil higher runs first (default 0)
---@field decorate fun(card: kanban.Card, ctx: table): kanban.Badge[]|nil

---@class kanban.Model
---@field title string|nil
---@field columns (kanban.Column|{ cards: kanban.Card[] })[]
---@field unplaced kanban.Card[] selected tasks whose state no column takes
---@field cards table<string, kanban.Card>
---@field rules { blockDone: boolean }
---@field states kanban.States
---@field errors string[] problems found while building (e.g. a failing decorator)

local function byPriority(list)
  local sorted = {}
  for i, v in ipairs(list or {}) do
    sorted[i] = v
  end
  table.sort(sorted, function(a, b)
    local pa, pb = a.priority or 0, b.priority or 0
    if pa ~= pb then
      return pa > pb
    end
    return a.name < b.name
  end)
  return sorted
end
model.byPriority = byPriority

local function validBadge(b)
  return type(b) == "table" and type(b.kind) == "string" and type(b.text) == "string"
end

---@param spec kanban.Spec `spec.tasks`, when set, must already be kanban.Task values
---@param allTasks kanban.Task[] every task in the space
---@param stateDefs table|nil the `taskStates` config map
---@param decorators kanban.Decorator[]|nil
---@return kanban.Model
function model.build(spec, allTasks, stateDefs, decorators)
  local st = kanban.states.normalize(stateDefs)
  local function isDone(state)
    return kanban.states.isDone(state, st)
  end
  local depsByRef = kanban.deps.resolve(allTasks, isDone)

  local m = {
    title = spec.title,
    columns = {},
    unplaced = {},
    cards = {},
    rules = spec.rules,
    states = st,
    errors = {},
  }
  for _, c in ipairs(kanban.columns.build(spec, st)) do
    c.cards = {}
    m.columns[#m.columns + 1] = c
  end

  -- The Lua API may hand over its own task list (`tasks`); dependencies are
  -- still resolved against every task.
  local selected = spec.tasks or kanban.tasks.select(allTasks, spec)
  for _, task in ipairs(selected) do
    local done = isDone(task.state)
    if spec.includeDone or not done then
      local card = {
        id = task.ref,
        task = task,
        title = task.name,
        page = task.page,
        done = done,
        deps = depsByRef[task.ref],
        badges = {},
      }
      local col = kanban.columns.forState(m.columns, task.state)
      if col then
        card.column = col.id
        col.cards[#col.cards + 1] = card
      else
        m.unplaced[#m.unplaced + 1] = card
      end
      m.cards[card.id] = card
    end
  end

  local function byPosition(a, b)
    if a.page ~= b.page then
      return a.page < b.page
    end
    return a.task.from < b.task.from
  end
  for _, c in ipairs(m.columns) do
    table.sort(c.cards, byPosition)
  end
  table.sort(m.unplaced, byPosition)

  local ctx = { model = m, states = st, isDone = isDone }
  for _, dec in ipairs(byPriority(decorators)) do
    local function decorate(card)
      local ok, badges = pcall(dec.decorate, card, ctx)
      if not ok then
        m.errors[#m.errors + 1] = "decorator " .. dec.name .. " failed: " .. tostring(badges)
        return false
      end
      for _, b in ipairs(badges or {}) do
        if validBadge(b) then
          card.badges[#card.badges + 1] = b
        end
      end
      return true
    end
    local failed = false
    for _, c in ipairs(m.columns) do
      for _, card in ipairs(c.cards) do
        if not failed and not decorate(card) then
          failed = true
        end
      end
    end
    for _, card in ipairs(m.unplaced) do
      if not failed and not decorate(card) then
        failed = true
      end
    end
  end
  return m
end

---@param m kanban.Model
---@param id string
---@return table|nil
function model.column(m, id)
  for _, c in ipairs(m.columns) do
    if c.id == id then
      return c
    end
  end
  return nil
end
```

### src/core/moves.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- Planning a card move: which state to write, and whether move guards allow
-- it. The built-in "refuse Done while blocked" rule is one guard
-- (src/core/builtins.lua); extensions add more.

kanban = kanban or {}
kanban.moves = kanban.moves or {}
local moves = kanban.moves

---@class kanban.Move
---@field card kanban.Card
---@field from table|nil the card's current column
---@field to table the target column
---@field targetState string

---@class kanban.MoveGuard
---@field name string
---@field priority number|nil higher runs first (default 0)
---@field check fun(move: kanban.Move, ctx: table): boolean, string|nil

---@class kanban.MovePlan
---@field ok boolean
---@field noop boolean|nil the card is already in that column
---@field move kanban.Move|nil
---@field reasons string[] why the move is refused

---@param m kanban.Model
---@param cardId string
---@param toColumnId string
---@param guards kanban.MoveGuard[]|nil
---@return kanban.MovePlan
function moves.plan(m, cardId, toColumnId, guards)
  local card = m.cards[cardId]
  if card == nil then
    return { ok = false, reasons = { "That task is no longer on this board." } }
  end
  local to = kanban.model.column(m, toColumnId)
  if to == nil then
    return { ok = false, reasons = { "That column no longer exists." } }
  end
  if kanban.util.contains(to.states, card.task.state) then
    return { ok = false, noop = true, reasons = {} }
  end
  local move = {
    card = card,
    from = card.column and kanban.model.column(m, card.column) or nil,
    to = to,
    targetState = to.dropState,
  }
  local reasons = {}
  local ctx = { model = m, states = m.states }
  for _, guard in ipairs(kanban.model.byPriority(guards)) do
    local ok, allowed, reason = pcall(guard.check, move, ctx)
    if not ok then
      reasons[#reasons + 1] = "Move check " .. guard.name .. " failed: " .. tostring(allowed)
    elseif allowed == false then
      reasons[#reasons + 1] = reason or ("Refused by " .. guard.name .. ".")
    end
  end
  return { ok = #reasons == 0, move = move, reasons = reasons }
end
```

### src/core/registry.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- The extension points: card decorators (badges) and move guards. Any Space
-- Lua block in the space can register one, as long as it runs after this
-- library (the default priority, 0, does). Re-registering a name replaces it.
-- The built-ins go through the same path (src/register.lua).

kanban = kanban or {}
kanban.registry = kanban.registry or { decorators = {}, guards = {} }
local registry = kanban.registry

local function check(def, fnField, apiName)
  if type(def) ~= "table" or type(def.name) ~= "string" or type(def[fnField]) ~= "function" then
    error(apiName .. " needs a table with `name` (string) and `" .. fnField .. "` (function)")
  end
  if def.priority ~= nil and type(def.priority) ~= "number" then
    error(apiName .. ": `priority` must be a number")
  end
end

---Registers a card decorator: `decorate(card, ctx)` returns a list of badges
---`{ kind, text, title?, tone?, refs? }` for the card (or nil). Decorators run
---by `priority`, highest first; a failing one is reported on the board.
---@param def kanban.Decorator
function kanban.defineDecorator(def)
  check(def, "decorate", "kanban.defineDecorator")
  registry.decorators[def.name] = def
end

---Registers a move guard: `check(move, ctx)` returns true to allow a card
---move, or false plus a reason shown to the user.
---@param def kanban.MoveGuard
function kanban.defineMoveGuard(def)
  check(def, "check", "kanban.defineMoveGuard")
  registry.guards[def.name] = def
end

---The registered definitions of one kind, sorted by name.
---@param kind "decorators"|"guards"
---@return table[]
function registry.list(kind)
  local out = {}
  for _, name in ipairs(kanban.util.sortedKeys(registry[kind])) do
    out[#out + 1] = registry[kind][name]
  end
  return out
end
```

### src/core/states.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- Task states: SilverBullet's built-in " " (to do) and "x"/"X" (done), plus
-- the custom states defined with `taskState.define { name, done, order }`
-- (config key `taskStates`). Done-ness is computed here rather than read from
-- `task.done`, which can be stale for pages indexed before CONFIG ran.

kanban = kanban or {}
kanban.states = kanban.states or {}
local states = kanban.states

---@class kanban.State
---@field name string
---@field done boolean
---@field order number
---@field builtin boolean

---@class kanban.States
---@field list kanban.State[] not-done states first (by order, then name), then done states
---@field byName table<string, kanban.State>

---Normalizes the `taskStates` config map into an ordered list.
---@param defs table<string, table>|nil
---@return kanban.States
function states.normalize(defs)
  local list = {}
  local byName = {}
  local function add(name, done, order, builtin)
    if byName[name] == nil then
      local s = { name = name, done = done, order = order, builtin = builtin }
      byName[name] = s
      list[#list + 1] = s
    end
  end
  add(" ", false, -math.huge, true)
  defs = defs or {}
  for _, key in ipairs(kanban.util.sortedKeys(defs)) do
    local def = defs[key]
    if type(def) == "table" then
      local name = def.name or key
      add(name, def.done == true, tonumber(def.order) or 0, false)
    end
  end
  add("x", true, math.huge, true)
  add("X", true, math.huge, true)
  table.sort(list, function(a, b)
    if a.done ~= b.done then
      return not a.done
    elseif a.order ~= b.order then
      return a.order < b.order
    end
    return a.name < b.name
  end)
  return { list = list, byName = byName }
end

---@param state string
---@param normalized kanban.States
---@return boolean
function states.isDone(state, normalized)
  local s = normalized.byName[state]
  return s ~= nil and s.done
end
```

### src/core/tasks.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- The library's view of a task: a plain table built from an index row, so
-- the rest of the core never touches SilverBullet's objects.

kanban = kanban or {}
kanban.tasks = kanban.tasks or {}
local tasks = kanban.tasks

---@class kanban.Task
---@field ref string the index ref: the anchor name when anchored, else "Page@pos"
---@field page string
---@field from integer start offset of the task's list line on its page
---@field to integer end offset (exclusive) of that line
---@field name string
---@field state string
---@field tags string[]
---@field anchor string|nil
---@field blockedBy string[] anchor names from the `blockedBy` attribute
---@field badLinks string[] `blockedBy` values that are not `[[$anchor]]` links

---Parses one `blockedBy` value: `[[$name]]` (optionally `[[$name|alias]]`)
---or a bare `$name`. Returns nil for anything else.
---@param value any
---@return string|nil
function tasks.parseAnchorLink(value)
  if type(value) ~= "string" then
    return nil
  end
  local v = kanban.util.trim(value)
  local inner = string.match(v, "^%[%[(.-)%]%]$")
  if inner then
    v = string.match(inner, "^([^|]*)") or inner
  end
  local name = string.match(v, "^%$([%a_][%w_/:%-]*)$")
  return name
end

---Builds a task from an `index.tasks()` row.
---@param row table
---@return kanban.Task
function tasks.fromIndex(row)
  local blockedBy, badLinks = {}, {}
  for _, value in ipairs(kanban.util.asList(row.blockedBy)) do
    local name = tasks.parseAnchorLink(value)
    if name then
      blockedBy[#blockedBy + 1] = name
    else
      badLinks[#badLinks + 1] = tostring(value)
    end
  end
  local ref = row.ref
  local anchor = nil
  if not string.match(ref, "@%d+$") then
    anchor = ref
  end
  local range = row.range or {}
  return {
    ref = ref,
    page = row.page,
    from = range[1],
    to = range[2],
    name = row.name or "",
    state = row.state or " ",
    tags = kanban.util.asList(row.tags),
    anchor = anchor,
    blockedBy = blockedBy,
    badLinks = badLinks,
  }
end

---The "Page@pos" ref SilverBullet's task functions need, even for anchored
---tasks (index.updateTaskState ignores anchor refs on 2.12).
---@param task kanban.Task
---@return string
function tasks.positionRef(task)
  return task.page .. "@" .. tostring(task.from)
end

local function onAnyPage(task, pages)
  return #pages == 0 or kanban.util.contains(pages, task.page)
end

local function underAnyPrefix(task, prefixes)
  if #prefixes == 0 then
    return true
  end
  for _, prefix in ipairs(prefixes) do
    if kanban.util.startsWith(task.page, prefix) then
      return true
    end
  end
  return false
end

local function hasAnyTag(task, wanted)
  if #wanted == 0 then
    return true
  end
  for _, tag in ipairs(wanted) do
    if kanban.util.contains(task.tags, tag) then
      return true
    end
  end
  return false
end

---Keeps the tasks a board spec selects (pages, page prefixes, tags; each
---filter matches any of its values, and all given filters must match).
---@param list kanban.Task[]
---@param spec table normalized board spec
---@return kanban.Task[]
function tasks.select(list, spec)
  return kanban.util.filter(list, function(task)
    return onAnyPage(task, spec.pages)
      and underAnyPrefix(task, spec.pagePrefixes)
      and hasAnyTag(task, spec.tags)
  end)
end
```

### src/core/util.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- Small helpers for the pure core. Standard Lua only (no Space Lua string
-- extensions), so the same code runs on Lua 5.5.1 in the unit tests.

kanban = kanban or {}
kanban.util = kanban.util or {}
local util = kanban.util

---Escapes text for use inside HTML element content or attribute values.
---@param s string
---@return string
function util.escapeHtml(s)
  local escaped = string.gsub(tostring(s), "[&<>\"']", {
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;",
    ["'"] = "&#39;",
  })
  return escaped
end

---@param s string
---@return string
function util.trim(s)
  return (string.match(s, "^%s*(.-)%s*$"))
end

---@param s string
---@param prefix string
---@return boolean
function util.startsWith(s, prefix)
  return string.sub(s, 1, #prefix) == prefix
end

---Turns nil into {}, a single value into { value }, and leaves lists alone.
---@param v any
---@return any[]
function util.asList(v)
  if v == nil then
    return {}
  elseif type(v) == "table" then
    return v
  end
  return { v }
end

---@param list any[]
---@param value any
---@return boolean
function util.contains(list, value)
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

---@param list any[]
---@param fn fun(v: any): any
---@return any[]
function util.map(list, fn)
  local out = {}
  for i, v in ipairs(list) do
    out[i] = fn(v)
  end
  return out
end

---@param list any[]
---@param fn fun(v: any): boolean
---@return any[]
function util.filter(list, fn)
  local out = {}
  for _, v in ipairs(list) do
    if fn(v) then
      out[#out + 1] = v
    end
  end
  return out
end

---A shallow copy of a table.
---@generic T: table
---@param t T
---@return T
function util.shallowCopy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = v
  end
  return out
end

---The keys of `t`, sorted, for iteration that does not depend on `pairs`
---order (which differs between Space Lua and reference Lua).
---@param t table
---@return any[]
function util.sortedKeys(t)
  local keys = {}
  for k in pairs(t) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)
  return keys
end
```

### src/namespace.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- The library's single global namespace. Never `kanban = {}`: a TypeScript
-- plug can register `kanban.*` syscalls, and SilverBullet adds those to an
-- existing table before scripts run.
kanban = kanban or {}

-- Bumped on any change to the public API (`kanban.board`, the options of
-- `kanban` fenced blocks, `kanban.defineDecorator`, `kanban.defineMoveGuard`)
-- that breaks existing boards or extensions.
kanban.apiVersion = 1
kanban.version = "0.1.0"
```

### src/sb/actions.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- What the board's controls do. Each action rebuilds the model from the
-- current index (so it acts on fresh data, not on what was rendered), plans
-- with the pure core, writes through kanban.sb.write and reports problems
-- with a notification. The board re-renders by itself once the index sees
-- the change.

kanban = kanban or {}
kanban.sb = kanban.sb or {}
kanban.sb.actions = kanban.sb.actions or {}
local actions = kanban.sb.actions

local function notifyError(message)
  editor.flashNotification(message, "error")
end

local function cardIn(m, cardId)
  local card = m.cards[cardId]
  if card == nil then
    notifyError "That task is no longer on this board."
  end
  return card
end

---Moves a card to a column (drag and drop, or the "Move to" menu).
---@param spec kanban.Spec
---@param cardId string
---@param columnId string
---@return boolean moved
function actions.move(spec, cardId, columnId)
  local m = kanban.sb.data.model(spec)
  local plan = kanban.moves.plan(m, cardId, columnId, kanban.registry.list "guards")
  if plan.noop then
    return false
  end
  if not plan.ok then
    notifyError(table.concat(plan.reasons, " "))
    return false
  end
  local ok, message = kanban.sb.write.setState(plan.move.card.task, plan.move.targetState)
  if not ok then
    notifyError(message)
    return false
  end
  return true
end

---Opens a task in the editor, by anchor when it has one.
---@param task kanban.Task
function actions.open(task)
  if task.anchor then
    editor.navigate("$" .. task.anchor)
  else
    editor.navigate(kanban.tasks.positionRef(task))
  end
end

---Opens one of the tasks a badge points at (asking which, if several).
---@param refs string[]
function actions.openRefs(refs)
  local byRef = {}
  for _, t in ipairs(kanban.sb.data.allTasks()) do
    byRef[t.ref] = t
  end
  local found = kanban.util.filter(
    kanban.util.map(refs, function(r)
      return byRef[r]
    end),
    function(t)
      return t ~= nil
    end
  )
  if #found == 0 then
    notifyError "Those tasks are gone."
    return
  elseif #found == 1 then
    actions.open(found[1])
    return
  end
  local options = kanban.util.map(found, function(t)
    return { name = t.name, description = t.page, ref = t.ref }
  end)
  local choice = editor.filterBox("Open", options, "Pick a task to open")
  if choice and byRef[choice.ref] then
    actions.open(byRef[choice.ref])
  end
end

---Asks for a task and records it as a blocker of the card's task, giving the
---blocker an anchor first if it has none. Blockers can be on any page.
---@param spec kanban.Spec
---@param cardId string
---@return boolean added
function actions.addBlocker(spec, cardId)
  local m = kanban.sb.data.model(spec)
  local card = cardIn(m, cardId)
  if card == nil then
    return false
  end
  local current = card.task.blockedBy
  local options, byRef = {}, {}
  for _, t in ipairs(kanban.sb.data.allTasks()) do
    local isCurrent = t.anchor ~= nil and kanban.util.contains(current, t.anchor)
    if t.ref ~= card.id and not isCurrent and not kanban.states.isDone(t.state, m.states) then
      -- Only plain values in options: they travel to the UI and back.
      options[#options + 1] = { name = t.name, description = t.page, ref = t.ref }
      byRef[t.ref] = t
    end
  end
  if #options == 0 then
    notifyError "There are no open tasks to add as a blocker."
    return false
  end
  local choice = editor.filterBox("Blocked by", options, "Pick the task this one waits for")
  local blocker = choice and byRef[choice.ref]
  if blocker == nil then
    return false
  end
  local anchor, delta = kanban.sb.write.ensureAnchor(blocker)
  if anchor == nil then
    notifyError(delta)
    return false
  end
  local task = card.task
  -- The new anchor lengthened the blocker's line; shift this task if it comes
  -- later on the same page.
  if blocker.page == task.page and blocker.from < task.from and delta ~= 0 then
    task = {}
    for k, v in pairs(card.task) do
      task[k] = v
    end
    task.from = task.from + delta
    task.to = task.to + delta
  end
  local anchors = {}
  for i, a in ipairs(current) do
    anchors[i] = a
  end
  anchors[#anchors + 1] = anchor
  local ok, message = kanban.sb.write.setBlockedBy(task, anchors)
  if not ok then
    notifyError(message)
    return false
  end
  return true
end

---Asks which blocker to drop and removes it from the card's task.
---@param spec kanban.Spec
---@param cardId string
---@return boolean removed
function actions.removeBlocker(spec, cardId)
  local m = kanban.sb.data.model(spec)
  local card = cardIn(m, cardId)
  if card == nil then
    return false
  end
  local options = {}
  local byAnchor = {}
  for _, b in ipairs(card.deps.blockers) do
    byAnchor[b.anchor] = b
  end
  for _, anchor in ipairs(card.task.blockedBy) do
    local b = byAnchor[anchor]
    if b then
      options[#options + 1] = { name = b.name, description = b.page, anchor = anchor }
    else
      options[#options + 1] =
        { name = "$" .. anchor, description = "missing task", anchor = anchor }
    end
  end
  if #options == 0 then
    notifyError "This task has no blockers."
    return false
  end
  local choice = editor.filterBox("Remove blocker", options, "Pick the blocker to remove")
  if choice == nil then
    return false
  end
  local anchors = kanban.util.filter(card.task.blockedBy, function(a)
    return a ~= choice.anchor
  end)
  local ok, message = kanban.sb.write.setBlockedBy(card.task, anchors)
  if not ok then
    notifyError(message)
    return false
  end
  return true
end
```

### src/sb/board.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- The public entry points: `kanban.board { ... }` for `${...}` expressions,
-- and `kanban` fenced blocks (registered in src/register.lua) with the same
-- options as YAML.
--
-- SilverBullet 2.12 does not re-render widgets by itself when the index
-- changes (that is Edge only), so boards are content widgets that refresh on
-- every index update; that is what moves a dropped card, and what updates a
-- blocker badge when the blocking task is finished on another page.

kanban = kanban or {}
kanban.sb = kanban.sb or {}

---A kanban board of tasks.
---@param options table|nil board options, as in a `kanban` block
---@return sb.Widget
function kanban.board(options)
  return widget.new {
    content = function()
      return kanban.sb.render.board(options)
    end,
    refreshOn = { "index" },
  }
end

---Renders the body of a `kanban` fenced block (YAML board options).
---@param body string
---@return sb.Widget
function kanban.sb.renderBlock(body)
  local ok, parsed = pcall(yaml.parse, body)
  if not ok then
    return kanban.sb.render.problems {
      "The board options are not valid YAML: " .. tostring(parsed),
    }
  end
  return kanban.board(parsed)
end
```

### src/sb/data.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- Reading from SilverBullet: tasks, task-state definitions and anchors, turned
-- into the core's plain tables.

kanban = kanban or {}
kanban.sb = kanban.sb or {}
kanban.sb.data = kanban.sb.data or {}
local data = kanban.sb.data

---Every task in the space.
---@return kanban.Task[]
function data.allTasks()
  local rows = query [[from t = index.tasks()]]
  return kanban.util.map(rows, kanban.tasks.fromIndex)
end

---The `taskStates` config map (from taskState.define).
---@return table
function data.stateDefs()
  return config.get("taskStates", {})
end

---The set of anchor names already used anywhere in the space.
---@return table<string, boolean>
function data.takenAnchors()
  local taken = {}
  local rows = query [[from a = index.objects("anchor")]]
  for _, a in ipairs(rows) do
    taken[a.ref] = true
  end
  return taken
end

---Builds the board model for a normalized spec from the current index.
---@param spec kanban.Spec
---@return kanban.Model
function data.model(spec)
  local s = spec
  if spec.tasks then
    s = kanban.util.shallowCopy(spec)
    s.tasks = kanban.util.map(spec.tasks, kanban.tasks.fromIndex)
  end
  return kanban.model.build(s, data.allTasks(), data.stateDefs(), kanban.registry.list "decorators")
end
```

### src/sb/render.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- The board as DOM, built with SilverBullet's `dom` builder: columns that
-- accept dropped cards, draggable cards with a keyboard-friendly "Move to"
-- menu, blocker buttons and clickable badges. Styling is in
-- src/style/kanban.css.

kanban = kanban or {}
kanban.sb = kanban.sb or {}
kanban.sb.render = kanban.sb.render or {}
local render = kanban.sb.render

-- The drag payload type, so only cards from these boards can be dropped.
render.dragType = "application/x-sb-kanban-card"

-- An element whose content is literal text. The 2.12 `dom` builder renders
-- plain-string children as Markdown (raw HTML included), so task text always
-- goes through here. `__rawText` is how 2.12's builder adds a text node.
local function textEl(tag, attrs, text)
  attrs.__rawText = text
  return dom[tag](attrs)
end
render.textEl = textEl

local function badgeEl(badge)
  local attrs = {
    class = "sbk-badge sbk-tone-" .. (badge.tone or "info"),
    title = badge.title or "",
    ["data-badge"] = badge.kind,
  }
  if badge.refs and #badge.refs > 0 then
    attrs.type = "button"
    attrs.onclick = function(e)
      e.stopPropagation()
      kanban.sb.actions.openRefs(badge.refs)
    end
    return textEl("button", attrs, badge.text)
  end
  return textEl("span", attrs, badge.text)
end

local function moveMenu(spec, m, card)
  local menu = {
    class = "sbk-move",
    ["aria-label"] = "Move “" .. card.title .. "” to",
    onchange = function(e)
      local columnId = e.target.value
      if columnId ~= nil and columnId ~= "" then
        kanban.sb.actions.move(spec, card.id, columnId)
      end
    end,
  }
  menu[#menu + 1] = textEl("option", { value = "" }, "Move to…")
  for _, c in ipairs(m.columns) do
    if c.id ~= card.column then
      menu[#menu + 1] = textEl("option", { value = c.id }, c.title)
    end
  end
  return dom.select(menu)
end

local function cardEl(spec, m, card)
  local el = {
    class = card.done and "sbk-card sbk-done" or "sbk-card",
    draggable = "true",
    ["data-card-id"] = card.id,
    ["data-card-title"] = card.title,
    ["data-state"] = card.task.state,
    ondragstart = function(e)
      e.dataTransfer.setData(render.dragType, card.id)
      e.dataTransfer.setData("text/plain", card.title)
    end,
  }
  el[#el + 1] = textEl("div", { class = "sbk-card-title" }, card.title)
  el[#el + 1] = textEl("button", {
    type = "button",
    class = "sbk-card-page",
    title = "Open this task",
    onclick = function()
      kanban.sb.actions.open(card.task)
    end,
  }, card.page)

  if #card.badges > 0 then
    local badges = { class = "sbk-badges" }
    for _, b in ipairs(card.badges) do
      badges[#badges + 1] = badgeEl(b)
    end
    el[#el + 1] = dom.div(badges)
  end

  local controls = { class = "sbk-card-actions" }
  controls[#controls + 1] = moveMenu(spec, m, card)
  controls[#controls + 1] = textEl("button", {
    type = "button",
    class = "sbk-btn sbk-add-blocker",
    title = "Add a task this one is blocked by",
    onclick = function()
      kanban.sb.actions.addBlocker(spec, card.id)
    end,
  }, "+ Blocker")
  if #card.task.blockedBy > 0 then
    controls[#controls + 1] = textEl("button", {
      type = "button",
      class = "sbk-btn sbk-remove-blocker",
      title = "Remove one of this task's blockers",
      onclick = function()
        kanban.sb.actions.removeBlocker(spec, card.id)
      end,
    }, "− Blocker")
  end
  el[#el + 1] = dom.div(controls)
  return dom.div(el)
end

local function columnEl(spec, m, col)
  local cards = { class = "sbk-cards" }
  for _, card in ipairs(col.cards) do
    cards[#cards + 1] = cardEl(spec, m, card)
  end
  if #col.cards == 0 then
    cards[#cards + 1] = textEl("div", { class = "sbk-empty" }, "No tasks")
  end
  return dom.div {
    class = col.done and "sbk-column sbk-column-done" or "sbk-column",
    ["data-column-id"] = col.id,
    ["data-column-title"] = col.title,
    ondragover = function(e)
      e.preventDefault()
    end,
    ondrop = function(e)
      e.preventDefault()
      local cardId = e.dataTransfer.getData(render.dragType)
      if cardId ~= nil and cardId ~= "" then
        kanban.sb.actions.move(spec, cardId, col.id)
      end
    end,
    dom.div {
      class = "sbk-column-header",
      textEl("span", { class = "sbk-column-title" }, col.title),
      textEl("span", { class = "sbk-count" }, tostring(#col.cards)),
    },
    dom.div(cards),
  }
end

local function problemsEl(messages)
  local el = { class = "sbk-problems", role = "alert" }
  for _, message in ipairs(messages) do
    el[#el + 1] = textEl("div", { class = "sbk-problem" }, message)
  end
  return dom.div(el)
end

local function unplacedText(m)
  local counts, order = {}, {}
  for _, card in ipairs(m.unplaced) do
    local s = card.task.state
    if counts[s] == nil then
      counts[s] = 0
      order[#order + 1] = s
    end
    counts[s] = counts[s] + 1
  end
  local parts = kanban.util.map(order, function(s)
    return "[" .. s .. "] ×" .. counts[s]
  end)
  local n = #m.unplaced
  local noun = n == 1 and "task is" or "tasks are"
  return n .. " " .. noun .. " in states no column takes: " .. table.concat(parts, ", ")
end

---The board's DOM element for a spec and model.
---@param spec kanban.Spec
---@param m kanban.Model
---@param errors string[] option problems to show above the board
function render.boardElement(spec, m, errors)
  local root = { class = "sbk-board", ["data-kanban-board"] = "1" }
  if spec.title then
    root[#root + 1] = textEl("div", { class = "sbk-title" }, spec.title)
  end
  local problems = {}
  for _, e in ipairs(errors) do
    problems[#problems + 1] = e
  end
  for _, e in ipairs(m.errors) do
    problems[#problems + 1] = e
  end
  if #problems > 0 then
    root[#root + 1] = problemsEl(problems)
  end
  local columns = { class = "sbk-columns" }
  for _, col in ipairs(m.columns) do
    columns[#columns + 1] = columnEl(spec, m, col)
  end
  root[#root + 1] = dom.div(columns)
  if #m.unplaced > 0 then
    root[#root + 1] = textEl("div", { class = "sbk-unplaced" }, unplacedText(m))
  end
  return dom.div(root)
end

---A widget showing only problems (e.g. unreadable board options).
---@param messages string[]
function render.problems(messages)
  return widget.html(dom.div { class = "sbk-board", problemsEl(messages) })
end

---Renders a board for raw options (from YAML or a Lua table).
---@param options table|nil
function render.board(options)
  local spec, errors = kanban.config.normalize(options)
  local ok, result = pcall(function()
    return render.boardElement(spec, kanban.sb.data.model(spec), errors)
  end)
  if not ok then
    return render.problems { "The board could not be drawn: " .. tostring(result) }
  end
  return widget.html(result)
end
```

### src/sb/write.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- The only code that changes pages. SilverBullet 2.12 has no object API, so:
-- task states go through the index plug's own updateTaskState (with a
-- "Page@pos" ref), and attribute/anchor edits are splices of the task's line,
-- computed by the pure core (src/core/edit.lua).
--
-- Every write first checks that the indexed range still holds the task's
-- line, and afterwards reads the page back to confirm the change landed.
-- When either check fails the task moved since the board was drawn (the index
-- lags edits by a moment), and the write reports that instead of guessing.
--
-- A later backend for SilverBullet's object API (Edge builds) would only
-- change this file.

kanban = kanban or {}
kanban.sb = kanban.sb or {}
kanban.sb.write = kanban.sb.write or {}
local write = kanban.sb.write

write.staleMessage = "This task changed since the board was drawn. Try again in a moment."

-- The page text as the editor would save it: the open buffer for the page in
-- the editor, else the stored page.
local function readPage(page)
  if editor.getCurrentPage() == page then
    return editor.getText(), true
  end
  return space.readPage(page), false
end

local function lineAt(text, task)
  return string.sub(text, task.from + 1, task.to)
end

-- The task's current line, if the indexed range still holds it.
local function currentLine(task)
  local text, open = readPage(task.page)
  local line = lineAt(text, task)
  local parsed = kanban.edit.parse(line)
  if parsed == nil or parsed.state ~= task.state then
    return nil
  end
  if not string.find(parsed.rest, task.name, 1, true) then
    return nil
  end
  return line, text, open
end

local function replaceLine(task, text, open, newLine)
  if open then
    editor.replaceRange(task.from, task.to, newLine)
  else
    local before = string.sub(text, 1, task.from)
    local after = string.sub(text, task.to + 1)
    space.writePage(task.page, before .. newLine .. after)
  end
end

local function landed(task, newLine)
  local text = readPage(task.page)
  return string.sub(text, task.from + 1, task.from + #newLine) == newLine
end

---Sets a task's state.
---@param task kanban.Task
---@param newState string
---@return boolean ok
---@return string|nil message why not
function write.setState(task, newState)
  local line = currentLine(task)
  if line == nil then
    return false, write.staleMessage
  end
  system.invokeFunction(
    "index.updateTaskState",
    kanban.tasks.positionRef(task),
    task.state,
    newState
  )
  local parsed = kanban.edit.parse(line)
  local newLine = parsed.prefix .. newState .. "]" .. parsed.rest
  if not landed(task, newLine) then
    return false, write.staleMessage
  end
  return true
end

---Sets a task's `blockedBy` attribute to exactly `anchors`.
---@param task kanban.Task
---@param anchors string[]
---@return boolean ok
---@return string|nil message why not
function write.setBlockedBy(task, anchors)
  local line, text, open = currentLine(task)
  if line == nil then
    return false, write.staleMessage
  end
  local newLine = kanban.edit.setBlockedBy(line, anchors)
  if newLine ~= line then
    replaceLine(task, text, open, newLine)
    if not landed(task, newLine) then
      return false, write.staleMessage
    end
  end
  return true
end

---Gives a task an anchor if it has none.
---@param task kanban.Task
---@return string|nil anchor the task's anchor
---@return string|integer messageOrDelta how many characters the line grew by, or why it failed
function write.ensureAnchor(task)
  if task.anchor then
    return task.anchor, 0
  end
  local line, text, open = currentLine(task)
  if line == nil then
    return nil, write.staleMessage
  end
  local id = kanban.ids.new(task.name, kanban.sb.data.takenAnchors())
  local newLine, anchor = kanban.edit.addAnchor(line, id)
  if newLine ~= line then
    replaceLine(task, text, open, newLine)
    if not landed(task, newLine) then
      return nil, write.staleMessage
    end
  end
  return anchor, #newLine - #line
end
```

### src/register.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 10

-- Everything the library does when it loads, as opposed to defining things.
-- SilverBullet runs blocks of equal priority in no guaranteed order (it sorts
-- them by their `Page@pos` ref as a string), so no other file may call into
-- another file while loading. This block runs after all of them (priority 10
-- comes after 50). spec/tools/load_order_spec.lua checks the rule.

kanban.defineDecorator(kanban.builtins.dependencies)
kanban.defineMoveGuard(kanban.builtins.blockDone)

codeWidget.define {
  language = "kanban",
  render = function(body)
    return kanban.sb.renderBlock(body)
  end,
}
```

### src/style/kanban.css
```space-style
/* SPDX-License-Identifier: AGPL-3.0-or-later */
/* Board styles, using SilverBullet's theme variables so boards follow the
   light and dark themes. Every class starts with sbk- to stay out of the way. */

.sbk-board {
  margin: 0.5em 0;
  font-size: 0.95em;
}

.sbk-title {
  font-weight: 600;
  margin-bottom: 0.5em;
}

.sbk-columns {
  display: flex;
  gap: 0.75rem;
  align-items: flex-start;
  overflow-x: auto;
  padding-bottom: 0.25rem;
}

.sbk-column {
  /* Share the editor's width; scroll sideways only when columns would get
     narrower than 9rem. */
  flex: 1 1 0;
  min-width: 9rem;
  max-width: 24rem;
  min-height: 5rem;
  padding: 0.5rem;
  border: 1px solid var(--button-border-color, rgba(127, 127, 127, 0.35));
  border-radius: 6px;
  background: var(--editor-widget-background-color, rgba(127, 127, 127, 0.08));
}

.sbk-column-header {
  display: flex;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
  font-weight: 600;
}

.sbk-count,
.sbk-empty {
  color: var(--meta-color, #888);
  font-weight: normal;
}

.sbk-empty {
  font-size: 0.85em;
  padding: 0.25rem 0;
}

.sbk-card {
  margin-bottom: 0.45rem;
  padding: 0.4rem 0.5rem;
  border: 1px solid var(--button-border-color, rgba(127, 127, 127, 0.35));
  border-radius: 5px;
  background: var(--editor-background-color, Canvas);
  cursor: grab;
}

.sbk-card.sbk-done .sbk-card-title {
  text-decoration: line-through;
  opacity: 0.7;
}

.sbk-card-title {
  overflow-wrap: anywhere;
}

.sbk-card-page {
  all: unset;
  cursor: pointer;
  font-size: 0.8em;
  color: var(--link-color, #2563eb);
}

.sbk-card-page:hover,
.sbk-card-page:focus-visible {
  text-decoration: underline;
}

.sbk-badges,
.sbk-card-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.3rem;
  margin-top: 0.35rem;
}

.sbk-badge {
  font: inherit;
  font-size: 0.75em;
  padding: 0 0.5em;
  border: 1px solid currentColor;
  border-radius: 999px;
  background: none;
}

button.sbk-badge {
  cursor: pointer;
}

.sbk-tone-info {
  color: var(--alert-info-color, #1d4ed8);
  background: var(--alert-info-background-color, transparent);
  border-color: var(--alert-info-border-color, currentColor);
}

.sbk-tone-warn {
  color: var(--alert-warning-color, #b45309);
  background: var(--alert-warning-background-color, transparent);
  border-color: var(--alert-warning-border-color, currentColor);
}

.sbk-tone-error {
  color: var(--alert-error-color, #b91c1c);
  background: var(--alert-error-background-color, transparent);
  border-color: var(--alert-error-border-color, currentColor);
}

.sbk-tone-ok {
  color: var(--meta-color, #15803d);
}

.sbk-move,
.sbk-btn {
  font: inherit;
  font-size: 0.75em;
  padding: 0.05em 0.4em;
  border: 1px solid var(--button-border-color, rgba(127, 127, 127, 0.5));
  border-radius: 4px;
  color: var(--button-color, inherit);
  background: var(--button-background-color, transparent);
}

.sbk-btn {
  cursor: pointer;
}

.sbk-btn:hover {
  background: var(--button-hover-background-color, rgba(127, 127, 127, 0.15));
}

.sbk-problems {
  margin-bottom: 0.5rem;
  padding: 0.4rem 0.6rem;
  border: 1px solid var(--alert-error-border-color, #b91c1c);
  border-radius: 5px;
  color: var(--alert-error-color, #b91c1c);
  background: var(--alert-error-background-color, transparent);
}

.sbk-unplaced {
  margin-top: 0.4rem;
  font-size: 0.85em;
  color: var(--meta-color, #888);
}
```

