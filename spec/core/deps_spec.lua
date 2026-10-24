describe("kanban.deps.resolve", function()
  local function task(ref, page, state, blockedBy)
    local anchor = nil
    if not string.find(ref, "@", 1, true) then
      anchor = ref
    end
    return {
      ref = ref,
      page = page,
      state = state,
      anchor = anchor,
      blockedBy = blockedBy or {},
      badLinks = {},
      name = ref,
    }
  end

  local st = kanban.states.normalize { SHIPPED = { name = "SHIPPED", done = true } }
  local function isDone(s)
    return kanban.states.isDone(s, st)
  end

  local function refs(list)
    return kanban.util.map(list, function(t)
      return t.ref
    end)
  end

  it("links blockers across pages and counts the open ones", function()
    local api = task("api", "Projects/Backend", "TODO")
    local db = task("db", "Projects/Backend", "SHIPPED")
    local web = task("Projects/Web@10", "Projects/Web", "TODO", { "api", "db" })
    local d = kanban.deps.resolve({ api, db, web }, isDone)
    assert.are.same({ "api", "db" }, refs(d[web.ref].blockers))
    assert.are.equal(1, d[web.ref].openBlockers)
    assert.are.same({ "Projects/Web@10" }, refs(d.api.blocks))
    assert.are.same({ "Projects/Web@10" }, refs(d.db.blocks))
    assert.are.same({}, d[web.ref].missing)
    assert.is_false(d[web.ref].inCycle)
  end)

  it("reports anchors that match no task", function()
    local t = task("P@0", "P", "TODO", { "gone", "also-gone" })
    local d = kanban.deps.resolve({ t }, isDone)
    assert.are.same({ "gone", "also-gone" }, d[t.ref].missing)
    assert.are.equal(0, d[t.ref].openBlockers)
  end)

  it("counts a repeated blocker once", function()
    local a = task("a", "P", "TODO")
    local b = task("P@9", "P", "TODO", { "a", "a" })
    local d = kanban.deps.resolve({ a, b }, isDone)
    assert.are.equal(1, #d[b.ref].blockers)
    assert.are.equal(1, d[b.ref].openBlockers)
  end)

  it("finds cycles and self-blocks", function()
    local a = task("a", "P", "TODO", { "b" })
    local b = task("b", "P", "TODO", { "c" })
    local c = task("c", "P", "TODO", { "a" })
    local selfish = task("s", "P", "TODO", { "s" })
    local outside = task("o", "P", "TODO", { "a" })
    local d = kanban.deps.resolve({ outside, a, b, c, selfish }, isDone)
    assert.is_true(d.a.inCycle)
    assert.is_true(d.b.inCycle)
    assert.is_true(d.c.inCycle)
    assert.is_true(d.s.inCycle)
    assert.is_false(d.o.inCycle)
  end)

  it("passes through bad blockedBy values", function()
    local t = task("P@0", "P", "TODO")
    t.badLinks = { "[[Page]]" }
    local d = kanban.deps.resolve({ t }, isDone)
    assert.are.same({ "[[Page]]" }, d[t.ref].badLinks)
  end)
end)
