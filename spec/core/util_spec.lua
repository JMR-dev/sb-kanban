describe("kanban.util", function()
  local util = kanban.util

  it("escapes HTML special characters", function()
    assert.are.equal(
      "&lt;b a=&quot;1&quot;&gt;Tom &amp; Jerry&#39;s&lt;/b&gt;",
      util.escapeHtml [[<b a="1">Tom & Jerry's</b>]]
    )
    assert.are.equal("42", util.escapeHtml(42))
  end)

  it("trims whitespace", function()
    assert.are.equal("a b", util.trim "  a b \t\n")
    assert.are.equal("", util.trim "   ")
  end)

  it("tests prefixes", function()
    assert.is_true(util.startsWith("Projects/Alpha", "Projects/"))
    assert.is_false(util.startsWith("Alpha", "Projects/"))
    assert.is_true(util.startsWith("abc", ""))
  end)

  it("turns values into lists", function()
    assert.are.same({}, util.asList(nil))
    assert.are.same({ "a" }, util.asList "a")
    assert.are.same({ "a", "b" }, util.asList { "a", "b" })
  end)

  it("maps, filters and finds", function()
    local doubled = util.map({ 1, 2, 3 }, function(v)
      return v * 2
    end)
    assert.are.same({ 2, 4, 6 }, doubled)
    local odd = util.filter({ 1, 2, 3 }, function(v)
      return v % 2 == 1
    end)
    assert.are.same({ 1, 3 }, odd)
    assert.is_true(util.contains({ "x", "y" }, "y"))
    assert.is_false(util.contains({ "x" }, "z"))
  end)

  it("copies tables shallowly", function()
    local inner = { 1 }
    local original = { a = 1, inner = inner }
    local copy = util.shallowCopy(original)
    assert.are.same(original, copy)
    assert.is_false(copy == original)
    assert.are.equal(inner, copy.inner)
  end)

  it("sorts keys independently of pairs order", function()
    assert.are.same({ "a", "b", "c" }, util.sortedKeys { c = 1, a = 2, b = 3 })
  end)
end)
