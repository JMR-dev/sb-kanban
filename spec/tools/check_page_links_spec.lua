local links = dofile "tools/check_page_links.lua"

local function targets(text)
  return links.check(text)
end

describe("check_page_links", function()
  it("accepts the built-in library and external links", function()
    local text =
      "See [[^Library/Std/APIs/Task State|states]] and [docs](https://silverbullet.md/x).\n"
    assert.are.same({}, targets(text))
  end)

  it("rejects wiki links to pages a space may not have", function()
    local found = targets "one\nUse [[Space Lua]] and [[API/service|services]].\n"
    assert.are.same({ { line = 2, link = "Space Lua" }, { line = 2, link = "API/service" } }, found)
  end)

  it("ignores code: inline spans, indented blocks and fences", function()
    local text = table.concat({
      'Write `[blockedBy: "[[$api]]"]` like this:',
      "",
      '    * [ ] Task [blockedBy: "[[$api]]"]',
      "```",
      "[[Not checked]]",
      "```",
    }, "\n")
    assert.are.same({}, targets(text))
  end)

  it("passes the real library page template", function()
    local f = assert(io.open("page/Kanban.template.md", "rb"))
    local text = f:read "a"
    f:close()
    assert.are.same({}, targets(text))
  end)
end)
