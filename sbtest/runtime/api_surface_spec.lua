-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Every name in tools/sb_api.lua (prepended as `sbApi`) must exist on the
-- pinned SilverBullet. luacheck only lets the library use what that list
-- allows, so together they guarantee the library uses nothing the release
-- lacks.
--
-- Names are resolved with `load("return <name>")`, which looks them up the
-- same way library code does. (`_G` is no help here: in Space Lua it is a
-- userdata proxy that `pairs` cannot enumerate; see docs/compat.md.)

local function resolve(expr)
  local chunk = load("return " .. expr)
  if chunk == nil then
    return nil
  end
  local ok, value = pcall(chunk)
  if ok then
    return value
  end
  return nil
end

local function present(expr)
  return resolve(expr) ~= nil
end

local function isFunction(expr)
  return type(resolve(expr)) == "function"
end

describe("SilverBullet API surface (tools/sb_api.lua)", function()
  it("has the allowlisted standard library globals", function()
    for _, name in ipairs(sbApi.stdlib.globals) do
      assert.is_true(present(name), name)
    end
  end)

  it("has the allowlisted standard library fields", function()
    for lib, fields in pairs(sbApi.stdlib.tables) do
      for _, field in ipairs(fields) do
        assert.is_true(present(lib .. "." .. field), lib .. "." .. field)
      end
    end
  end)

  it("has the allowlisted Space Lua extensions", function()
    for lib, fields in pairs(sbApi.extensions) do
      for _, field in ipairs(fields) do
        assert.is_true(isFunction(lib .. "." .. field), lib .. "." .. field)
      end
    end
  end)

  it("has every allowlisted SilverBullet function", function()
    for ns, fields in pairs(sbApi.namespaces) do
      assert.is_true(present(ns), ns)
      if fields == true then
        assert.is_true(isFunction(ns .. ".div"), ns .. ".div")
      else
        for _, field in ipairs(fields) do
          assert.is_true(isFunction(ns .. "." .. field), ns .. "." .. field)
        end
      end
    end
  end)

  it("has the names the in-SilverBullet specs use", function()
    for _, name in ipairs(sbApi.testOnly.globals) do
      assert.is_true(present(name), name)
    end
    for ns, fields in pairs(sbApi.testOnly.namespaces) do
      for _, field in ipairs(fields) do
        assert.is_true(isFunction(ns .. "." .. field), ns .. "." .. field)
      end
    end
  end)

  it("still lacks what the allowlist deliberately leaves out", function()
    -- Sanity check that `resolve` can tell a missing name from a present one.
    assert.is_nil(resolve "string.escapeHtml")
    assert.is_nil(resolve "unpack")
  end)
end)
