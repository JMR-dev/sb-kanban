-- Makes table.sort reject comparators that are not strict orderings, for the
-- Lua 5.5.1 test run. Reference Lua usually copes with such a comparator;
-- Space Lua's sort never returns (docs/compat.md). Checking here turns that
-- hang inside SilverBullet into an immediate unit-test failure.

local realSort = table.sort

-- luacheck: push ignore 122 (replacing table.sort is the point)
function table.sort(list, cmp)
  if cmp ~= nil then
    local n = #list
    for i = 1, n do
      if cmp(list[i], list[i]) then
        error(
          "table.sort comparator is not strict: cmp(a, a) is true for "
            .. tostring(list[i])
            .. " (Space Lua's sort never returns on this)",
          2
        )
      end
    end
    for i = 1, n do
      for j = i + 1, n do
        if cmp(list[i], list[j]) and cmp(list[j], list[i]) then
          error(
            "table.sort comparator is not strict: both cmp(a, b) and cmp(b, a) are true"
              .. " (Space Lua's sort never returns on this)",
            2
          )
        end
      end
    end
  end
  return realSort(list, cmp)
end
-- luacheck: pop
