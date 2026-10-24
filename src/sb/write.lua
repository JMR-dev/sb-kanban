-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- The only code that changes pages. SilverBullet 2.12 has no object API, so:
-- task states go through the index plug's own updateTaskState (with a
-- "Page@pos" ref), and attribute/anchor edits are splices of the task's line,
-- computed by the pure core (src/core/edit.lua).
--
-- Every write first checks that the indexed range still holds the task's
-- line, and afterwards reads the page back to confirm the change landed.
-- When either check fails the task moved since the board was drawn (the index
-- lags edits by a moment), and the write reports that instead of guessing.
--
-- A later backend for SilverBullet's object API (Edge builds) would only
-- change this file.

kanban = kanban or {}
kanban.sb = kanban.sb or {}
kanban.sb.write = kanban.sb.write or {}
local write = kanban.sb.write

write.staleMessage = "This task changed since the board was drawn. Try again in a moment."

-- The page text as the editor would save it: the open buffer for the page in
-- the editor, else the stored page.
local function readPage(page)
  if editor.getCurrentPage() == page then
    return editor.getText(), true
  end
  return space.readPage(page), false
end

local function lineAt(text, task)
  return string.sub(text, task.from + 1, task.to)
end

-- The task's current line, if the indexed range still holds it.
local function currentLine(task)
  local text, open = readPage(task.page)
  local line = lineAt(text, task)
  local parsed = kanban.edit.parse(line)
  if parsed == nil or parsed.state ~= task.state then
    return nil
  end
  if not string.find(parsed.rest, task.name, 1, true) then
    return nil
  end
  return line, text, open
end

local function replaceLine(task, text, open, newLine)
  if open then
    editor.replaceRange(task.from, task.to, newLine)
  else
    local before = string.sub(text, 1, task.from)
    local after = string.sub(text, task.to + 1)
    space.writePage(task.page, before .. newLine .. after)
  end
end

local function landed(task, newLine)
  local text = readPage(task.page)
  return string.sub(text, task.from + 1, task.from + #newLine) == newLine
end

---Sets a task's state.
---@param task kanban.Task
---@param newState string
---@return boolean ok
---@return string|nil message why not
function write.setState(task, newState)
  local line = currentLine(task)
  if line == nil then
    return false, write.staleMessage
  end
  system.invokeFunction(
    "index.updateTaskState",
    kanban.tasks.positionRef(task),
    task.state,
    newState
  )
  local parsed = kanban.edit.parse(line)
  local newLine = parsed.prefix .. newState .. "]" .. parsed.rest
  if not landed(task, newLine) then
    return false, write.staleMessage
  end
  return true
end

---Sets a task's `blockedBy` attribute to exactly `anchors`.
---@param task kanban.Task
---@param anchors string[]
---@return boolean ok
---@return string|nil message why not
function write.setBlockedBy(task, anchors)
  local line, text, open = currentLine(task)
  if line == nil then
    return false, write.staleMessage
  end
  local newLine = kanban.edit.setBlockedBy(line, anchors)
  if newLine ~= line then
    replaceLine(task, text, open, newLine)
    if not landed(task, newLine) then
      return false, write.staleMessage
    end
  end
  return true
end

---Gives a task an anchor if it has none.
---@param task kanban.Task
---@return string|nil anchor the task's anchor
---@return string|integer messageOrDelta how many characters the line grew by, or why it failed
function write.ensureAnchor(task)
  if task.anchor then
    return task.anchor, 0
  end
  local line, text, open = currentLine(task)
  if line == nil then
    return nil, write.staleMessage
  end
  local id = kanban.ids.new(task.name, kanban.sb.data.takenAnchors())
  local newLine, anchor = kanban.edit.addAnchor(line, id)
  if newLine ~= line then
    replaceLine(task, text, open, newLine)
    if not landed(task, newLine) then
      return nil, write.staleMessage
    end
  end
  return anchor, #newLine - #line
end
