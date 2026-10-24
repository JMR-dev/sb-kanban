---@meta
-- Type stubs for the SilverBullet APIs in tools/sb_api.lua, the allowlist of
-- what the library may use (verified on the pinned release). Only read by
-- lua-language-server; never loaded at runtime. tools/check_api.lua fails the
-- lint stage if a stub here is not in the allowlist or an allowlisted function
-- has no stub, so adding an API means adding it to both.

---Integrated query. In Space Lua `query [[...]]` is syntax; to plain Lua (and
---to the tools) it is a call with a long-string argument.
---@param q string
---@return table[]
function query(q) end

---@param s string
---@param prefix string
---@return boolean
function string.startsWith(s, prefix) end

---@param s string
---@param suffix string
---@return boolean
function string.endsWith(s, suffix) end

---@param s string
---@return string
function string.trim(s) end

---@param s string
---@param sep string
---@return string[]
function string.split(s, sep) end

---@class sb.Widget

---@class sb.CodeWidgetDef
---@field language string
---@field render fun(body: string, pageName: string): any

codeWidget = {}

---@param def sb.CodeWidgetDef
function codeWidget.define(def) end

config = {}

---@param key string|string[]
---@param default? any
---@return any
function config.get(key, default) end

---@param key string|string[]
---@param value any
function config.set(key, value) end

---@param key string
---@param schema table
function config.define(key, schema) end

---DOM element builders: `dom.div { class = "x", onclick = fn, child, ... }`.
---@type table<string, fun(spec?: table): any>
dom = {}

editor = {}

---@param message string
---@param kind? "info"|"error"
function editor.flashNotification(message, kind) end

---@param ref string
function editor.navigate(ref) end

---@return string
function editor.getCurrentPage() end

---@return string
function editor.getText() end

---@param from integer
---@param to integer
---@param text string
function editor.replaceRange(from, to, text) end

---@param label string
---@param options table[]
---@param helpText? string
---@param placeholder? string
---@return table?
function editor.filterBox(label, options, helpText, placeholder) end

index = {}

---@param tag? string
---@return table[]
function index.tasks(tag) end

---@param kind? string
---@return table[]
function index.relations(kind) end

---@param tag string
---@return table[]
function index.objects(tag) end

service = {}

---@param def table
function service.define(def) end

---@param selector string
---@param match? any
---@return table[]
function service.discover(selector, match) end

---@param serviceDef table
---@param data any
---@return any
function service.invoke(serviceDef, data) end

space = {}

---@param name string
---@return string
function space.readPage(name) end

---@param name string
---@param text string
function space.writePage(name, text) end

system = {}

---@param name string
---@param ... any
---@return any
function system.invokeFunction(name, ...) end

widget = {}

---@param spec table
---@return sb.Widget
function widget.new(spec) end

---@param html any
---@return sb.Widget
function widget.html(html) end

yaml = {}

---@param text string
---@return any
function yaml.parse(text) end

command = {}

---@param def { name: string, run: (fun(...): any), key?: string, hide?: boolean }
function command.define(def) end

slashCommand = {}

---@param def { name: string, description?: string, run: (fun(...): any) }
function slashCommand.define(def) end

event = {}

---@param listener { name: string, run: (fun(e: table): any) }
function event.listen(listener) end

---@param text string
function editor.insertAtCursor(text) end

---@return integer
function editor.getCursor() end

function index.ensureFullIndex() end
