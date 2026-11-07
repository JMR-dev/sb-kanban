-- SPDX-License-Identifier: Apache-2.0
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
