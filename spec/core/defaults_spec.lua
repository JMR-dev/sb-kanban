describe("kanban.defaults", function()
  local defaults = kanban.defaults

  local function normalizedDefaults()
    return kanban.states.normalize(defaults.stateMap(defaults.taskStates))
  end

  local function titles(cols)
    return kanban.util.map(cols, function(c)
      return c.title
    end)
  end

  it("ships the default task states, with Done last", function()
    assert.are.same({
      "Backlog",
      "Ready for Development",
      "In Progress",
      "Blocked",
      "Cancelled",
      "Done",
    }, kanban.columns.defaultTitles(normalizedDefaults()))
  end)

  it("puts plain [ ] tasks in Backlog and writes Backlog on drops there", function()
    local cols = kanban.columns.build(kanban.config.normalize(nil), normalizedDefaults())
    assert.are.same({ "Backlog", " " }, cols[1].states)
    assert.are.equal("Backlog", cols[1].dropState)
    assert.are.equal("Backlog", kanban.columns.forState(cols, " ").title)
  end)

  it("gives Cancelled its own column but counts it as done", function()
    local st = normalizedDefaults()
    local cols = kanban.columns.build(kanban.config.normalize(nil), st)
    local cancelled = cols[5]
    assert.are.equal("Cancelled", cancelled.title)
    assert.is_true(cancelled.done)
    assert.is_true(kanban.states.isDone("Cancelled", st))
    assert.are.same({ "x", "X" }, cols[6].states)
  end)

  it("lets a board drop default columns by leaving their names out", function()
    local spec = kanban.config.normalize { columns = { "In Progress", "Backlog", "Done" } }
    local cols = kanban.columns.build(spec, normalizedDefaults())
    assert.are.same({ "In Progress", "Backlog", "Done" }, titles(cols))
    assert.are.same({ "Backlog", " " }, cols[2].states)
  end)

  it("resolves a name by column title, then by state, else as a state", function()
    local spec = kanban.config.normalize { columns = { "x", " ", "Someday" } }
    local cols = kanban.columns.build(spec, normalizedDefaults())
    assert.are.same({ "Done", "Backlog", "Someday" }, titles(cols))
    assert.are.same({ "Someday" }, cols[3].states)
  end)

  it("hides Cancelled and Done when done tasks are hidden", function()
    local cols =
      kanban.columns.build(kanban.config.normalize { includeDone = false }, normalizedDefaults())
    assert.are.same({ "Backlog", "Ready for Development", "In Progress", "Blocked" }, titles(cols))
  end)

  it("counts a cancelled blocker as finished", function()
    local function row(ref, state, extra)
      local r = { ref = ref, page = "P", range = { 0, 5 }, state = state, name = ref }
      for k, v in pairs(extra or {}) do
        r[k] = v
      end
      return kanban.tasks.fromIndex(r)
    end
    local all = { row("old", "Cancelled"), row("P@9", "Blocked", { blockedBy = "[[$old]]" }) }
    local m = kanban.model.build(
      kanban.config.normalize(nil),
      all,
      defaults.stateMap(defaults.taskStates),
      {}
    )
    assert.are.equal(0, m.cards["P@9"].deps.openBlockers)
  end)

  describe("validateStates", function()
    it("keeps valid states and normalizes their flags", function()
      local valid, problems = defaults.validateStates {
        { name = "A", order = 1, todo = true },
        { name = "B", done = true, column = true, extra = "dropped" },
      }
      assert.are.same({}, problems)
      assert.are.same({
        { name = "A", order = 1, todo = true },
        { name = "B", done = true, column = true },
      }, valid)
    end)

    it("reports problems and skips those entries", function()
      local valid, problems = defaults.validateStates {
        { name = "A" },
        { order = 1 },
        { name = "x" },
        { name = "a:b" },
        { name = "A" },
        { name = "C", order = "1" },
        { name = "D", todo = true, done = true },
        { name = "E", todo = true },
        { name = "F", todo = true },
      }
      assert.are.same(
        { "A", "E" },
        kanban.util.map(valid, function(s)
          return s.name
        end)
      )
      assert.are.same({
        "task state 2 needs a `name`",
        "task state 3: `x` is built in",
        "task state 4: names cannot contain `:` or `]`",
        "task state 5: `A` is listed twice",
        "task state 6: `order` must be a number",
        "task state 7: a done state cannot hold `[ ]` tasks",
        "task state 9: only one state can hold `[ ]` tasks (E already does)",
      }, problems)
      local _, notAList = defaults.validateStates "nope"
      assert.are.same({ "kanban.taskStates needs a list of states" }, notAList)
    end)
  end)

  it("turns a state map back into an ordered list", function()
    local map = defaults.stateMap(defaults.taskStates)
    assert.are.same(defaults.taskStates, defaults.stateList(map))
  end)

  it("writes a board block with the columns spelled out", function()
    local block = defaults.boardBlock("Projects/Web site", { "Backlog", "In Progress", "Done" })
    local fence = string.rep("`", 3)
    assert.are.equal(
      table.concat({
        fence .. "kanban",
        "page: Projects/Web site",
        "columns:",
        "  - Backlog",
        "  - In Progress",
        "  - Done",
        fence,
        "",
      }, "\n"),
      block
    )
  end)

  it("quotes YAML values that need it", function()
    local block = defaults.boardBlock('Odd: "page"', { " ", "x" })
    assert.is_true(string.find(block, 'page: "Odd: \\"page\\""', 1, true) ~= nil, block)
    assert.is_true(string.find(block, '  - " "', 1, true) ~= nil, block)
  end)

  it("writes a CONFIG block with the states listed", function()
    local text = defaults.configBlock(defaults.taskStates)
    assert.is_true(string.find(text, "kanban.taskStates {", 1, true) ~= nil)
    assert.is_true(
      string.find(text, '  { name = "Backlog", order = 0, todo = true },', 1, true) ~= nil
    )
    assert.is_true(
      string.find(text, '  { name = "Cancelled", order = 4, done = true, column = true },', 1, true)
        ~= nil
    )
  end)
end)

describe("kanban.defaults.insertIntoConfig", function()
  local fence = string.rep("`", 3)
  local snippet = "kanban.taskStates {}\n"

  it("appends to the user's block, not the Configuration Manager's", function()
    local config = table.concat({
      "# Config",
      fence .. "space-lua",
      "-- managed-by: configuration-manager",
      'config.set("a", 1)',
      fence,
      "",
      fence .. "space-lua",
      'taskState.define { name = "X1" }',
      fence,
      "",
    }, "\n")
    local out = kanban.defaults.insertIntoConfig(config, snippet)
    local expected = table.concat({
      "# Config",
      fence .. "space-lua",
      "-- managed-by: configuration-manager",
      'config.set("a", 1)',
      fence,
      "",
      fence .. "space-lua",
      'taskState.define { name = "X1" }',
      "kanban.taskStates {}",
      fence,
      "",
    }, "\n")
    assert.are.equal(expected, out)
  end)

  it("adds a block when there is no user block", function()
    local out = kanban.defaults.insertIntoConfig("# Config\n", snippet)
    assert.are.equal("# Config\n\n" .. fence .. "space-lua\n" .. snippet .. fence .. "\n", out)
  end)
end)
