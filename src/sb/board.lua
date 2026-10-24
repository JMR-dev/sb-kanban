-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- The public entry points: `kanban.board { ... }` for `${...}` expressions,
-- and `kanban` fenced blocks (registered in src/register.lua) with the same
-- options as YAML.
--
-- SilverBullet 2.12 does not re-render widgets by itself when the index
-- changes (that is Edge only), so boards are content widgets that refresh on
-- every index update; that is what moves a dropped card, and what updates a
-- blocker badge when the blocking task is finished on another page.

kanban = kanban or {}
kanban.sb = kanban.sb or {}

---A kanban board of tasks.
---@param options table|nil board options, as in a `kanban` block
---@return sb.Widget
function kanban.board(options)
  return widget.new {
    content = function()
      return kanban.sb.render.board(options)
    end,
    refreshOn = { "index" },
  }
end

---Renders the body of a `kanban` fenced block (YAML board options).
---@param body string
---@return sb.Widget
function kanban.sb.renderBlock(body)
  local ok, parsed = pcall(yaml.parse, body)
  if not ok then
    return kanban.sb.render.problems {
      "The board options are not valid YAML: " .. tostring(parsed),
    }
  end
  return kanban.board(parsed)
end
