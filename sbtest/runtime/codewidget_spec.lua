-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- The `kanban` fenced block is registered with SilverBullet and renders.
-- (2.12's codeWidget.render syscall only knows plug widgets, so the spec
-- calls the registered Space Lua definition directly.)

local function definition()
  return config.get { "codeWidgets", "kanban" }
end

describe("kanban code widget", function()
  it("is registered and renders a board", function()
    local def = definition()
    assert.is_true(def ~= nil and type(def.render) == "function", "no kanban code widget")
    assert.is_true(def.render("page: Move/Tasks\n", "Boards/Move") ~= nil, "render returned nil")
  end)

  it("reports invalid YAML instead of failing", function()
    local ok, w = pcall(definition().render, "page: [unclosed\n", "Boards/Bad")
    assert.is_true(ok, tostring(w))
    assert.is_true(w ~= nil, "render returned nil")
  end)

  it("exposes the Lua API", function()
    assert.are.equal("function", type(kanban.board))
    assert.are.equal(1, kanban.apiVersion)
  end)
end)
