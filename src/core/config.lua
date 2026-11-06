-- SPDX-License-Identifier: Apache-2.0
-- priority: 50

-- Board options, from a `kanban` fenced block (parsed YAML) or a Lua table
-- passed to `kanban.board`. Validation collects every problem so a board can
-- show them all at once. No option is called `query` or `using`: those are
-- keywords in Space Lua.

kanban = kanban or {}
kanban.config = kanban.config or {}
local config = kanban.config

---@class kanban.ColumnSpec
---@field ref string|nil a column name, resolved against the default columns
---@field title string|nil
---@field states string[]|nil
---@field dropState string|nil

---@class kanban.Spec
---@field title string|nil
---@field pages string[]
---@field pagePrefixes string[]
---@field tags string[]
---@field includeDone boolean
---@field columns kanban.ColumnSpec[]|nil nil means "derive from task states"
---@field rules { blockDone: boolean }
---@field tasks table[]|nil Lua API only: rows to use instead of index.tasks()

local known = {
  title = true,
  page = true,
  pagePrefix = true,
  tag = true,
  includeDone = true,
  columns = true,
  rules = true,
  tasks = true,
}

local function stringList(v, name, errors)
  local list = kanban.util.asList(v)
  if type(v) == "table" or v == nil or type(v) == "string" then
    for _, item in ipairs(list) do
      if type(item) ~= "string" then
        errors[#errors + 1] = "`" .. name .. "` must be a string or a list of strings"
        return {}
      end
    end
    return list
  end
  errors[#errors + 1] = "`" .. name .. "` must be a string or a list of strings"
  return {}
end

local function columnSpec(entry, i, errors)
  if type(entry) == "string" then
    -- A name: resolved against the default columns in kanban.columns.build.
    return { ref = entry }
  elseif type(entry) ~= "table" then
    errors[#errors + 1] = "column " .. i .. " must be a state name or a table"
    return nil
  end
  local list = {}
  if entry.state ~= nil then
    list[#list + 1] = entry.state
  end
  for _, s in ipairs(kanban.util.asList(entry.states)) do
    if not kanban.util.contains(list, s) then
      list[#list + 1] = s
    end
  end
  if #list == 0 then
    errors[#errors + 1] = "column " .. i .. " needs `state` or `states`"
    return nil
  end
  for _, s in ipairs(list) do
    if type(s) ~= "string" then
      errors[#errors + 1] = "column " .. i .. ": states must be strings"
      return nil
    end
  end
  if entry.title ~= nil and type(entry.title) ~= "string" then
    errors[#errors + 1] = "column " .. i .. ": `title` must be a string"
  end
  local dropState = entry.dropState or list[1]
  if not kanban.util.contains(list, dropState) then
    errors[#errors + 1] = "column " .. i .. ": `dropState` must be one of its states"
    dropState = list[1]
  end
  return { title = entry.title, states = list, dropState = dropState }
end

---Validates and normalizes board options.
---@param raw table|nil
---@return kanban.Spec spec
---@return string[] errors
function config.normalize(raw)
  local errors = {}
  if raw ~= nil and type(raw) ~= "table" then
    return config.normalize(nil), { "board options must be a table (YAML mapping)" }
  end
  raw = raw or {}
  for _, key in ipairs(kanban.util.sortedKeys(raw)) do
    if not known[key] then
      errors[#errors + 1] = "unknown option `" .. tostring(key) .. "`"
    end
  end

  local spec = {
    title = nil,
    pages = stringList(raw.page, "page", errors),
    pagePrefixes = stringList(raw.pagePrefix, "pagePrefix", errors),
    tags = stringList(raw.tag, "tag", errors),
    includeDone = true,
    columns = nil,
    rules = { blockDone = false },
    tasks = nil,
  }

  if raw.title ~= nil then
    if type(raw.title) == "string" then
      spec.title = raw.title
    else
      errors[#errors + 1] = "`title` must be a string"
    end
  end
  if raw.includeDone ~= nil then
    if type(raw.includeDone) == "boolean" then
      spec.includeDone = raw.includeDone
    else
      errors[#errors + 1] = "`includeDone` must be true or false"
    end
  end
  if raw.columns ~= nil then
    if type(raw.columns) ~= "table" then
      errors[#errors + 1] = "`columns` must be a list"
    else
      spec.columns = {}
      for i, entry in ipairs(raw.columns) do
        local c = columnSpec(entry, i, errors)
        if c then
          spec.columns[#spec.columns + 1] = c
        end
      end
    end
  end
  if raw.rules ~= nil then
    if type(raw.rules) ~= "table" then
      errors[#errors + 1] = "`rules` must be a table"
    else
      for _, key in ipairs(kanban.util.sortedKeys(raw.rules)) do
        if key ~= "blockDone" then
          errors[#errors + 1] = "unknown rule `" .. tostring(key) .. "`"
        end
      end
      if raw.rules.blockDone ~= nil then
        if type(raw.rules.blockDone) == "boolean" then
          spec.rules.blockDone = raw.rules.blockDone
        else
          errors[#errors + 1] = "`rules.blockDone` must be true or false"
        end
      end
    end
  end
  if raw.tasks ~= nil then
    if type(raw.tasks) == "table" then
      spec.tasks = raw.tasks
    else
      errors[#errors + 1] = "`tasks` must be a list of tasks"
    end
  end
  return spec, errors
end
