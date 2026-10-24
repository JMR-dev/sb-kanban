describe("kanban.model.build", function()
  local stateDefs = {
    DOING = { name = "DOING", order = 1 },
    SHIPPED = { name = "SHIPPED", done = true },
  }

  local function row(ref, page, from, state, name, extra)
    local r = { ref = ref, page = page, range = { from, from + 10 }, state = state, name = name }
    for k, v in pairs(extra or {}) do
      r[k] = v
    end
    return kanban.tasks.fromIndex(r)
  end

  local all = {
    row("api", "Backend", 30, "DOING", "Ship API"),
    row("Web@5", "Web", 5, "TODO", "Build web", { blockedBy = "[[$api]]" }),
    row("Backend@0", "Backend", 0, " ", "Write spec"),
    row("Backend@60", "Backend", 60, "SHIPPED", "Old thing"),
    row("Other@0", "Other", 0, " ", "Elsewhere"),
  }

  local function spec(fields)
    local s = kanban.config.normalize(fields)
    return s
  end

  local function titles(cards)
    return kanban.util.map(cards, function(c)
      return c.title
    end)
  end

  it("places selected tasks in their state's column, ordered by page and position", function()
    local m = kanban.model.build(spec { page = { "Backend", "Web" } }, all, stateDefs, {})
    assert.are.same({ "To do", "DOING", "Done" }, titles(m.columns))
    assert.are.same({ "Write spec" }, titles(m.columns[1].cards))
    assert.are.same({ "Ship API" }, titles(m.columns[2].cards))
    assert.are.same({ "Old thing" }, titles(m.columns[3].cards))
    -- TODO is not a defined state, so no derived column takes it.
    assert.are.same({ "Build web" }, titles(m.unplaced))
    assert.are.equal("2", m.cards.api.column)
    assert.is_nil(m.cards["Web@5"].column)
    assert.is_true(m.cards["Backend@60"].done)
  end)

  it("hides done tasks and the done column when asked", function()
    local m = kanban.model.build(spec { page = "Backend", includeDone = false }, all, stateDefs, {})
    assert.are.same({ "To do", "DOING" }, titles(m.columns))
    assert.is_nil(m.cards["Backend@60"])
  end)

  it("resolves dependencies against every task, not just the board's", function()
    local m = kanban.model.build(spec { page = "Web", columns = { "TODO" } }, all, stateDefs, {})
    local card = m.cards["Web@5"]
    assert.are.equal("api", card.deps.blockers[1].ref)
    assert.are.equal(1, card.deps.openBlockers)
  end)

  it("uses a given task list instead of the filters", function()
    local s = spec { page = "Nowhere" }
    s.tasks = { all[2] }
    local m = kanban.model.build(s, all, stateDefs, {})
    assert.are.same({ "Build web" }, titles(m.unplaced))
    assert.are.equal("api", m.cards["Web@5"].deps.blockers[1].ref)
  end)

  it("runs decorators by priority and keeps only valid badges", function()
    local order = {}
    local decorators = {
      {
        name = "low",
        decorate = function(card)
          order[#order + 1] = "low:" .. card.title
          return { { kind = "k", text = "low" }, { text = "no kind" }, "junk" }
        end,
      },
      {
        name = "high",
        priority = 5,
        decorate = function(card)
          order[#order + 1] = "high:" .. card.title
          return { { kind = "k", text = "high" } }
        end,
      },
    }
    local m = kanban.model.build(spec { page = "Other" }, all, stateDefs, decorators)
    assert.are.same({ "high:Elsewhere", "low:Elsewhere" }, order)
    assert.are.same(
      { "high", "low" },
      kanban.util.map(m.cards["Other@0"].badges, function(b)
        return b.text
      end)
    )
    assert.are.same({}, m.errors)
  end)

  it("records a failing decorator instead of failing the board", function()
    local decorators = {
      {
        name = "broken",
        decorate = function()
          error "boom"
        end,
      },
    }
    local m = kanban.model.build(spec { page = "Other" }, all, stateDefs, decorators)
    assert.are.equal(1, #m.errors)
    assert.is_true(string.find(m.errors[1], "decorator broken failed", 1, true) == 1)
    assert.are.same({}, m.cards["Other@0"].badges)
  end)

  it("adds the built-in dependency badges", function()
    local m = kanban.model.build(
      spec { page = { "Backend", "Web" }, columns = { "TODO", "DOING" } },
      all,
      stateDefs,
      { kanban.builtins.dependencies }
    )
    local web = m.cards["Web@5"].badges
    assert.are.equal("blocked", web[1].kind)
    assert.are.equal("Blocked by 1", web[1].text)
    assert.are.same({ "api" }, web[1].refs)
    local api = m.cards.api.badges
    assert.are.equal("blocks", api[1].kind)
    assert.are.same({ "Web@5" }, api[1].refs)
  end)
end)
