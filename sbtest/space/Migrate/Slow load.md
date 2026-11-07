A slow load of the scripts, for every test client: this block waits until one
clock tick has passed. Its priority (5) is what makes it work: it runs after
the library's register block (priority 10) and before CONFIG, so a
`cron:secondPassed` tick lands between them, as it does on a busy machine. The
removed-state check must still wait for CONFIG's task states
(sbtest/runtime.spec.ts and sbtest/ui/board.spec.ts check Migrate/Runtime and
Migrate/Tasks).

A client that already has an index (a page reload) loads the scripts during
boot, before the clock ticks start, so no tick comes: the block gives up after
one to two seconds there instead of holding up the load for good.

```space-lua
-- priority: 5
local ticked = false
event.listen {
  name = "cron:secondPassed",
  run = function()
    ticked = true
  end,
}
local start = os.time()
while not ticked and os.time() - start < 2 do
  space.readPage "index"
end
```
