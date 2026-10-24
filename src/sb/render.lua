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
