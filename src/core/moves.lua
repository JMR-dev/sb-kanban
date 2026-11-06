-- SPDX-License-Identifier: Apache-2.0
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
