-- Keeps types/silverbullet.lua (lua-language-server stubs) in step with
-- tools/sb_api.lua (the allowlist luacheck enforces and the api_surface spec
-- verifies on real SilverBullet). A stub for an API outside the allowlist
-- would let typecheck pass code that the pinned release cannot run.
--
--   lua tools/check_api.lua    (exit status 1 on any mismatch)

local api = dofile "tools/sb_api.lua"

local f = assert(io.open("types/silverbullet.lua", "rb"))
local stubs = f:read "a"
f:close()

local declared = {}
for ns, field in string.gmatch(stubs, "\nfunction ([%w_]+)%.([%w_]+)%(") do
  declared[ns .. "." .. field] = true
end

local allowed = {}
for ns, fields in pairs(api.namespaces) do
  if fields ~= true then
    for _, field in ipairs(fields) do
      allowed[ns .. "." .. field] = true
    end
  end
end
for ns, fields in pairs(api.extensions) do
  for _, field in ipairs(fields) do
    allowed[ns .. "." .. field] = true
  end
end

local problems = {}
for name in pairs(declared) do
  if not allowed[name] then
    problems[#problems + 1] = "types/silverbullet.lua declares "
      .. name
      .. ", which tools/sb_api.lua does not allow"
  end
end
for name in pairs(allowed) do
  if not declared[name] then
    problems[#problems + 1] = "tools/sb_api.lua allows "
      .. name
      .. " but types/silverbullet.lua has no stub for it"
  end
end
for ns, fields in pairs(api.namespaces) do
  if fields == true and not string.find(stubs, "\n" .. ns .. " = {}", 1, true) then
    problems[#problems + 1] = "types/silverbullet.lua has no `" .. ns .. " = {}` declaration"
  end
end

table.sort(problems)
for _, p in ipairs(problems) do
  io.stderr:write(p, "\n")
end
if #problems > 0 then
  os.exit(1)
end
