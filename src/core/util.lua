-- SPDX-License-Identifier: Apache-2.0
-- priority: 50

-- Small helpers for the pure core. Standard Lua only (no Space Lua string
-- extensions), so the same code runs on Lua 5.5.1 in the unit tests.

kanban = kanban or {}
kanban.util = kanban.util or {}
local util = kanban.util

---Escapes text for use inside HTML element content or attribute values.
---@param s string
---@return string
function util.escapeHtml(s)
  local escaped = string.gsub(tostring(s), "[&<>\"']", {
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;",
    ["'"] = "&#39;",
  })
  return escaped
end

---@param s string
---@return string
function util.trim(s)
  return (string.match(s, "^%s*(.-)%s*$"))
end

---@param s string
---@param prefix string
---@return boolean
function util.startsWith(s, prefix)
  return string.sub(s, 1, #prefix) == prefix
end

---Turns nil into {}, a single value into { value }, and leaves lists alone.
---@param v any
---@return any[]
function util.asList(v)
  if v == nil then
    return {}
  elseif type(v) == "table" then
    return v
  end
  return { v }
end

---@param list any[]
---@param value any
---@return boolean
function util.contains(list, value)
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

---@param list any[]
---@param fn fun(v: any): any
---@return any[]
function util.map(list, fn)
  local out = {}
  for i, v in ipairs(list) do
    out[i] = fn(v)
  end
  return out
end

---@param list any[]
---@param fn fun(v: any): boolean
---@return any[]
function util.filter(list, fn)
  local out = {}
  for _, v in ipairs(list) do
    if fn(v) then
      out[#out + 1] = v
    end
  end
  return out
end

---A shallow copy of a table.
---@generic T: table
---@param t T
---@return T
function util.shallowCopy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = v
  end
  return out
end

---The keys of `t`, sorted, for iteration that does not depend on `pairs`
---order (which differs between Space Lua and reference Lua).
---@param t table
---@return any[]
function util.sortedKeys(t)
  local keys = {}
  for k in pairs(t) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)
  return keys
end
