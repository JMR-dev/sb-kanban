-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 10

-- Everything the library does when it loads, as opposed to defining things.
-- SilverBullet runs blocks of equal priority in no guaranteed order (it sorts
-- them by their `Page@pos` ref as a string), so no other file may call into
-- another file while loading. This block runs after all of them (priority 10
-- comes after 50) and before CONFIG (priority 0), which can change the default
-- task states. spec/tools/load_order_spec.lua checks the rule.

kanban.defineDecorator(kanban.builtins.dependencies)
kanban.defineMoveGuard(kanban.builtins.blockDone)

kanban.sb.states.applyDefaults()

codeWidget.define {
  language = "kanban",
  render = function(body)
    return kanban.sb.renderBlock(body)
  end,
}

slashCommand.define {
  name = "kanban",
  description = "Insert a kanban board with the default columns",
  run = function()
    kanban.sb.insertBoard()
  end,
}

command.define {
  name = "Kanban: Insert board",
  run = function()
    kanban.sb.insertBoard()
  end,
}

command.define {
  name = "Kanban: Customize task states",
  run = function()
    kanban.sb.states.customize()
  end,
}

command.define {
  name = "Kanban: Move tasks in removed states to [ ]",
  run = function()
    kanban.sb.migrate.run(true)
  end,
}

-- Move tasks in removed states back to [ ] once the scripts have loaded:
-- this block runs on every load (startup and System: Reload), before CONFIG,
-- and the check runs on the next clock tick, after CONFIG. (editor:init is not
-- enough: System: Reload doesn't fire it, and on a client's first start the
-- scripts only load after it.)
kanban.sb.migrate.pending = true
event.listen {
  name = "cron:secondPassed",
  run = function()
    if kanban.sb.migrate.pending then
      kanban.sb.migrate.pending = false
      kanban.sb.migrate.run()
    end
  end,
}
