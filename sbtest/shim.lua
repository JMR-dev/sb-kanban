-- SPDX-License-Identifier: Apache-2.0
--
-- The subset of busted that specs may use (stds.bustedSubset in .luacheckrc),
-- reimplemented in portable Lua so the same specs also run inside a real
-- SilverBullet through the Runtime API (sbtest/runtime.spec.ts).
--
-- sbtest/runtime.spec.ts inlines this file as the body of a function and
-- keeps the returned table in a local, then runs each spec inside
-- `do local describe, it, before_each, assert = ... end`. Nothing here assigns
-- a global, so the live client is left untouched (its builtin `assert`
-- included).
--
-- Differences from busted: `it` runs immediately, so `before_each` must come
-- before the `it`s it applies to (reported as a failure otherwise), and
-- error-message comparisons strip a leading "file:line: " the way luassert
-- does, since Space Lua's error() adds none.

local results = { passed = 0, failures = {} }
local frames = {}

local function currentName(name)
  local parts = {}
  for _, frame in ipairs(frames) do
    parts[#parts + 1] = frame.name
  end
  parts[#parts + 1] = name
  return table.concat(parts, " ")
end

local function record(name, ok, message)
  if ok then
    results.passed = results.passed + 1
  else
    results.failures[#results.failures + 1] = { name = name, message = tostring(message) }
  end
end

local function sortedKeys(t)
  local keys = {}
  for k in pairs(t) do
    keys[#keys + 1] = k
  end
  table.sort(keys, function(a, b)
    return tostring(a) < tostring(b)
  end)
  return keys
end

local function show(v, depth)
  depth = depth or 0
  if type(v) == "string" then
    return string.format("%q", v)
  elseif type(v) ~= "table" then
    return tostring(v)
  elseif depth >= 3 then
    return "{...}"
  end
  local parts = {}
  for _, k in ipairs(sortedKeys(v)) do
    parts[#parts + 1] = tostring(k) .. " = " .. show(v[k], depth + 1)
  end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

local function same(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return a == b
  end
  for k, v in pairs(a) do
    if not same(v, b[k]) then
      return false
    end
  end
  for k in pairs(b) do
    if a[k] == nil then
      return false
    end
  end
  return true
end

local function fail(message, extra)
  if extra ~= nil then
    message = tostring(extra) .. ": " .. message
  end
  error("assertion failed: " .. message, 0)
end

local function stripPosition(message)
  if type(message) ~= "string" then
    return message
  end
  local stripped = string.gsub(message, "^.-:%d+: ", "", 1)
  return stripped
end

local assertions = {
  are = {
    same = function(expected, actual, extra)
      if not same(expected, actual) then
        fail("expected " .. show(expected) .. ", got " .. show(actual), extra)
      end
    end,
    equal = function(expected, actual, extra)
      if expected ~= actual then
        fail("expected " .. show(expected) .. ", got " .. show(actual), extra)
      end
    end,
  },
  is_true = function(v, extra)
    if v ~= true then
      fail("expected true, got " .. show(v), extra)
    end
  end,
  is_false = function(v, extra)
    if v ~= false then
      fail("expected false, got " .. show(v), extra)
    end
  end,
  is_nil = function(v, extra)
    if v ~= nil then
      fail("expected nil, got " .. show(v), extra)
    end
  end,
  has_error = function(fn, expected, extra)
    local ok, err = pcall(fn)
    if ok then
      fail("expected an error", extra)
    elseif expected ~= nil and stripPosition(err) ~= expected then
      fail("expected error " .. show(expected) .. ", got " .. show(stripPosition(err)), extra)
    end
  end,
}
setmetatable(assertions, {
  __call = function(_, v, message, ...)
    if not v then
      error(message or "assertion failed!", 0)
    end
    return v, message, ...
  end,
})

local shim = { assert = assertions }

function shim.describe(name, fn)
  frames[#frames + 1] = { name = name, hooks = {}, ranIt = false }
  local ok, err = pcall(fn)
  if not ok then
    record(currentName "(describe block)", false, err)
  end
  frames[#frames] = nil
end

function shim.before_each(fn)
  local frame = frames[#frames]
  if frame == nil then
    record("before_each", false, "before_each outside describe")
  elseif frame.ranIt then
    record(
      currentName "(before_each)",
      false,
      "before_each must come before the `it`s it applies to"
    )
  else
    frame.hooks[#frame.hooks + 1] = fn
  end
end

function shim.it(name, fn)
  local fullName = currentName(name)
  if frames[#frames] then
    frames[#frames].ranIt = true
  end
  local ok, err = pcall(function()
    for _, frame in ipairs(frames) do
      for _, hook in ipairs(frame.hooks) do
        hook()
      end
    end
    fn()
  end)
  record(fullName, ok, err)
end

function shim.results()
  return results
end

return shim
