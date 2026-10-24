Task states for the sb-kanban test space: the complete list, which replaces
the library's default states.

```space-lua
kanban.taskStates {
  { name = "TODO", order = 0 },
  { name = "DOING", order = 1 },
  { name = "SHIPPED", order = 9, done = true },
  { name = "Retired", order = 10, done = true },
}
```
