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

local function refs(list)
  return kanban.util.map(list, function(t)
    return t.ref
  end)
end

---A card as plain data (no functions, no shared tables), for extensions that
---run outside this library, such as a TypeScript plug behind a SilverBullet
---service.
---@param card kanban.Card
---@return table
function model.cardSnapshot(card)
  local t, d = card.task, card.deps
  return {
    id = card.id,
    title = card.title,
    page = card.page,
    done = card.done,
    column = card.column,
    state = t.state,
    anchor = t.anchor,
    tags = kanban.util.shallowCopy(t.tags),
    blockedBy = kanban.util.shallowCopy(t.blockedBy),
    blockers = refs(d.blockers),
    blocks = refs(d.blocks),
    openBlockers = d.openBlockers,
    missing = kanban.util.shallowCopy(d.missing),
    inCycle = d.inCycle,
  }
end

---A column as plain data, with its cards as a list of card ids.
---@param column table
---@return table
function model.columnSnapshot(column)
  return {
    id = column.id,
    title = column.title,
    states = kanban.util.shallowCopy(column.states),
    dropState = column.dropState,
    done = column.done,
    cards = column.cards and kanban.util.map(column.cards, function(c)
      return c.id
    end) or {},
  }
end

---The whole board as plain data: `{ apiVersion, title, columns, cards }`, with
---`cards` keyed by card id.
---@param m kanban.Model
---@return table
function model.snapshot(m)
  local cards = {}
  for id, card in pairs(m.cards) do
    cards[id] = model.cardSnapshot(card)
  end
  return {
    apiVersion = kanban.apiVersion,
    title = m.title,
    columns = kanban.util.map(m.columns, model.columnSnapshot),
    cards = cards,
  }
end

---Adds badges from an outside source, given as `{ [cardId] = { badge, ... } }`.
---Invalid badges and unknown cards are skipped.
---@param m kanban.Model
---@param byCard table
---@return integer added
function model.addBadges(m, byCard)
  local added = 0
  if type(byCard) ~= "table" then
    return added
  end
  for _, id in ipairs(kanban.util.sortedKeys(byCard)) do
    local card = m.cards[id]
    if card and type(byCard[id]) == "table" then
      for _, b in ipairs(byCard[id]) do
        if validBadge(b) then
          card.badges[#card.badges + 1] = b
          added = added + 1
        end
      end
    end
  end
  return added
end
