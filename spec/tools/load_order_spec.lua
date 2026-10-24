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
      assert.is_true(env.kanban.sb.migrate.pending)
      -- The default task states are in place before CONFIG runs.
      assert.is_true(sbfake.config.taskStates.Backlog.todo)
    end)
  end

  it("would have caught a load-time call between same-priority files", function()
    local a = { path = "a.lua", priority = 50, src = "x = x or {}; x.value = 1" }
    local b = { path = "b.lua", priority = 50, src = "y = x.value + 1" }
    assert.has_error(function()
      loadInto { b, a }
    end)
  end)
end)
