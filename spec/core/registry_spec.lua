describe("kanban registry", function()
  local function names(list)
    return kanban.util.map(list, function(d)
      return d.name
    end)
  end

  it("has the built-ins registered", function()
    assert.is_true(
      kanban.util.contains(names(kanban.registry.list "decorators"), "kanban.dependencies")
    )
    assert.is_true(kanban.util.contains(names(kanban.registry.list "guards"), "kanban.blockDone"))
  end)

  it("registers and replaces definitions by name", function()
    kanban.defineDecorator {
      name = "spec.test",
      decorate = function()
        return nil
      end,
    }
    local replacement = {
      name = "spec.test",
      priority = 3,
      decorate = function()
        return nil
      end,
    }
    kanban.defineDecorator(replacement)
    local found = nil
    for _, d in ipairs(kanban.registry.list "decorators") do
      if d.name == "spec.test" then
        found = d
      end
    end
    assert.are.equal(replacement, found)
    kanban.registry.decorators["spec.test"] = nil
  end)

  it("rejects malformed definitions", function()
    assert.has_error(function()
      kanban.defineDecorator { name = "x" }
    end, "kanban.defineDecorator needs a table with `name` (string) and `decorate` (function)")
    assert.has_error(function()
      kanban.defineMoveGuard { name = "x", check = 1 }
    end, "kanban.defineMoveGuard needs a table with `name` (string) and `check` (function)")
    assert.has_error(function()
      kanban.defineMoveGuard {
        name = "x",
        priority = "high",
        check = function()
          return true
        end,
      }
    end, "kanban.defineMoveGuard: `priority` must be a number")
  end)
end)
