describe("kanban.columns", function()
  local customStates = kanban.states.normalize {
    DOING = { name = "DOING", order = 1 },
    SHIPPED = { name = "SHIPPED", done = true, order = 9 },
  }

  local function spec(fields)
    local s = kanban.config.normalize(fields)
    return s
  end

  local function summary(cols)
    return kanban.util.map(cols, function(c)
      return { c.title, c.states, c.dropState, c.done }
    end)
  end

  it("derives columns from task states, merging done states", function()
    local cols = kanban.columns.build(spec {}, customStates)
    assert.are.same({
      { "To do", { " " }, " ", false },
      { "DOING", { "DOING" }, "DOING", false },
      { "Done", { "x", "SHIPPED", "X" }, "x", true },
    }, summary(cols))
    assert.are.same(
      { "1", "2", "3" },
      kanban.util.map(cols, function(c)
        return c.id
      end)
    )
  end)

  it("leaves out done columns when done tasks are hidden", function()
    local cols = kanban.columns.build(spec { includeDone = false }, customStates)
    assert.are.same(
      { "To do", "DOING" },
      kanban.util.map(cols, function(c)
        return c.title
      end)
    )
  end)

  it("uses explicit columns as given", function()
    local cols = kanban.columns.build(
      spec { columns = { "DOING", { states = { "x", "SHIPPED" } } } },
      customStates
    )
    assert.are.same({
      { "DOING", { "DOING" }, "DOING", false },
      { "Done", { "x", "SHIPPED" }, "x", true },
    }, summary(cols))
  end)

  it("finds the column for a state", function()
    local cols = kanban.columns.build(spec {}, customStates)
    assert.are.equal("Done", kanban.columns.forState(cols, "SHIPPED").title)
    assert.is_nil(kanban.columns.forState(cols, "NOPE"))
  end)
end)
