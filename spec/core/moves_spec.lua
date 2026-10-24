describe("kanban.moves.plan", function()
  local stateDefs = { DOING = { name = "DOING", order = 1 } }

  local function row(ref, state, extra)
    local r = { ref = ref, page = "P", range = { 0, 10 }, state = state, name = ref }
    for k, v in pairs(extra or {}) do
      r[k] = v
    end
    return kanban.tasks.fromIndex(r)
  end

  local all = {
    row("blocker", "DOING"),
    row("P@20", " ", { blockedBy = "[[$blocker]]" }),
    row("P@40", " "),
  }

  local function build(fields)
    local spec = kanban.config.normalize(fields)
    return kanban.model.build(spec, all, stateDefs, {})
  end

  local guards = { kanban.builtins.blockDone }

  it("plans a move into another column", function()
    local m = build {}
    local plan = kanban.moves.plan(m, "P@40", "2", guards)
    assert.is_true(plan.ok)
    assert.are.equal("DOING", plan.move.targetState)
    assert.are.equal("1", plan.move.from.id)
  end)

  it("writes the column's drop state when it holds several states", function()
    local m = build {}
    local plan = kanban.moves.plan(m, "P@40", "3", guards)
    assert.is_true(plan.ok)
    assert.are.equal("x", plan.move.targetState)
    assert.is_true(plan.move.to.done)
  end)

  it("treats a move within the same column as a no-op", function()
    local plan = kanban.moves.plan(build {}, "P@40", "1", guards)
    assert.is_false(plan.ok)
    assert.is_true(plan.noop)
  end)

  it("refuses unknown cards and columns", function()
    local m = build {}
    assert.are.same(
      { "That task is no longer on this board." },
      kanban.moves.plan(m, "nope", "1").reasons
    )
    assert.are.same({ "That column no longer exists." }, kanban.moves.plan(m, "P@40", "99").reasons)
  end)

  it("allows moving a blocked card to Done unless the rule is on", function()
    assert.is_true(kanban.moves.plan(build {}, "P@20", "3", guards).ok)
    local plan = kanban.moves.plan(build { rules = { blockDone = true } }, "P@20", "3", guards)
    assert.is_false(plan.ok)
    assert.are.same({ "Blocked by 1 open task: blocker" }, plan.reasons)
  end)

  it("only applies the rule to done columns", function()
    local plan = kanban.moves.plan(build { rules = { blockDone = true } }, "P@20", "2", guards)
    assert.is_true(plan.ok)
  end)

  it("collects reasons from every guard and survives failing guards", function()
    local extra = {
      {
        name = "no",
        check = function()
          return false, "Nope."
        end,
      },
      {
        name = "broken",
        check = function()
          error "boom"
        end,
      },
      {
        name = "silent",
        check = function()
          return false
        end,
      },
    }
    local plan = kanban.moves.plan(build {}, "P@40", "2", extra)
    assert.is_false(plan.ok)
    assert.are.equal(3, #plan.reasons)
    assert.is_true(kanban.util.contains(plan.reasons, "Nope."))
    assert.is_true(kanban.util.contains(plan.reasons, "Refused by silent."))
  end)
end)
