-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 10

-- Everything the library does when it loads, as opposed to defining things.
-- SilverBullet runs blocks of equal priority in no guaranteed order (it sorts
-- them by their `Page@pos` ref as a string), so no other file may call into
-- another file while loading. This block runs after all of them (priority 10
-- comes after 50). spec/tools/load_order_spec.lua checks the rule.

kanban.defineDecorator(kanban.builtins.dependencies)
kanban.defineMoveGuard(kanban.builtins.blockDone)

codeWidget.define {
  language = "kanban",
  render = function(body)
    return kanban.sb.renderBlock(body)
  end,
}
