-- SilverBullet runs ```space-lua blocks of equal priority in no guaranteed
-- order (sorted by their "Page@pos" ref as a string, docs/compat.md), so the
-- library must load correctly whatever order its same-priority files run in.
-- Loading them forwards and backwards within each priority catches any file
-- that calls into another file while loading.

local sources = dofile "tools/page_sources.lua"

local function runOrders()
  local files = sources.list("src").lua
  local forward, backward = {}, {}
  local i = 1
  while i <= #files do
    local j = i
    while j < #files and files[j + 1].priority == files[i].priority do
      j = j + 1
    end
    for k = i, j do
      forward[#forward + 1] = files[k]
    end
    for k = j, i, -1 do
      backward[#backward + 1] = files[k]
    end
    i = j + 1
  end
  return { forward = forward, backward = backward }
end

-- Loads the files into a fresh environment (with the SilverBullet stubs from
-- spec/helpers/sb_stubs.lua reachable as globals) and returns it.
local function loadInto(files)
  sbfake.reset()
  local env = setmetatable({}, { __index = _G })
  for _, f in ipairs(files) do
    local chunk = assert(load(f.src, "@" .. f.path, "t", env))
    chunk()
  end
  return env
end

describe("library load order", function()
  for name, files in pairs(runOrders()) do
    it("loads with same-priority files run " .. name, function()
      local env = loadInto(files)
      assert.is_true(env.kanban.registry.decorators["kanban.dependencies"] ~= nil)
      assert.is_true(env.kanban.registry.guards["kanban.blockDone"] ~= nil)
      assert.is_true(sbfake.codeWidgets.kanban ~= nil)
      assert.is_true(sbfake.slashCommands.kanban ~= nil)
      assert.is_true(sbfake.commands["Kanban: Customize task states"] ~= nil)
      assert.are.equal(1, #sbfake.listeners["cron:secondPassed"])
      assert.are.equal("awaiting", env.kanban.sb.migrate.phase)
      -- The default task states are in place before CONFIG runs.
      assert.is_true(sbfake.config.taskStates.Backlog.todo)
    end)
  end

  -- The removed-state check after a load (src/sb/migrate.lua): loading the
  -- scripts can take longer than a clock tick, and CONFIG loads after
  -- src/register.lua, so ticks can come before CONFIG's kanban.taskStates.
  describe("removed-state check", function()
    local env, runs

    local function tick()
      sbfake.listeners["cron:secondPassed"][1].run()
    end

    before_each(function()
      env = loadInto(runOrders().forward)
      runs = 0
      env.kanban.sb.migrate.run = function()
        runs = runs + 1
        return 0, 0
      end
    end)

    it("waits for CONFIG's list: ticks before it neither run nor use up the check", function()
      tick()
      tick()
      assert.are.equal(0, runs)
      env.kanban.taskStates { { name = "TODO" } }
      assert.is_true(sbfake.config.kanban.customStates)
      tick()
      assert.are.equal(1, runs)
    end)

    it("runs once per load", function()
      env.kanban.taskStates { { name = "TODO" } }
      tick()
      tick()
      assert.are.equal(1, runs)
    end)

    it("also becomes due for an empty list (the check then finds nothing to do)", function()
      env.kanban.taskStates {}
      tick()
      assert.are.equal(1, runs)
    end)

    it("schedules nothing for a list applied after the load's check", function()
      env.kanban.taskStates { { name = "TODO" } }
      tick()
      env.kanban.taskStates { { name = "OK" } }
      tick()
      assert.are.equal(1, runs)
      assert.is_nil(env.kanban.sb.migrate.phase)
    end)

    it("waits again on the next load (System: Reload)", function()
      env.kanban.taskStates { { name = "TODO" } }
      tick()
      env.kanban.sb.migrate.loading()
      tick()
      assert.are.equal(1, runs)
      env.kanban.taskStates { { name = "TODO" } }
      tick()
      assert.are.equal(2, runs)
    end)
  end)

  it("would have caught a load-time call between same-priority files", function()
    local a = { path = "a.lua", priority = 50, src = "x = x or {}; x.value = 1" }
    local b = { path = "b.lua", priority = 50, src = "y = x.value + 1" }
    assert.has_error(function()
      loadInto { b, a }
    end)
  end)
end)
