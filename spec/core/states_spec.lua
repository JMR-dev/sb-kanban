describe("kanban.states", function()
  local states = kanban.states

  local function names(normalized)
    return kanban.util.map(normalized.list, function(s)
      return s.name
    end)
  end

  it("has the built-in states with no configuration", function()
    local st = states.normalize(nil)
    assert.are.same({ " ", "X", "x" }, names(st))
    assert.is_false(states.isDone(" ", st))
    assert.is_true(states.isDone("x", st))
    assert.is_true(states.isDone("X", st))
  end)

  it("orders custom states by order then name, done states last", function()
    local st = states.normalize {
      REVIEW = { name = "REVIEW", order = 2 },
      DOING = { name = "DOING", order = 1 },
      BLOCKED = { name = "BLOCKED", order = 1 },
      SHIPPED = { name = "SHIPPED", done = true, order = 9 },
    }
    assert.are.same({ " ", "BLOCKED", "DOING", "REVIEW", "SHIPPED", "X", "x" }, names(st))
  end)

  it("computes done-ness from the definitions, not task.done", function()
    local st = states.normalize { SHIPPED = { name = "SHIPPED", done = true } }
    assert.is_true(states.isDone("SHIPPED", st))
    assert.is_false(states.isDone("TODO", st))
    assert.is_false(states.isDone("UNKNOWN", st))
  end)

  it("uses the config key when a definition has no name", function()
    local st = states.normalize { WAITING = { order = 3 } }
    assert.is_false(st.byName.WAITING.done)
    assert.are.equal(3, st.byName.WAITING.order)
  end)
end)
