# Extensions

A decorator through the Lua API, and a decorator and move guard through
SilverBullet services, the way a TypeScript plug would provide them.

```space-lua
kanban.defineDecorator {
  name = "test.lua",
  decorate = function(card)
    if card.title == "Decorate me" then
      return { { kind = "fromLua", text = "From Lua", tone = "info" } }
    end
  end,
}

service.define {
  selector = "kanban:decorator",
  match = { priority = 1, name = "test.service" },
  run = function(snapshot)
    local out = {}
    for id, card in pairs(snapshot.cards) do
      if card.title == "Decorate me" then
        out[id] = { { kind = "fromService", text = "From a service", tone = "ok" } }
      end
    end
    return out
  end,
}

service.define {
  selector = "kanban:moveGuard",
  match = { priority = 1, name = "test.guard" },
  run = function(move)
    if move.card.title == "Guarded task" then
      return { allowed = false, reason = "Guarded by a service." }
    end
  end,
}
```
