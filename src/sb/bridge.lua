-- SPDX-License-Identifier: Apache-2.0
-- priority: 50

-- Extensions provided as SilverBullet services, which is how a TypeScript
-- plug (or any other code) can extend boards without being Space Lua:
--
-- * "kanban:decorator": invoked once per board with kanban.model.snapshot(m);
--   returns `{ [cardId] = { badge, ... } }`.
-- * "kanban:moveGuard": invoked once per move with
--   `{ card = cardSnapshot, from = columnSnapshot, to = columnSnapshot,
--   targetState }`; returns nil/true to allow, or `{ allowed = false,
--   reason = "..." }` to refuse.
--
-- Discovery data is `{ apiVersion = kanban.apiVersion }`, so a provider can
-- decline versions it does not know. A plug provides a service by answering
-- the `discover:<selector>` event with `{ id = "<its id>", priority = n }` and
-- handling `service:<its id>`; Space Lua uses service.define.

kanban = kanban or {}
kanban.sb = kanban.sb or {}
kanban.sb.bridge = kanban.sb.bridge or {}
local bridge = kanban.sb.bridge

bridge.decoratorSelector = "kanban:decorator"
bridge.guardSelector = "kanban:moveGuard"

local function discover(selector)
  local ok, matches = pcall(service.discover, selector, { apiVersion = kanban.apiVersion })
  if not ok or type(matches) ~= "table" then
    return {}
  end
  return matches
end

local function label(match)
  return tostring(match.name or match.id or "?")
end

---Adds badges from decorator services to a model.
---@param m kanban.Model
function bridge.decorate(m)
  local matches = discover(bridge.decoratorSelector)
  if #matches == 0 then
    return
  end
  local snapshot = kanban.model.snapshot(m)
  for _, match in ipairs(matches) do
    local ok, result = pcall(service.invoke, match, snapshot)
    if ok then
      kanban.model.addBadges(m, result)
    else
      m.errors[#m.errors + 1] = "decorator service "
        .. label(match)
        .. " failed: "
        .. tostring(result)
    end
  end
end

---Asks move-guard services about a planned move.
---@param move kanban.Move
---@return string[] reasons to refuse (empty when every service allows it)
function bridge.checkMove(move)
  local reasons = {}
  local matches = discover(bridge.guardSelector)
  if #matches == 0 then
    return reasons
  end
  local data = {
    card = kanban.model.cardSnapshot(move.card),
    from = move.from and kanban.model.columnSnapshot(move.from) or nil,
    to = kanban.model.columnSnapshot(move.to),
    targetState = move.targetState,
  }
  for _, match in ipairs(matches) do
    local ok, result = pcall(service.invoke, match, data)
    if not ok then
      reasons[#reasons + 1] = "Move check " .. label(match) .. " failed: " .. tostring(result)
    elseif type(result) == "table" and result.allowed == false then
      reasons[#reasons + 1] = result.reason or ("Refused by " .. label(match) .. ".")
    end
  end
  return reasons
end
