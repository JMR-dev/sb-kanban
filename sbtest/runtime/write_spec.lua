-- SPDX-License-Identifier: Apache-2.0
--
-- kanban.sb.write against real pages (sbtest/space/Write/*). The client
-- re-indexes a page right after it writes it, and a task is briefly missing
-- from queries while that happens, so every fixture task is looked up before
-- anything is written. Positions then stay as indexed, so each case edits a
-- different line, bottom-up within a page.

local function taskNamed(page, name)
  for _, t in ipairs(kanban.sb.data.allTasks()) do
    if t.page == page and t.name == name then
      return t
    end
  end
  error("fixture task not found: " .. page .. " / " .. name)
end

local function lines(text)
  local out = {}
  for line in string.gmatch(text, "[^\n]+") do
    out[#out + 1] = line
  end
  return out
end

describe("kanban.sb.write", function()
  local fixtures = {
    state = taskNamed("Write/State", "Change my state"),
    open = taskNamed("Write/Open", "Change me while open"),
    stale = taskNamed("Write/Stale", "Moved under my feet"),
    lose = taskNamed("Write/Edits", "Lose a blocker"),
    collect = taskNamed("Write/Edits", "Collect blockers"),
    keep = taskNamed("Write/Edits", "Keep my anchor"),
    give = taskNamed("Write/Edits", "Give me an anchor"),
  }

  it("changes a task's state on a page that is not open", function()
    local task = fixtures.state
    local ok, message = kanban.sb.write.setState(task, "DOING")
    assert.is_true(ok, message)
    assert.are.equal("* [DOING] Change my state", lines(space.readPage "Write/State")[1])
  end)

  it("changes a task's state on the page open in the editor", function()
    editor.navigate "Write/Open"
    local task = fixtures.open
    local ok, message = kanban.sb.write.setState(task, "DOING")
    assert.is_true(ok, message)
    assert.are.equal("* [DOING] Change me while open", lines(editor.getText())[1])
    editor.navigate "index"
  end)

  it("refuses to write when the task moved since it was indexed", function()
    local task = fixtures.stale
    local shifted = "* [TODO] A new first line\n" .. space.readPage "Write/Stale"
    space.writePage("Write/Stale", shifted)
    local ok, message = kanban.sb.write.setState(task, "DOING")
    assert.is_false(ok)
    assert.are.equal(kanban.sb.write.staleMessage, message)
    assert.are.equal(shifted, space.readPage "Write/Stale")
  end)

  it("replaces a list of blockers with one", function()
    local task = fixtures.lose
    local ok, message = kanban.sb.write.setBlockedBy(task, { "write-kept" })
    assert.is_true(ok, message)
    assert.are.equal(
      '* [TODO] Lose a blocker [blockedBy: "[[$write-kept]]"]',
      lines(space.readPage "Write/Edits")[4]
    )
  end)

  it("adds blockers as a list", function()
    local task = fixtures.collect
    local ok, message = kanban.sb.write.setBlockedBy(task, { "write-kept", "write-other" })
    assert.is_true(ok, message)
    assert.are.equal(
      '* [TODO] Collect blockers [blockedBy: ["[[$write-kept]]", "[[$write-other]]"]]',
      lines(space.readPage "Write/Edits")[3]
    )
  end)

  it("keeps an existing anchor without writing", function()
    local task = fixtures.keep
    local anchor, delta = kanban.sb.write.ensureAnchor(task)
    assert.are.equal("write-kept", anchor)
    assert.are.equal(0, delta)
  end)

  it("gives a task a new, unique anchor", function()
    local task = fixtures.give
    local anchor, delta = kanban.sb.write.ensureAnchor(task)
    assert.is_true(string.match(anchor, "^give%-me%-an%-anchor%-%x%x%x%x$") ~= nil, anchor)
    assert.are.equal(#anchor + 2, delta)
    assert.are.equal(
      "* [TODO] Give me an anchor $" .. anchor,
      lines(space.readPage "Write/Edits")[1]
    )
  end)
end)
