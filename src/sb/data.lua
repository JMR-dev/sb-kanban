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
