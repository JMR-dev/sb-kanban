local dialect = dofile "tools/check_dialect.lua"

local function messages(src)
  local out = {}
  for _, f in ipairs(dialect.check(src)) do
    out[#out + 1] = f.line .. ": " .. f.message
  end
  return out
end

local function hasFinding(src, needle)
  for _, m in ipairs(messages(src)) do
    if string.find(m, needle, 1, true) then
      return true
    end
  end
  return false
end

describe("check_dialect", function()
  it("accepts ordinary Space Lua", function()
    local src = [=[
local open = query [[from t = index.tasks() where not t.done]]
local rows = query[[from t = index.tasks()]]
local first = rows[1]
if a ~= b then x = a // 2 end
local s = "query" .. 'using' -- query using global != & | ~
--[==[ long comment, level 2 ]==]
kanban = kanban or {}
]=]
    assert.are.same({}, messages(src))
  end)

  it("rejects `global` declarations", function()
    assert.is_true(hasFinding("global x = 1", "`global`"))
  end)

  it("rejects `query` and `using` as names", function()
    assert.is_true(hasFinding("local query = 1", "only `query [[...]]`"))
    assert.is_true(hasFinding("cfg.query = 1", "only `query [[...]]`"))
    assert.is_true(hasFinding("local t = { query = 1 }", "only `query [[...]]`"))
    assert.is_true(hasFinding("obj:query [[x]]", "only `query [[...]]`"))
    assert.is_true(hasFinding("local using = 2", "`using`"))
  end)

  it("rejects indexing a query result directly", function()
    assert.is_true(hasFinding("local t = query[[from x]][1]", "assign the result"))
    assert.is_true(hasFinding("local n = query [[from x]].n", "assign the result"))
  end)

  it("rejects `!=` and bitwise operators", function()
    assert.is_true(hasFinding("if a != b then end", "`!=`"))
    assert.is_true(hasFinding("local x = a & b", "bitwise"))
    assert.is_true(hasFinding("local x = a | b", "bitwise"))
    assert.is_true(hasFinding("local x = a ~ b", "bitwise"))
    assert.is_true(hasFinding("local x = ~a", "bitwise"))
    assert.is_true(hasFinding("local x = a << 2", "bitwise"))
    assert.is_true(hasFinding("local x = a >> 2", "bitwise"))
  end)

  it("rejects long brackets above level 2", function()
    assert.is_true(hasFinding("local s = [===[x]===]", "level 2"))
    assert.is_true(hasFinding("--[===[ c ]===]", "level 2"))
  end)

  it("rejects unsupported metamethods", function()
    assert.is_true(hasFinding("setmetatable(t, { __gc = f })", "`__gc`"))
    assert.is_true(hasFinding('local k = "__mode"', "`__mode`"))
    assert.is_true(hasFinding("local m = { __metatable = false }", "`__metatable`"))
  end)

  it("rejects `_G`", function()
    assert.is_true(hasFinding("for k in pairs(_G) do end", "`_G`"))
    assert.is_true(hasFinding("local s = _G.string", "`_G`"))
  end)

  it("reports the right line", function()
    local found = dialect.check "local a = 1\n\nlocal b = a & 1\n"
    assert.are.equal(3, found[1].line)
  end)

  it("keeps counting lines through long strings and comments", function()
    local found = dialect.check "local s = [[\n\n]]\n--[[\n]]\nlocal b = a & 1\n"
    assert.are.equal(6, found[1].line)
  end)
end)
