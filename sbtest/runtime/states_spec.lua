-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Default task states, kanban.taskStates from CONFIG, and the commands that
-- write pre-filled boards and state lists, inside real SilverBullet. The
-- fixture CONFIG (sbtest/space/CONFIG.md) sets a complete list; specs that
-- change it put it back.

local fixtureStates = {
  { name = "TODO", order = 0 },
  { name = "DOING", order = 1 },
  { name = "SHIPPED", order = 9, done = true },
  { name = "Retired", order = 10, done = true },
}

local function stateNames()
  local names = {}
  for _, s in ipairs(kanban.defaults.stateList(config.get("taskStates", {}))) do
    names[#names + 1] = s.name
  end
  return names
end

local fence = string.rep("`", 3)

describe("task states", function()
  it("uses the complete list from CONFIG", function()
    assert.are.same({ "TODO", "DOING", "SHIPPED", "Retired" }, stateNames())
    assert.is_true(kanban.sb.states.customized())
    assert.are.same({}, kanban.sb.states.problems)
  end)

  it("goes back to the library defaults for an empty list", function()
    kanban.taskStates {}
    assert.is_false(kanban.sb.states.customized())
    local normalized = kanban.states.normalize(config.get("taskStates", {}))
    assert.are.same({
      "Backlog",
      "Ready for Development",
      "In Progress",
      "Blocked",
      "Cancelled",
      "Done",
    }, kanban.columns.defaultTitles(normalized))
    kanban.taskStates(fixtureStates)
    assert.is_true(kanban.sb.states.customized())
  end)

  it("reports problems with the list and keeps the valid states", function()
    kanban.taskStates { { name = "OK" }, { name = "x" } }
    assert.are.same({ "OK" }, stateNames())
    assert.are.same(
      { "kanban.taskStates: task state 2: `x` is built in" },
      kanban.sb.states.problems
    )
    kanban.taskStates(fixtureStates)
    assert.are.same({}, kanban.sb.states.problems)
  end)

  it("writes the current states into a CONFIG page once", function()
    space.writePage("Scratch/CONFIG", fence .. "space-lua\n-- mine\n" .. fence .. "\n")
    assert.is_true(kanban.sb.states.customize "Scratch/CONFIG")
    local text = space.readPage "Scratch/CONFIG"
    assert.is_true(string.find(text, "-- mine\n-- Kanban task states", 1, true) ~= nil, text)
    assert.is_true(string.find(text, '{ name = "DOING", order = 1 },', 1, true) ~= nil, text)
    assert.is_true(
      string.find(text, '{ name = "Retired", order = 10, done = true },', 1, true) ~= nil
    )
    assert.is_false(kanban.sb.states.customize "Scratch/CONFIG")
    editor.navigate "index"
  end)

  it("inserts a board with the current columns written out", function()
    editor.navigate "Scratch/Board"
    kanban.sb.insertBoard()
    local text = editor.getText()
    local expected = fence
      .. "kanban\npage: Scratch/Board\ncolumns:\n  - To do\n  - TODO\n  - DOING\n  - Done\n"
      .. fence
    assert.is_true(string.find(text, expected, 1, true) ~= nil, text)
    editor.navigate "index"
  end)
end)
