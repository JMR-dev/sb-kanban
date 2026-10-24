-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- Pure edits of one task line (`* [STATE] name [key: value] $anchor`):
-- reading and rewriting the `blockedBy` attribute and adding an anchor.
-- SilverBullet 2.12 has no object API for this, so the adapter
-- (src/sb/write.lua) splices these lines into pages after checking that the
-- indexed range still holds the expected line.

kanban = kanban or {}
kanban.edit = kanban.edit or {}
local edit = kanban.edit

local anchorPattern = "%$([%a_][%w_/:%-]*)"

---Splits a task line into the part up to "[", the state, and the rest
---(after "]"), or returns nil for a line that is not a task.
---@param line string
---@return { prefix: string, state: string, rest: string }|nil
function edit.parse(line)
  local prefix, state, rest = string.match(line, "^(%s*[%*%-%+]%s+%[)([^%]]*)%](.*)$")
  if prefix == nil then
    prefix, state, rest = string.match(line, "^(%s*%d+[%.%)]%s+%[)([^%]]*)%](.*)$")
  end
  if prefix == nil then
    return nil
  end
  return { prefix = prefix, state = state, rest = rest }
end

---The start and end index of the `[key: ...]` attribute in `line`, honouring
---nested brackets and quoted strings, or nil.
---@param line string
---@param key string
---@return integer|nil, integer|nil
function edit.attributeSpan(line, key)
  local search = 1
  while true do
    local s, e = string.find(line, "[" .. key .. ":", search, true)
    if s == nil then
      return nil
    end
    -- "[[key:" would be a wiki link, not an attribute.
    if string.sub(line, s - 1, s - 1) ~= "[" then
      local depth, quote, i = 0, nil, s
      while i <= #line do
        local c = string.sub(line, i, i)
        if quote then
          if c == "\\" then
            i = i + 1
          elseif c == quote then
            quote = nil
          end
        elseif c == '"' or c == "'" then
          quote = c
        elseif c == "[" then
          depth = depth + 1
        elseif c == "]" then
          depth = depth - 1
          if depth == 0 then
            return s, i
          end
        end
        i = i + 1
      end
      return nil
    end
    search = e + 1
  end
end

---The anchor names in the line's `blockedBy` attribute, in order.
---@param line string
---@return string[]
function edit.blockedByOf(line)
  local s, e = edit.attributeSpan(line, "blockedBy")
  local out = {}
  if s then
    for name in string.gmatch(string.sub(line, s, e), anchorPattern) do
      out[#out + 1] = name
    end
  end
  return out
end

---The task's own anchor (`$name` outside brackets), or nil.
---@param line string
---@return string|nil
function edit.anchorOf(line)
  local parsed = edit.parse(line)
  local rest = parsed and parsed.rest or line
  -- Drop wiki links and attributes, which may contain `$name` themselves.
  local outside = string.gsub(rest, "%b[]", " ")
  return string.match(" " .. outside, "%s" .. anchorPattern)
end

---@param anchors string[]
---@return string
function edit.renderBlockedBy(anchors)
  local links = kanban.util.map(anchors, function(a)
    return '"[[$' .. a .. ']]"'
  end)
  if #links == 1 then
    return "[blockedBy: " .. links[1] .. "]"
  end
  return "[blockedBy: [" .. table.concat(links, ", ") .. "]]"
end

-- Inserts `text` at the end of the line, before a trailing `$anchor` if any.
local function insertBeforeTrailingAnchor(line, text)
  local body, anchor = string.match(line, "^(.-)(%s+%$[%a_][%w_/:%-]*)%s*$")
  if body then
    return body .. " " .. text .. anchor
  end
  return (string.gsub(line, "%s+$", "")) .. " " .. text
end

---Sets the line's `blockedBy` attribute to exactly `anchors` (removing it
---when the list is empty).
---@param line string
---@param anchors string[]
---@return string
function edit.setBlockedBy(line, anchors)
  local s, e = edit.attributeSpan(line, "blockedBy")
  if s == nil then
    if #anchors == 0 then
      return line
    end
    return insertBeforeTrailingAnchor(line, edit.renderBlockedBy(anchors))
  end
  local before, after = string.sub(line, 1, s - 1), string.sub(line, e + 1)
  if #anchors > 0 then
    return before .. edit.renderBlockedBy(anchors) .. after
  end
  before = string.gsub(before, "%s+$", "")
  if after == "" or string.match(after, "^%s") then
    return before .. after
  end
  return before .. " " .. after
end

---Adds ` $id` unless the line already has an anchor. Returns the new line and
---the anchor the task now has.
---@param line string
---@param id string
---@return string, string
function edit.addAnchor(line, id)
  local existing = edit.anchorOf(line)
  if existing then
    return line, existing
  end
  return (string.gsub(line, "%s+$", "")) .. " $" .. id, id
end
