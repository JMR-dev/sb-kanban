describe("kanban.config.normalize", function()
  local normalize = kanban.config.normalize

  it("has defaults", function()
    local spec, errors = normalize(nil)
    assert.are.same({}, errors)
    assert.are.same({}, spec.pages)
    assert.are.same({}, spec.pagePrefixes)
    assert.are.same({}, spec.tags)
    assert.is_true(spec.includeDone)
    assert.is_nil(spec.columns)
    assert.is_false(spec.rules.blockDone)
  end)

  it("accepts single values and lists for filters", function()
    local spec, errors = normalize {
      page = "Projects/Alpha",
      pagePrefix = { "Projects/", "Areas/" },
      tag = "urgent",
      title = "Alpha",
      includeDone = false,
      rules = { blockDone = true },
    }
    assert.are.same({}, errors)
    assert.are.same({ "Projects/Alpha" }, spec.pages)
    assert.are.same({ "Projects/", "Areas/" }, spec.pagePrefixes)
    assert.are.same({ "urgent" }, spec.tags)
    assert.are.equal("Alpha", spec.title)
    assert.is_false(spec.includeDone)
    assert.is_true(spec.rules.blockDone)
  end)

  it("normalizes column forms", function()
    local spec, errors = normalize {
      columns = {
        " ",
        { state = "DOING", title = "In progress" },
        { states = { "x", "SHIPPED" }, title = "Done" },
        { states = { "WAIT", "HOLD" }, dropState = "HOLD" },
      },
    }
    assert.are.same({}, errors)
    assert.are.same({
      { ref = " " },
      { title = "In progress", states = { "DOING" }, dropState = "DOING" },
      { title = "Done", states = { "x", "SHIPPED" }, dropState = "x" },
      { states = { "WAIT", "HOLD" }, dropState = "HOLD" },
    }, spec.columns)
  end)

  it("reports every problem", function()
    local _, errors = normalize {
      pgae = "typo",
      tag = 3,
      includeDone = "yes",
      columns = { {}, { state = "A", dropState = "B" }, 7 },
      rules = { blockDone = "on", other = true },
    }
    assert.are.same({
      "unknown option `pgae`",
      "`tag` must be a string or a list of strings",
      "`includeDone` must be true or false",
      "column 1 needs `state` or `states`",
      "column 2: `dropState` must be one of its states",
      "column 3 must be a state name or a table",
      "unknown rule `other`",
      "`rules.blockDone` must be true or false",
    }, errors)
  end)

  it("rejects options that are not a table", function()
    local spec, errors = normalize "page: x"
    assert.are.same({ "board options must be a table (YAML mapping)" }, errors)
    assert.is_true(spec.includeDone)
  end)
end)
