describe("kanban.model snapshots", function()
  local function row(ref, page, from, state, name, extra)
    local r = { ref = ref, page = page, range = { from, from + 10 }, state = state, name = name }
    for k, v in pairs(extra or {}) do
      r[k] = v
    end
    return kanban.tasks.fromIndex(r)
  end

  local all = {
    row("api", "P", 0, "DOING", "Ship API", { tags = { "backend" } }),
    row("P@20", "P", 20, "TODO", "Build web", { blockedBy = { "[[$api]]", "[[$gone]]" } }),
  }

  local function build()
    local spec = kanban.config.normalize { columns = { "TODO", "DOING" } }
    return kanban.model.build(spec, all, { DOING = { name = "DOING" } }, {})
  end

  local function hasFunctions(v, seen)
    seen = seen or {}
    if type(v) == "function" then
      return true
    elseif type(v) ~= "table" or seen[v] then
      return false
    end
    seen[v] = true
    for k, x in pairs(v) do
      if hasFunctions(k, seen) or hasFunctions(x, seen) then
        return true
      end
    end
    return false
  end

  it("turns a board into plain data keyed by card id", function()
    local s = kanban.model.snapshot(build())
    assert.are.equal(kanban.apiVersion, s.apiVersion)
    assert.is_false(hasFunctions(s))
    assert.are.same(
      { "1", "2" },
      kanban.util.map(s.columns, function(c)
        return c.id
      end)
    )
    assert.are.same({ "P@20" }, s.columns[1].cards)
    assert.are.same({
      id = "P@20",
      title = "Build web",
      page = "P",
      done = false,
      column = "1",
      state = "TODO",
      tags = {},
      blockedBy = { "api", "gone" },
      blockers = { "api" },
      blocks = {},
      openBlockers = 1,
      missing = { "gone" },
      inCycle = false,
    }, s.cards["P@20"])
    assert.are.same({ "P@20" }, s.cards.api.blocks)
    assert.are.equal("api", s.cards.api.anchor)
  end)

  it("does not share tables with the model", function()
    local m = build()
    local s = kanban.model.snapshot(m)
    s.cards.api.tags[1] = "changed"
    s.cards["P@20"].blockedBy[1] = "changed"
    assert.are.equal("backend", m.cards.api.task.tags[1])
    assert.are.equal("api", m.cards["P@20"].task.blockedBy[1])
  end)

  it("adds valid outside badges to known cards only", function()
    local m = build()
    local added = kanban.model.addBadges(m, {
      api = { { kind = "x", text = "From outside" }, { text = "no kind" }, "junk" },
      ["nope@1"] = { { kind = "x", text = "lost" } },
    })
    assert.are.equal(1, added)
    assert.are.equal("From outside", m.cards.api.badges[1].text)
    assert.are.equal(0, kanban.model.addBadges(m, "not a table"))
  end)
end)
