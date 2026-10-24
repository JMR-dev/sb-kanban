-- Checks that the library page's prose links only to pages every space has.
--
-- The page is installed into other people's spaces, so a wiki link such as
-- [[Space Lua]] points at a page that usually doesn't exist there; clicking
-- it creates an empty page. Prose may only wiki-link SilverBullet's built-in
-- library ([[^Library/Std/...]]); everything else must be an external link
-- (e.g. https://silverbullet.md/...). Indented and fenced code is skipped,
-- since examples legitimately contain [[$anchor]] links.
--
--   lua tools/check_page_links.lua [FILE]   (default page/Kanban.template.md)

local M = {}

---@param text string
---@return { line: integer, link: string }[]
function M.check(text)
  local problems = {}
  local inFence = false
  local n = 0
  for line in (text .. "\n"):gmatch "([^\n]*)\n" do
    n = n + 1
    if line:match "^%s*```" then
      inFence = not inFence
    elseif not inFence and not line:match "^    " and not line:match "^\t" then
      -- Drop inline code spans before looking for links.
      local prose = line:gsub("`[^`]*`", "")
      for target in prose:gmatch "%[%[([^%]|]+)" do
        if not target:match "^%^Library/Std/" then
          problems[#problems + 1] = { line = n, link = target }
        end
      end
    end
  end
  return problems
end

if arg and arg[0] and arg[0]:match "check_page_links%.lua$" then
  local path = arg[1] or "page/Kanban.template.md"
  local f = assert(io.open(path, "rb"))
  local text = f:read "a"
  f:close()
  local problems = M.check(text)
  for _, p in ipairs(problems) do
    io.stderr:write(
      string.format(
        "%s:%d: [[%s]] is not a page every space has;"
          .. " link to https://silverbullet.md/... instead\n",
        path,
        p.line,
        p.link
      )
    )
  end
  if #problems > 0 then
    os.exit(1)
  end
end

return M
