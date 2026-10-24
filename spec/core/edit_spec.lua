describe("kanban.edit", function()
  local edit = kanban.edit

  it("parses task lines", function()
    local p = edit.parse "  * [TODO] ship it [due: 2026-11-01]"
    assert.are.same({ prefix = "  * [", state = "TODO", rest = " ship it [due: 2026-11-01]" }, p)
    assert.are.equal(" ", edit.parse("- [ ] x").state)
    assert.are.equal("x", edit.parse("1. [x] done").state)
    assert.is_nil(edit.parse "just text")
  end)

  it("finds attribute spans through nested brackets and quotes", function()
    local line = '* [ ] a [blockedBy: ["[[$x]]", "[[$y]]"]] [note: "a ] b"] tail'
    local s, e = edit.attributeSpan(line, "blockedBy")
    assert.are.equal('[blockedBy: ["[[$x]]", "[[$y]]"]]', string.sub(line, s, e))
    local ns, ne = edit.attributeSpan(line, "note")
    assert.are.equal('[note: "a ] b"]', string.sub(line, ns, ne))
    assert.is_nil(edit.attributeSpan("* [ ] [[blockedBy: page]]", "blockedBy"))
  end)

  it("reads blockedBy anchors", function()
    assert.are.same({ "x", "y" }, edit.blockedByOf '* [ ] a [blockedBy: ["[[$x]]", "[[$y]]"]]')
    assert.are.same({ "x" }, edit.blockedByOf '* [ ] a [blockedBy: "[[$x]]"]')
    assert.are.same({}, edit.blockedByOf "* [ ] a")
  end)

  it("finds the task's own anchor, not anchors it links to", function()
    assert.are.equal("me", edit.anchorOf '* [ ] task [blockedBy: "[[$other]]"] $me')
    assert.are.equal("me", edit.anchorOf "* [ ] $me first")
    assert.is_nil(edit.anchorOf '* [ ] task [blockedBy: "[[$other]]"] see [[$x]]')
    assert.is_nil(edit.anchorOf "* [ ] costs $5")
  end)

  describe("setBlockedBy", function()
    it("adds the attribute, before a trailing anchor", function()
      assert.are.equal('* [ ] a [blockedBy: "[[$x]]"]', edit.setBlockedBy("* [ ] a", { "x" }))
      assert.are.equal(
        '* [ ] a [blockedBy: "[[$x]]"] $me',
        edit.setBlockedBy("* [ ] a $me", { "x" })
      )
    end)

    it("replaces the attribute, as a list when there are several", function()
      assert.are.equal(
        '* [ ] a [blockedBy: ["[[$x]]", "[[$y]]"]] #tag',
        edit.setBlockedBy('* [ ] a [blockedBy: "[[$x]]"] #tag', { "x", "y" })
      )
    end)

    it("removes the attribute when no blockers remain", function()
      assert.are.equal("* [ ] a #tag", edit.setBlockedBy('* [ ] a [blockedBy: "[[$x]]"] #tag', {}))
      assert.are.equal("* [ ] a", edit.setBlockedBy('* [ ] a [blockedBy: "[[$x]]"]', {}))
      assert.are.equal("* [ ] a", edit.setBlockedBy("* [ ] a", {}))
    end)
  end)

  it("adds an anchor unless there is one", function()
    local line, id = edit.addAnchor("* [ ] a  ", "a-1f2e")
    assert.are.equal("* [ ] a $a-1f2e", line)
    assert.are.equal("a-1f2e", id)
    local same, existing = edit.addAnchor("* [ ] a $mine", "a-1f2e")
    assert.are.equal("* [ ] a $mine", same)
    assert.are.equal("mine", existing)
  end)
end)
