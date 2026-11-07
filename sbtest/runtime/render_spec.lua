-- SPDX-License-Identifier: Apache-2.0
--
-- kanban.sb.render builds real DOM inside SilverBullet's client.

describe("kanban.sb.render", function()
  local spec = kanban.config.normalize { pagePrefix = "Projects/" }

  it("draws a column per state and a card per task", function()
    local m = kanban.sb.data.model(spec)
    local el = kanban.sb.render.boardElement(spec, m, {})
    assert.are.equal(4, el.querySelectorAll(".sbk-column").length)
    local cards = 0
    for _ in pairs(m.cards) do
      cards = cards + 1
    end
    assert.are.equal(cards, el.querySelectorAll(".sbk-card").length)
    assert.are.equal(cards, el.querySelectorAll(".sbk-move").length)
  end)

  it("shows task text literally, never as HTML or Markdown", function()
    local m = kanban.sb.data.model(spec)
    local el = kanban.sb.render.boardElement(spec, m, {})
    assert.is_nil(el.querySelector ".sbk-card-title b")
    assert.is_nil(el.querySelector ".sbk-card-title strong")
    local text = el.textContent
    assert.is_true(string.find(text, "Show <b>this</b> **literally**", 1, true) ~= nil, text)
  end)

  it("lists option problems above the board", function()
    local bad, errors = kanban.config.normalize { pgae = "x", includeDone = "no" }
    local el = kanban.sb.render.boardElement(bad, kanban.sb.data.model(bad), errors)
    assert.are.equal(2, el.querySelectorAll(".sbk-problem").length)
  end)
end)
