-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- kanban.sb.data against the real index of the fixture space
-- (sbtest/space/Projects/*, CONFIG.md).

local function find(list, name)
  for _, t in ipairs(list) do
    if t.name == name then
      return t
    end
  end
  return nil
end

describe("kanban.sb.data", function()
  it("reads every task as a core task", function()
    local all = kanban.sb.data.allTasks()
    local api = find(all, "Ship the API")
    assert.is_true(api ~= nil, "Ship the API")
    assert.are.equal("api-v2", api.anchor)
    assert.are.equal("api-v2", api.ref)
    assert.are.equal("Projects/Backend", api.page)
    assert.are.equal("DOING", api.state)
    assert.is_true(type(api.from) == "number" and api.to > api.from, "range")

    local web = find(all, "Build the web client")
    assert.is_nil(web.anchor)
    assert.are.same({ "api-v2", "db" }, web.blockedBy)
    assert.are.equal("Projects/Web@" .. web.from, web.ref)
  end)

  it("reads the task states defined in CONFIG", function()
    local defs = kanban.sb.data.stateDefs()
    assert.are.equal(1, defs.DOING.order)
    assert.is_true(defs.SHIPPED.done)
  end)

  it("knows which anchors are taken", function()
    local taken = kanban.sb.data.takenAnchors()
    assert.is_true(taken["api-v2"] == true, "api-v2")
    assert.is_true(taken["deps-one"] == true, "deps-one")
    assert.is_nil(taken["no-such-task"])
  end)

  it("builds a model with cross-page dependencies", function()
    local spec = kanban.config.normalize { pagePrefix = "Projects/" }
    local m = kanban.sb.data.model(spec)
    local titles = kanban.util.map(m.columns, function(c)
      return c.title
    end)
    assert.are.same({ "To do", "TODO", "DOING", "Done" }, titles)
    local web = nil
    for _, card in pairs(m.cards) do
      if card.title == "Build the web client" then
        web = card
      end
    end
    assert.are.equal(2, #web.deps.blockers)
    -- The database task is done ([x]); only the API is still open.
    assert.are.equal(1, web.deps.openBlockers)
    assert.are.equal("blocked", web.badges[1].kind)
  end)

  it("honours a Lua API task list", function()
    local rows = query [[from t = index.tasks() where t.page == "Projects/Web"]]
    local spec = kanban.config.normalize { tasks = rows, columns = { "TODO", " " } }
    local m = kanban.sb.data.model(spec)
    local n = 0
    for _ in pairs(m.cards) do
      n = n + 1
    end
    assert.are.equal(#rows, n)
  end)
end)
