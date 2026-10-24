-- Space Lua dialect check for code that runs inside SilverBullet.
--
-- The code must parse and behave the same under SilverBullet's Space Lua
-- (a Lua 5.4-level interpreter written in TypeScript) and under Lua 5.5.1,
-- which runs the unit tests. `luac -p` (5.5.1) rejects Space Lua-only syntax
-- such as `!=`; luacheck's allowlist std rejects missing library functions.
-- This tool covers the rest: valid Lua 5.5 that Space Lua parses differently
-- or not at all, or that behaves differently there.
--
--   lua tools/check_dialect.lua FILE...    (exit status 1 on any finding)
--
-- Findings are documented in docs/compat.md.

local M = {}

local twoCharOps = {
  ["=="] = true,
  ["~="] = true,
  ["<="] = true,
  [">="] = true,
  ["//"] = true,
  [".."] = true,
  ["::"] = true,
  ["<<"] = true,
  [">>"] = true,
  ["!="] = true,
}

local unsupportedMetamethods = {
  __gc = true,
  __mode = true,
  __metatable = true,
}

local function countNewlines(s)
  local _, n = string.gsub(s, "\n", "")
  return n
end

-- Reads a number literal starting at i; returns its end index.
local function scanNumber(src, i)
  local j = i
  if string.match(src, "^0[xX]", i) then
    j = i + 2
    while string.match(string.sub(src, j, j), "[%x%.]") do
      j = j + 1
    end
    if string.match(string.sub(src, j, j), "[pP]") then
      j = j + 1
      if string.match(string.sub(src, j, j), "[%+%-]") then
        j = j + 1
      end
      while string.match(string.sub(src, j, j), "%d") do
        j = j + 1
      end
    end
    return j - 1
  end
  while string.match(string.sub(src, j, j), "[%d%.]") do
    j = j + 1
  end
  if string.match(string.sub(src, j, j), "[eE]") then
    j = j + 1
    if string.match(string.sub(src, j, j), "[%+%-]") then
      j = j + 1
    end
    while string.match(string.sub(src, j, j), "%d") do
      j = j + 1
    end
  end
  return j - 1
end

--- Splits Lua source into tokens: name, number, string, op, plus `longbracket`
--- entries for long comments (so their level can be checked). Long strings are
--- `string` tokens with `level` set.
function M.tokenize(src)
  local tokens = {}
  local i, n, line = 1, #src, 1
  local function push(kind, value, level)
    tokens[#tokens + 1] = { kind = kind, value = value, line = line, level = level }
  end
  while i <= n do
    local c = string.sub(src, i, i)
    if c == "\n" then
      line = line + 1
      i = i + 1
    elseif string.match(c, "%s") then
      i = i + 1
    elseif string.sub(src, i, i + 1) == "--" then
      local eq = string.match(src, "^%[(=*)%[", i + 2)
      if eq then
        local _, e = string.find(src, "]" .. eq .. "]", i + 4 + #eq, true)
        e = e or n
        local body = string.sub(src, i, e)
        push("longbracket", body, #eq)
        line = line + countNewlines(body)
        i = e + 1
      else
        i = string.find(src, "\n", i, true) or n + 1
      end
    elseif c == "[" and string.match(src, "^%[=*%[", i) then
      local eq = string.match(src, "^%[(=*)%[", i)
      local _, e = string.find(src, "]" .. eq .. "]", i + 2 + #eq, true)
      e = e or n
      local body = string.sub(src, i, e)
      push("string", body, #eq)
      line = line + countNewlines(body)
      i = e + 1
    elseif c == '"' or c == "'" then
      local j = i + 1
      while j <= n do
        local d = string.sub(src, j, j)
        if d == "\\" then
          j = j + 2
        elseif d == c or d == "\n" then
          break
        else
          j = j + 1
        end
      end
      push("string", string.sub(src, i, j))
      i = j + 1
    elseif string.match(c, "[%a_]") then
      local name = string.match(src, "^[%w_]+", i)
      push("name", name)
      i = i + #name
    elseif
      string.match(c, "%d") or (c == "." and string.match(string.sub(src, i + 1, i + 1), "%d"))
    then
      local e = scanNumber(src, i)
      push("number", string.sub(src, i, e))
      i = e + 1
    elseif string.sub(src, i, i + 2) == "..." then
      push("op", "...")
      i = i + 3
    elseif twoCharOps[string.sub(src, i, i + 1)] then
      push("op", string.sub(src, i, i + 1))
      i = i + 2
    else
      push("op", c)
      i = i + 1
    end
  end
  return tokens
end

local function isLongString(tok)
  return tok ~= nil and tok.kind == "string" and tok.level ~= nil
end

local function isOp(tok, ...)
  if tok == nil or tok.kind ~= "op" then
    return false
  end
  for _, v in ipairs { ... } do
    if tok.value == v then
      return true
    end
  end
  return false
end

--- Returns a list of { line = n, message = "..." } findings for `src`.
function M.check(src)
  local tokens = M.tokenize(src)
  local findings = {}
  local function report(tok, message)
    findings[#findings + 1] = { line = tok.line, message = message }
  end
  for idx, tok in ipairs(tokens) do
    local prev, nextTok = tokens[idx - 1], tokens[idx + 1]
    if tok.kind == "name" then
      if tok.value == "global" then
        report(tok, "`global` declarations are Lua 5.5 only; Space Lua has none")
      elseif tok.value == "using" then
        report(tok, "`using` is a Space Lua keyword; pick another name")
      elseif tok.value == "query" then
        if isOp(prev, ".", ":") or not isLongString(nextTok) then
          report(tok, "`query` is a Space Lua keyword; only `query [[...]]` is allowed")
        elseif isOp(tokens[idx + 2], "[", ".", ":") then
          report(
            tok,
            "Space Lua cannot parse `query [[...]]` followed by `[`, `.` or `:`;"
              .. " assign the result to a local first"
          )
        end
      elseif tok.value == "_G" then
        report(
          tok,
          "`_G` is a userdata proxy in Space Lua (`pairs` sees nothing); name globals directly"
        )
      elseif unsupportedMetamethods[tok.value] then
        report(tok, "`" .. tok.value .. "` is not supported by Space Lua")
      end
    elseif tok.kind == "op" then
      if tok.value == "!=" then
        report(tok, "`!=` is Space Lua only; use `~=`")
      elseif isOp(tok, "&", "|", "~", "<<", ">>") then
        report(tok, "bitwise operators are 32-bit in Space Lua but 64-bit in Lua 5.5; avoid them")
      end
    elseif tok.kind == "string" or tok.kind == "longbracket" then
      if tok.level ~= nil and tok.level >= 3 then
        report(tok, "Space Lua long brackets only go up to level 2 (`[==[`)")
      end
      if tok.kind == "string" and tok.level == nil then
        local inner = string.sub(tok.value, 2, -2)
        if unsupportedMetamethods[inner] then
          report(tok, "`" .. inner .. "` is not supported by Space Lua")
        end
      end
    end
  end
  return findings
end

local function main(files)
  local failed = false
  for _, path in ipairs(files) do
    local f = assert(io.open(path, "rb"))
    local src = f:read "a"
    f:close()
    for _, finding in ipairs(M.check(src)) do
      io.stderr:write(string.format("%s:%d: %s\n", path, finding.line, finding.message))
      failed = true
    end
  end
  if failed then
    os.exit(1)
  end
end

if arg and arg[0] and string.match(arg[0], "check_dialect%.lua$") then
  main(arg)
end

return M
