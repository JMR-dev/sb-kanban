-- SPDX-License-Identifier: Apache-2.0
-- priority: 50

-- When CONFIG sets the complete list of task states (kanban.taskStates), a
-- task in any other state goes back to `[ ]`. This runs once after the
-- scripts load, at startup and after System: Reload (scheduled in
-- src/register.lua), and from the "Kanban: Move tasks in removed states to
-- [ ]" command.
--
-- Tasks are rewritten bottom-up within each page, so a rewrite never shifts
-- the position of a task still to come, and every write goes through the
-- guarded write path: a task that changed meanwhile is skipped and picked up
-- next time.

kanban = kanban or {}
kanban.sb = kanban.sb or {}
kanban.sb.migrate = kanban.sb.migrate or {}
local migrate = kanban.sb.migrate

local builtin = { [" "] = true, x = true, X = true }

---The tasks in states that the current list doesn't have, grouped by page and
---ordered bottom-up within each page.
---@return kanban.Task[]
function migrate.strays()
  local defs = config.get("taskStates", {})
  local byPage, pages = {}, {}
  for _, t in ipairs(kanban.sb.data.allTasks()) do
    if not builtin[t.state] and defs[t.state] == nil then
      if byPage[t.page] == nil then
        byPage[t.page] = {}
        pages[#pages + 1] = t.page
      end
      local list = byPage[t.page]
      list[#list + 1] = t
    end
  end
  table.sort(pages)
  local out = {}
  for _, page in ipairs(pages) do
    local list = byPage[page]
    table.sort(list, function(a, b)
      return a.from > b.from
    end)
    for _, t in ipairs(list) do
      out[#out + 1] = t
    end
  end
  return out
end

---Moves tasks in removed states back to `[ ]` (only when CONFIG sets the
---complete list of states).
---@param explicit boolean|nil true when run as a command: also report "nothing to do"
---@return integer moved
---@return integer skipped
function migrate.run(explicit)
  if not kanban.sb.states.customized() then
    if explicit then
      editor.flashNotification(
        "CONFIG doesn't set a list of task states"
          .. " (Kanban: Customize task states), so no state was removed."
      )
    end
    return 0, 0
  end
  index.ensureFullIndex()
  local moved, skipped = 0, 0
  for _, t in ipairs(migrate.strays()) do
    if kanban.sb.write.setState(t, " ") then
      moved = moved + 1
    else
      skipped = skipped + 1
    end
  end
  if moved > 0 then
    local noun = moved == 1 and " task" or " tasks"
    editor.flashNotification("Kanban: moved " .. moved .. noun .. " in removed states back to [ ].")
  end
  if skipped > 0 then
    editor.flashNotification(
      "Kanban: "
        .. skipped
        .. " task(s) in removed states changed meanwhile; they'll be moved next time.",
      "error"
    )
  elseif explicit and moved == 0 then
    editor.flashNotification "Kanban: no tasks are in removed states."
  end
  return moved, skipped
end
