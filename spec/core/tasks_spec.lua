describe("kanban.tasks", function()
  local tasks = kanban.tasks

  describe("parseAnchorLink", function()
    it("accepts anchor wiki links and bare anchors", function()
      assert.are.equal("api-v2", tasks.parseAnchorLink "[[$api-v2]]")
      assert.are.equal("api-v2", tasks.parseAnchorLink " [[$api-v2|the API]] ")
      assert.are.equal("api-v2", tasks.parseAnchorLink "$api-v2")
      assert.are.equal("a/b:c_d", tasks.parseAnchorLink "[[$a/b:c_d]]")
    end)

    it("rejects anything else", function()
      assert.is_nil(tasks.parseAnchorLink "[[Some Page]]")
      assert.is_nil(tasks.parseAnchorLink "api-v2")
      assert.is_nil(tasks.parseAnchorLink "[[$1bad]]")
      assert.is_nil(tasks.parseAnchorLink(42))
    end)
  end)

  describe("fromIndex", function()
    it("builds an anchored task", function()
      local t = tasks.fromIndex {
        ref = "sp-a",
        page = "Spike",
        range = { 9, 31 },
        name = "alpha task",
        state = " ",
        tags = { "x" },
      }
      assert.are.equal("sp-a", t.anchor)
      assert.are.equal(9, t.from)
      assert.are.equal(31, t.to)
      assert.are.same({ "x" }, t.tags)
      assert.are.same({}, t.blockedBy)
      assert.are.equal("Spike@9", tasks.positionRef(t))
    end)

    it("builds an unanchored task with one or several blockers", function()
      local one = tasks.fromIndex {
        ref = "Spike@32",
        page = "Spike",
        range = { 32, 75 },
        name = "beta",
        state = "TODO",
        blockedBy = "[[$sp-a]]",
      }
      assert.is_nil(one.anchor)
      assert.are.same({ "sp-a" }, one.blockedBy)
      local many = tasks.fromIndex {
        ref = "Spike@102",
        page = "Spike",
        range = { 102, 161 },
        name = "delta",
        state = "TODO",
        blockedBy = { "[[$sp-a]]", "[[$sp-g]]", "[[Not An Anchor]]" },
      }
      assert.are.same({ "sp-a", "sp-g" }, many.blockedBy)
      assert.are.same({ "[[Not An Anchor]]" }, many.badLinks)
    end)

    it("defaults a missing name and state", function()
      local t = tasks.fromIndex { ref = "P@0", page = "P", range = { 0, 5 } }
      assert.are.equal("", t.name)
      assert.are.equal(" ", t.state)
      assert.are.same({}, t.tags)
    end)
  end)

  describe("select", function()
    local function task(page, tags)
      return { ref = page .. "@0", page = page, tags = tags or {} }
    end
    local all = {
      task("Projects/Alpha", { "urgent" }),
      task "Projects/Beta",
      task("Inbox", { "urgent" }),
    }
    local function spec(fields)
      local s = { pages = {}, pagePrefixes = {}, tags = {} }
      for k, v in pairs(fields) do
        s[k] = v
      end
      return s
    end
    local function pages(list)
      return kanban.util.map(list, function(t)
        return t.page
      end)
    end

    it("keeps everything without filters", function()
      assert.are.equal(3, #tasks.select(all, spec {}))
    end)

    it("filters by page, page prefix and tag", function()
      assert.are.same({ "Inbox" }, pages(tasks.select(all, spec { pages = { "Inbox" } })))
      assert.are.same(
        { "Projects/Alpha", "Projects/Beta" },
        pages(tasks.select(all, spec { pagePrefixes = { "Projects/" } }))
      )
      assert.are.same(
        { "Projects/Alpha", "Inbox" },
        pages(tasks.select(all, spec { tags = { "urgent" } }))
      )
    end)

    it("requires every given filter", function()
      local s = spec { pagePrefixes = { "Projects/" }, tags = { "urgent" } }
      assert.are.same({ "Projects/Alpha" }, pages(tasks.select(all, s)))
    end)
  end)
end)
