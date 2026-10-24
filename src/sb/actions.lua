-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- What the board's controls do. Each action rebuilds the model from the
-- current index (so it acts on fresh data, not on what was rendered), plans
-- with the pure core, writes through kanban.sb.write and reports problems
-- with a notification. The board re-renders by itself once the index sees
-- the change.

kanban = kanban or {}
kanban.sb = kanban.sb or {}
kanban.sb.actions = kanban.sb.actions or {}
local actions = kanban.sb.actions

local function notifyError(message)
  editor.flashNotification(message, "error")
end

local function cardIn(m, cardId)
  local card = m.cards[cardId]
  if card == nil then
    notifyError "That task is no longer on this board."
  end
  return card
end

---Moves a card to a column (drag and drop, or the "Move to" menu).
---@param spec kanban.Spec
---@param cardId string
---@param columnId string
---@return boolean moved
function actions.move(spec, cardId, columnId)
  local m = kanban.sb.data.model(spec)
  local plan = kanban.moves.plan(m, cardId, columnId, kanban.registry.list "guards")
  if plan.noop then
    return false
  end
  if not plan.ok then
    notifyError(table.concat(plan.reasons, " "))
    return false
  end
  local ok, message = kanban.sb.write.setState(plan.move.card.task, plan.move.targetState)
  if not ok then
    notifyError(message)
    return false
  end
  return true
end

---Opens a task in the editor, by anchor when it has one.
---@param task kanban.Task
function actions.open(task)
  if task.anchor then
    editor.navigate("$" .. task.anchor)
  else
    editor.navigate(kanban.tasks.positionRef(task))
  end
end

---Opens one of the tasks a badge points at (asking which, if several).
---@param refs string[]
function actions.openRefs(refs)
  local byRef = {}
  for _, t in ipairs(kanban.sb.data.allTasks()) do
    byRef[t.ref] = t
  end
  local found = kanban.util.filter(
    kanban.util.map(refs, function(r)
      return byRef[r]
    end),
    function(t)
      return t ~= nil
    end
  )
  if #found == 0 then
    notifyError "Those tasks are gone."
    return
  elseif #found == 1 then
    actions.open(found[1])
    return
  end
  local options = kanban.util.map(found, function(t)
    return { name = t.name, description = t.page, ref = t.ref }
  end)
  local choice = editor.filterBox("Open", options, "Pick a task to open")
  if choice and byRef[choice.ref] then
    actions.open(byRef[choice.ref])
  end
end

---Asks for a task and records it as a blocker of the card's task, giving the
---blocker an anchor first if it has none. Blockers can be on any page.
---@param spec kanban.Spec
---@param cardId string
---@return boolean added
function actions.addBlocker(spec, cardId)
  local m = kanban.sb.data.model(spec)
  local card = cardIn(m, cardId)
  if card == nil then
    return false
  end
  local current = card.task.blockedBy
  local options, byRef = {}, {}
  for _, t in ipairs(kanban.sb.data.allTasks()) do
    local isCurrent = t.anchor ~= nil and kanban.util.contains(current, t.anchor)
    if t.ref ~= card.id and not isCurrent and not kanban.states.isDone(t.state, m.states) then
      -- Only plain values in options: they travel to the UI and back.
      options[#options + 1] = { name = t.name, description = t.page, ref = t.ref }
      byRef[t.ref] = t
    end
  end
  if #options == 0 then
    notifyError "There are no open tasks to add as a blocker."
    return false
  end
  local choice = editor.filterBox("Blocked by", options, "Pick the task this one waits for")
  local blocker = choice and byRef[choice.ref]
  if blocker == nil then
    return false
  end
  local anchor, delta = kanban.sb.write.ensureAnchor(blocker)
  if anchor == nil then
    notifyError(delta)
    return false
  end
  local task = card.task
  -- The new anchor lengthened the blocker's line; shift this task if it comes
  -- later on the same page.
  if blocker.page == task.page and blocker.from < task.from and delta ~= 0 then
    task = {}
    for k, v in pairs(card.task) do
      task[k] = v
    end
    task.from = task.from + delta
    task.to = task.to + delta
  end
  local anchors = {}
  for i, a in ipairs(current) do
    anchors[i] = a
  end
  anchors[#anchors + 1] = anchor
  local ok, message = kanban.sb.write.setBlockedBy(task, anchors)
  if not ok then
    notifyError(message)
    return false
  end
  return true
end

---Asks which blocker to drop and removes it from the card's task.
---@param spec kanban.Spec
---@param cardId string
---@return boolean removed
function actions.removeBlocker(spec, cardId)
  local m = kanban.sb.data.model(spec)
  local card = cardIn(m, cardId)
  if card == nil then
    return false
  end
  local options = {}
  local byAnchor = {}
  for _, b in ipairs(card.deps.blockers) do
    byAnchor[b.anchor] = b
  end
  for _, anchor in ipairs(card.task.blockedBy) do
    local b = byAnchor[anchor]
    if b then
      options[#options + 1] = { name = b.name, description = b.page, anchor = anchor }
    else
      options[#options + 1] =
        { name = "$" .. anchor, description = "missing task", anchor = anchor }
    end
  end
  if #options == 0 then
    notifyError "This task has no blockers."
    return false
  end
  local choice = editor.filterBox("Remove blocker", options, "Pick the blocker to remove")
  if choice == nil then
    return false
  end
  local anchors = kanban.util.filter(card.task.blockedBy, function(a)
    return a ~= choice.anchor
  end)
  local ok, message = kanban.sb.write.setBlockedBy(card.task, anchors)
  if not ok then
    notifyError(message)
    return false
  end
  return true
end
