-- Lists the library's source files in the order SilverBullet runs them, so
-- the page generator (tools/build_page.lua) and the Lua 5.5.1 test loader
-- (spec/helpers/load_src.lua) agree.
--
-- SilverBullet runs ```space-lua blocks by `-- priority: N` (highest first),
-- then by position on the page. The generator writes blocks in this order, so
-- position order matches priority order.

local M = {}

--- Reads the `-- priority: N` declaration from a Lua source (default 0),
--- using the same pattern as SilverBullet (plugs/index/space_lua.ts).
function M.priority(src)
  local p = string.match(src, "%-%-%s*priority:%s*(%-?%d+)")
  return p and tonumber(p) or 0
end

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read "a"
  f:close()
  return s
end
M.readFile = readFile

--- Returns { lua = {{path, src, priority}...}, css = {{path, src}...} }.
function M.list(root)
  root = root or "src"
  local lua, css = {}, {}
  local find = "find " .. root .. " -type f \\( -name '*.lua' -o -name '*.css' \\)"
  local p = assert(io.popen(find .. " | sort"))
  for path in p:lines() do
    local src = readFile(path)
    if string.match(path, "%.lua$") then
      lua[#lua + 1] = { path = path, src = src, priority = M.priority(src) }
    else
      css[#css + 1] = { path = path, src = src }
    end
  end
  p:close()
  table.sort(lua, function(a, b)
    if a.priority ~= b.priority then
      return a.priority > b.priority
    end
    return a.path < b.path
  end)
  return { lua = lua, css = css }
end

return M
