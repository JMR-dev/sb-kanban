describe("kanban.ids", function()
  local ids = kanban.ids

  -- A deterministic stand-in for math.random(1, 16).
  local function sequence(values)
    local i = 0
    return function()
      i = i + 1
      return values[(i - 1) % #values + 1]
    end
  end

  it("validates anchor names", function()
    assert.is_true(ids.isValid "ship-api-3f2a")
    assert.is_true(ids.isValid "_x/y:z")
    assert.is_false(ids.isValid "1abc")
    assert.is_false(ids.isValid "has space")
    assert.is_false(ids.isValid(nil))
  end)

  it("slugs task names", function()
    assert.are.equal("ship-the-api", ids.slug "Ship the API!")
    assert.are.equal("t-2026-planning", ids.slug "2026 planning")
    assert.are.equal("task", ids.slug "!!!")
    assert.are.equal("task", ids.slug(nil))
    assert.are.equal("a-very-long-task-name-th", ids.slug "A very long task name that keeps going")
  end)

  it("makes valid names with a random suffix", function()
    local id = ids.new("Ship the API", {}, sequence { 1, 2, 11, 16 })
    assert.are.equal("ship-the-api-01af", id)
    assert.is_true(ids.isValid(id))
  end)

  it("avoids names that are taken", function()
    local taken = { ["x-0000"] = true }
    local id = ids.new("x", taken, sequence { 1, 1, 1, 1, 2, 2, 2, 2 })
    assert.are.equal("x-1111", id)
  end)

  it("gives up when every name is taken", function()
    assert.has_error(function()
      ids.new("x", { ["x-0000"] = true }, sequence { 1 })
    end, "could not find a free anchor name for x")
  end)
end)
