-- SPDX-License-Identifier: Apache-2.0
-- priority: 50

-- Anchor names for tasks that get linked from the board: a readable slug of
-- the task name plus a short random suffix (`ship-the-api-3f2a`). Anchors must
-- be unique across the whole space.

kanban = kanban or {}
kanban.ids = kanban.ids or {}
local ids = kanban.ids

---Whether `name` is a valid SilverBullet anchor name.
---@param name any
---@return boolean
function ids.isValid(name)
  return type(name) == "string" and string.match(name, "^[%a_][%w_/:%-]*$") ~= nil
end

---A lower-case, dash-separated slug of a task name (at most 24 characters,
---starting with a letter).
---@param name string|nil
---@return string
function ids.slug(name)
  local s = string.lower(name or "")
  s = string.gsub(s, "[^%w]+", "-")
  s = string.gsub(s, "^%-+", "")
  s = string.sub(s, 1, 24)
  s = string.gsub(s, "%-+$", "")
  if s == "" then
    return "task"
  elseif not string.match(s, "^%a") then
    return "t-" .. s
  end
  return s
end

---A new anchor name for a task called `name` that is not in `taken`.
---@param name string|nil
---@param taken table<string, boolean>
---@param random (fun(m: integer, n: integer): integer)|nil defaults to math.random
---@return string
function ids.new(name, taken, random)
  random = random or math.random
  local hex = "0123456789abcdef"
  local base = ids.slug(name)
  for _ = 1, 100 do
    local digits = {}
    for i = 1, 4 do
      local k = random(1, 16)
      digits[i] = string.sub(hex, k, k)
    end
    local id = base .. "-" .. table.concat(digits)
    if not taken[id] then
      return id
    end
  end
  error("could not find a free anchor name for " .. base)
end
