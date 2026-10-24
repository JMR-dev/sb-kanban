-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- Extensions provided as SilverBullet services (the seam a TypeScript plug
-- would use), with real service.define/discover/invoke. Services cannot be
-- removed again, so the ones defined here only answer while `active.on` is
-- set, and are switched off at the end.

local active = { on = true }

service.define {
  selector = "kanban:decorator",
  match = function()
    if active.on then
      return { priority = 1, name = "sbtest.decorator" }
    end
  end,
  run = function(snapshot)
    local out = {}
    for id, card in pairs(snapshot.cards) do
      if card.title == "Ship the API" then
        out[id] = { { kind = "fromService", text = "From a service", tone = "ok" } }
      end
    end
    return out
  end,
}

service.define {
  selector = "kanban:moveGuard",
  match = function()
    if active.on then
      return { priority = 1, name = "sbtest.guard" }
    end
  end,
  run = function(move)
    if move.card.title == "Ship the API" and move.to.done then
      return { allowed = false, reason = "The service says no." }
    end
    return true
  end,
}

describe("kanban service bridge", function()
  local spec = kanban.config.normalize { pagePrefix = "Projects/" }

  local function cardTitled(m, title)
    for _, card in pairs(m.cards) do
      if card.title == title then
        return card
      end
    end
  end

  it("adds badges from decorator services", function()
    local m = kanban.sb.data.model(spec)
    local api = cardTitled(m, "Ship the API")
    local kinds = kanban.util.map(api.badges, function(b)
      return b.kind
    end)
    assert.is_true(kanban.util.contains(kinds, "fromService"), table.concat(kinds, ","))
    assert.are.same({}, m.errors)
  end)

  it("lets move-guard services refuse a move", function()
    local m = kanban.sb.data.model(spec)
    local api = cardTitled(m, "Ship the API")
    local done = m.columns[#m.columns]
    local plan = kanban.moves.plan(m, api.id, done.id, kanban.registry.list "guards")
    assert.is_true(plan.ok)
    assert.are.same({ "The service says no." }, kanban.sb.bridge.checkMove(plan.move))
  end)

  it("lets other moves through", function()
    local m = kanban.sb.data.model(spec)
    local docs = cardTitled(m, "Write the API docs")
    local plan = kanban.moves.plan(m, docs.id, m.columns[#m.columns].id, {})
    assert.are.same({}, kanban.sb.bridge.checkMove(plan.move))
    active.on = false
  end)
end)
