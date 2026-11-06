-- SPDX-License-Identifier: Apache-2.0
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
