-- Loads the library into the global environment the way SilverBullet does:
-- each source file is one ```space-lua block, run as its own chunk (so
-- `local`s stay private and globals are shared), in the same order the page
-- generator writes them (tools/page_sources.lua).
--
-- SilverBullet's globals are stubbed first (spec/helpers/sb_stubs.lua) so
-- that adapter files, which register code widgets and config schemas when
-- they load, can be loaded at all. Specs under spec/sb/ reset and drive those
-- stubs; specs under spec/core/ must not touch them, since they also run
-- inside real SilverBullet against the installed page.

dofile "spec/helpers/sb_stubs.lua"

local sources = dofile "tools/page_sources.lua"
for _, f in ipairs(sources.list("src").lua) do
  local chunk = assert(load(f.src, "@" .. f.path, "t"))
  chunk()
end
