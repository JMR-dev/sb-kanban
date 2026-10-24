-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- The library's view of a task: a plain table built from an index row, so
-- the rest of the core never touches SilverBullet's objects.

kanban = kanban or {}
kanban.tasks = kanban.tasks or {}
local tasks = kanban.tasks

---@class kanban.Task
---@field ref string the index ref: the anchor name when anchored, else "Page@pos"
---@field page string
---@field from integer start offset of the task's list line on its page
---@field to integer end offset (exclusive) of that line
---@field name string
---@field state string
---@field tags string[]
---@field anchor string|nil
---@field blockedBy string[] anchor names from the `blockedBy` attribute
---@field badLinks string[] `blockedBy` values that are not `[[$anchor]]` links

---Parses one `blockedBy` value: `[[$name]]` (optionally `[[$name|alias]]`)
---or a bare `$name`. Returns nil for anything else.
---@param value any
---@return string|nil
function tasks.parseAnchorLink(value)
  if type(value) ~= "string" then
    return nil
  end
  local v = kanban.util.trim(value)
  local inner = string.match(v, "^%[%[(.-)%]%]$")
  if inner then
    v = string.match(inner, "^([^|]*)") or inner
  end
  local name = string.match(v, "^%$([%a_][%w_/:%-]*)$")
  return name
end

---Builds a task from an `index.tasks()` row.
---@param row table
---@return kanban.Task
function tasks.fromIndex(row)
  local blockedBy, badLinks = {}, {}
  for _, value in ipairs(kanban.util.asList(row.blockedBy)) do
    local name = tasks.parseAnchorLink(value)
    if name then
      blockedBy[#blockedBy + 1] = name
    else
      badLinks[#badLinks + 1] = tostring(value)
    end
  end
  local ref = row.ref
  local anchor = nil
  if not string.match(ref, "@%d+$") then
    anchor = ref
  end
  local range = row.range or {}
  return {
    ref = ref,
    page = row.page,
    from = range[1],
    to = range[2],
    name = row.name or "",
    state = row.state or " ",
    tags = kanban.util.asList(row.tags),
    anchor = anchor,
    blockedBy = blockedBy,
    badLinks = badLinks,
  }
end

---The "Page@pos" ref SilverBullet's task functions need, even for anchored
---tasks (index.updateTaskState ignores anchor refs on 2.12).
---@param task kanban.Task
---@return string
function tasks.positionRef(task)
  return task.page .. "@" .. tostring(task.from)
end

local function onAnyPage(task, pages)
  return #pages == 0 or kanban.util.contains(pages, task.page)
end

local function underAnyPrefix(task, prefixes)
  if #prefixes == 0 then
    return true
  end
  for _, prefix in ipairs(prefixes) do
    if kanban.util.startsWith(task.page, prefix) then
      return true
    end
  end
  return false
end

local function hasAnyTag(task, wanted)
  if #wanted == 0 then
    return true
  end
  for _, tag in ipairs(wanted) do
    if kanban.util.contains(task.tags, tag) then
      return true
    end
  end
  return false
end

---Keeps the tasks a board spec selects (pages, page prefixes, tags; each
---filter matches any of its values, and all given filters must match).
---@param list kanban.Task[]
---@param spec table normalized board spec
---@return kanban.Task[]
function tasks.select(list, spec)
  return kanban.util.filter(list, function(task)
    return onAnyPage(task, spec.pages)
      and underAnyPrefix(task, spec.pagePrefixes)
      and hasAnyTag(task, spec.tags)
  end)
end
