---
name: Library/JMR-dev/Kanban
tags: meta/library
description: Kanban boards for SilverBullet tasks, with drag-and-drop and cross-page blockers.
author: JMR-dev
license: AGPL-3.0-or-later
website: https://gitea.jasonmross.dev/JMR-dev/sb-kanban
version: "0.1.0"
---
Kanban boards for your [[^Library/Std/APIs/Task State|tasks]].

> **note** Generated page
> This page is generated from the [sb-kanban repository](https://gitea.jasonmross.dev/JMR-dev/sb-kanban) (version 0.1.0). Edit the sources there, not here: updating the library replaces this page.

# Implementation
### src/namespace.lua
```space-lua
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- priority: 50

-- The library's single global namespace. Never `kanban = {}`: a TypeScript
-- plug can register `kanban.*` syscalls, and SilverBullet adds those to an
-- existing table before scripts run.
kanban = kanban or {}

-- Bumped on any change to the public API (`kanban.board`, the options of
-- `kanban` fenced blocks, `kanban.defineDecorator`, `kanban.defineMoveGuard`)
-- that breaks existing boards or extensions.
kanban.apiVersion = 1
kanban.version = "0.1.0"
```

