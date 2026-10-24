-- Tool fixture: Space Lua idioms that StyLua must leave byte-identical and that
-- luacheck must accept (checked by `make fmt-check lint`).
-- `query [[...]]` is StyLua's spelling; real SilverBullet 2.12.0 parses it the
-- same as `query[[...]]` (docs/adr/0001-spike.md).
local open = query [[from t = index.tasks() where not t.done]]

local w = widget.new {
  html = "<b>" .. string.trim "  hi  " .. "</b>",
  display = "block",
}

editor.flashNotification "saved"

kanban = kanban or {}
kanban.fixture = { w = w, n = #open }
