---
name: Library/JMR-dev/Kanban
tags: meta/library
description: Kanban boards for SilverBullet tasks, with drag-and-drop and cross-page blockers.
author: JMR-dev
license: AGPL-3.0-or-later
website: https://gitea.jasonmross.dev/JMR-dev/sb-kanban
version: "0.1.0"
---
Kanban boards for your [[^Library/Std/APIs/Task State|tasks]].

> **note** Generated page
> This page is generated from the [sb-kanban repository](https://gitea.jasonmross.dev/JMR-dev/sb-kanban) (version 0.1.0). Edit the sources there, not here: updating the library replaces this page.

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

---@param spec kanban.Spec
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

  for _, task in ipairs(kanban.tasks.select(allTasks, spec)) do
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

