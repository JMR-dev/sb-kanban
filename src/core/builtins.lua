-- SPDX-License-Identifier: Apache-2.0
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
