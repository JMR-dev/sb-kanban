-- Generates the installable library page from page/Kanban.template.md and
-- the sources under src/.
--
--   lua tools/build_page.lua [OUT]   (default dist/Library/JMR-dev/Kanban.md)
--
-- The template's `{{version}}` is replaced with `kanban.version` from
-- src/namespace.lua, and `{{implementation}}` with one fenced block per source
-- file (```space-lua for .lua, ```space-style for .css), in run order.

local sources = dofile "tools/page_sources.lua"

local out = arg[1] or "dist/Library/JMR-dev/Kanban.md"
local template = sources.readFile "page/Kanban.template.md"
local namespace = sources.readFile "src/namespace.lua"
local version = assert(
  string.match(namespace, 'kanban%.version%s*=%s*"([^"]+)"'),
  'src/namespace.lua must set kanban.version = "x.y.z"'
)

local function fence(lang, path, src)
  assert(
    not string.find(src, "```", 1, true),
    path .. " must not contain ``` (it would end the block)"
  )
  if string.sub(src, -1) ~= "\n" then
    src = src .. "\n"
  end
  return "### " .. path .. "\n```" .. lang .. "\n" .. src .. "```\n"
end

local list = sources.list "src"
local parts = {}
for _, f in ipairs(list.lua) do
  parts[#parts + 1] = fence("space-lua", f.path, f.src)
end
for _, f in ipairs(list.css) do
  parts[#parts + 1] = fence("space-style", f.path, f.src)
end
local implementation = table.concat(parts, "\n")

local function replaceOnce(s, placeholder, value)
  local i, j = string.find(s, placeholder, 1, true)
  assert(i, "template has no " .. placeholder)
  return string.sub(s, 1, i - 1) .. value .. string.sub(s, j + 1)
end

local page = template
page = string.gsub(page, "{{version}}", function()
  return version
end)
page = replaceOnce(page, "{{implementation}}", implementation)

os.execute("mkdir -p '" .. string.match(out, "^(.*)/[^/]*$") .. "'")
local f = assert(io.open(out, "wb"))
f:write(page)
f:close()
