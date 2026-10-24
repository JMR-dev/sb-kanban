-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- Task states: the library's defaults (applied when it loads), and
-- `kanban.taskStates { ... }` for CONFIG, which sets the complete list.

kanban = kanban or {}
kanban.sb = kanban.sb or {}
kanban.sb.states = kanban.sb.states or {}
local states = kanban.sb.states

-- Problems with the last kanban.taskStates list, shown above every board.
states.problems = states.problems or {}

---Adds the library's default task states, leaving any state that is already
---defined alone. Runs when the library loads (src/register.lua), before
---CONFIG, so CONFIG can change or replace them.
function states.applyDefaults()
  for _, s in ipairs(kanban.defaults.taskStates) do
    if config.get({ "taskStates", s.name }, nil) == nil then
      config.set({ "taskStates", s.name }, kanban.util.shallowCopy(s))
    end
  end
end

---Whether CONFIG set a complete list of task states.
---@return boolean
function states.customized()
  return config.get({ "kanban", "customStates" }, false) == true
end

---Sets the complete list of task states (use in CONFIG). Every state not in a
---non-empty list stops existing, the library's defaults included, and tasks
---left in such states go back to `[ ]` once the scripts reload. An empty
---list goes back to the defaults. Each entry is
---`{ name, order?, done?, todo?, column? }`: `todo = true` also puts plain
---`[ ]` tasks in that state's column, and `column = true` gives a done state
---its own column.
---@param list kanban.StateSpec[]
function kanban.taskStates(list)
  local valid, problems = kanban.defaults.validateStates(list)
  states.problems = kanban.util.map(problems, function(p)
    return "kanban.taskStates: " .. p
  end)
  if #valid == 0 then
    config.set("taskStates", kanban.defaults.stateMap(kanban.defaults.taskStates))
    config.set({ "kanban", "customStates" }, false)
    return
  end
  config.set("taskStates", kanban.defaults.stateMap(valid))
  config.set({ "kanban", "customStates" }, true)
end

---Writes the current task states into CONFIG as an editable
---`kanban.taskStates { ... }` list, unless CONFIG already has one.
---@param pageName string|nil defaults to "CONFIG"
---@return boolean written
function states.customize(pageName)
  pageName = pageName or "CONFIG"
  local open = editor.getCurrentPage() == pageName
  local text = ""
  if open then
    text = editor.getText()
  else
    local ok, existing = pcall(space.readPage, pageName)
    if ok and existing then
      text = existing
    end
  end
  if string.find(text, "kanban.taskStates", 1, true) then
    editor.flashNotification(pageName .. " already lists the task states: edit them there.")
    if not open then
      editor.navigate(pageName)
    end
    return false
  end
  local current = kanban.defaults.stateList(config.get("taskStates", {}))
  local updated = kanban.defaults.insertIntoConfig(text, kanban.defaults.configBlock(current))
  if open then
    editor.replaceRange(0, #text, updated)
  else
    space.writePage(pageName, updated)
    editor.navigate(pageName)
  end
  editor.flashNotification "Edit the task states in CONFIG, then run System: Reload."
  return true
end
