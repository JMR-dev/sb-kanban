#!/usr/bin/env bash
# Installs the pinned, checksum-verified toolchain from tools/versions.env into
# .tools/ (override with TOOLS_DIR). Used both locally and by CI.
#
#   scripts/bootstrap.sh            # everything
#   scripts/bootstrap.sh lua stylua # a subset: lua luarocks rocks luacheck stylua luals silverbullet
#
# Re-running is cheap: each tool is skipped when its stamp file already records
# the pinned version.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../tools/versions.env
source "${repo_root}/tools/versions.env"

tools_dir="${TOOLS_DIR:-${repo_root}/.tools}"
bin_dir="${tools_dir}/bin"
mkdir -p "$bin_dir"

all_tools=(lua luarocks rocks luacheck stylua luals silverbullet)
if [[ $# -gt 0 ]]; then
  selected=("$@")
else
  selected=("${all_tools[@]}")
fi

log() { printf '==> %s\n' "$*" >&2; }

# fetch <url> <sha256> <dest>: download into a fresh directory and verify.
fetch() {
  local url="$1" sum="$2" dest="$3"
  mkdir -p "$(dirname "$dest")"
  curl -fsSL --retry 3 -o "$dest" "$url"
  echo "${sum}  ${dest}" | sha256sum -c --quiet -
}

# up_to_date <name> <version>: true when the stamp records this version.
up_to_date() {
  [[ -f "${tools_dir}/.stamp-$1" && "$(cat "${tools_dir}/.stamp-$1")" == "$2" ]]
}
stamp() { echo "$2" >"${tools_dir}/.stamp-$1"; }

# fresh_dir <path>: an empty directory for one download/extraction.
fresh_dir() {
  rm -rf "$1"
  mkdir -p "$1"
}

install_lua() {
  up_to_date lua "$LUA_VERSION" && return
  log "lua ${LUA_VERSION}"
  local work="${tools_dir}/dl/lua"
  fresh_dir "$work"
  fetch "https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz" "$LUA_SHA256" "${work}/lua.tar.gz"
  tar -C "$work" -xzf "${work}/lua.tar.gz"
  make -C "${work}/lua-${LUA_VERSION}" -j"$(nproc)" linux >/dev/null
  make -C "${work}/lua-${LUA_VERSION}" test
  rm -rf "${tools_dir}/lua"
  make -C "${work}/lua-${LUA_VERSION}" install INSTALL_TOP="${tools_dir}/lua" >/dev/null
  ln -sf "${tools_dir}/lua/bin/lua" "${bin_dir}/lua"
  ln -sf "${tools_dir}/lua/bin/luac" "${bin_dir}/luac"
  stamp lua "$LUA_VERSION"
}

install_luarocks() {
  up_to_date luarocks "$LUAROCKS_VERSION" && return
  log "luarocks ${LUAROCKS_VERSION}"
  local work="${tools_dir}/dl/luarocks"
  fresh_dir "$work"
  fetch "https://luarocks.github.io/luarocks/releases/luarocks-${LUAROCKS_VERSION}.tar.gz" \
    "$LUAROCKS_SHA256" "${work}/luarocks.tar.gz"
  tar -C "$work" -xzf "${work}/luarocks.tar.gz"
  (
    cd "${work}/luarocks-${LUAROCKS_VERSION}"
    ./configure --prefix="${tools_dir}/luarocks" --with-lua="${tools_dir}/lua" >/dev/null
    make >/dev/null
    rm -rf "${tools_dir}/luarocks"
    make install >/dev/null
  )
  ln -sf "${tools_dir}/luarocks/bin/luarocks" "${bin_dir}/luarocks"
  stamp luarocks "$LUAROCKS_VERSION"
}

# Dev rocks (busted and its dependencies) into the project-local lua_modules/
# tree, at the versions pinned in luarocks.lock.
#
# luarocks.lock comes from `luarocks build --only-deps --pin`, with its
# `lua = "5.5-1"` entry deleted by hand: LuaRocks 3.13 pins the interpreter as
# if it were a rock and then fails every fresh install with "pinned to lua
# 5.5-1 (not installed)". The interpreter is pinned by LUA_VERSION instead.
install_rocks() {
  local lock_sum
  lock_sum="$(sha256sum "${repo_root}/luarocks.lock" "${repo_root}"/sb-kanban-dev-*.rockspec | sha256sum | cut -d' ' -f1)"
  up_to_date rocks "$lock_sum" && return
  log "rocks (luarocks.lock)"
  (
    cd "$repo_root"
    "${bin_dir}/luarocks" --tree="${repo_root}/lua_modules" --lua-dir="${tools_dir}/lua" \
      --lua-version="${LUA_VERSION%.*}" build --only-deps sb-kanban-dev-1.rockspec >/dev/null
  )
  stamp rocks "$lock_sum"
}

install_stylua() {
  up_to_date stylua "$STYLUA_VERSION" && return
  log "stylua ${STYLUA_VERSION}"
  local work="${tools_dir}/dl/stylua"
  fresh_dir "$work"
  fetch "https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA_VERSION}/stylua-linux-x86_64.zip" \
    "$STYLUA_SHA256" "${work}/stylua.zip"
  unzip -q -o "${work}/stylua.zip" stylua -d "$work"
  install -m 0755 "${work}/stylua" "${bin_dir}/stylua"
  stamp stylua "$STYLUA_VERSION"
}

# luacheck from a pinned master commit (see versions.env), built into the same
# lua_modules/ tree as busted. Its dependencies (argparse, luafilesystem) are
# pinned through the dev rockspec, so `rocks` must run first.
install_luacheck() {
  up_to_date luacheck "$LUACHECK_COMMIT" && return
  log "luacheck ${LUACHECK_COMMIT:0:12}"
  local work="${tools_dir}/dl/luacheck"
  fresh_dir "$work"
  fetch "https://github.com/lunarmodules/luacheck/archive/${LUACHECK_COMMIT}.tar.gz" \
    "$LUACHECK_SHA256" "${work}/luacheck.tar.gz"
  tar -C "$work" -xzf "${work}/luacheck.tar.gz"
  (
    cd "${work}/luacheck-${LUACHECK_COMMIT}"
    "${bin_dir}/luarocks" --tree="${repo_root}/lua_modules" --lua-dir="${tools_dir}/lua" \
      --lua-version="${LUA_VERSION%.*}" make --deps-mode=none luacheck-dev-1.rockspec >/dev/null
  )
  stamp luacheck "$LUACHECK_COMMIT"
}

install_luals() {
  up_to_date luals "$LUALS_VERSION" && return
  log "lua-language-server ${LUALS_VERSION}"
  local work="${tools_dir}/dl/luals"
  fresh_dir "$work"
  fetch "https://github.com/LuaLS/lua-language-server/releases/download/${LUALS_VERSION}/lua-language-server-${LUALS_VERSION}-linux-x64.tar.gz" \
    "$LUALS_SHA256" "${work}/luals.tar.gz"
  fresh_dir "${tools_dir}/luals"
  tar -C "${tools_dir}/luals" -xzf "${work}/luals.tar.gz"
  ln -sf "${tools_dir}/luals/bin/lua-language-server" "${bin_dir}/lua-language-server"
  stamp luals "$LUALS_VERSION"
}

install_silverbullet() {
  up_to_date silverbullet "$SILVERBULLET_VERSION" && return
  log "silverbullet ${SILVERBULLET_VERSION}"
  local work="${tools_dir}/dl/silverbullet"
  fresh_dir "$work"
  fetch "https://github.com/silverbulletmd/silverbullet/releases/download/${SILVERBULLET_VERSION}/silverbullet-server-linux-x86_64.zip" \
    "$SILVERBULLET_SHA256" "${work}/silverbullet.zip"
  unzip -q -o "${work}/silverbullet.zip" -d "$work/extract"
  install -m 0755 "$(find "${work}/extract" -type f -name silverbullet | head -1)" "${bin_dir}/silverbullet"
  stamp silverbullet "$SILVERBULLET_VERSION"
}

for tool in "${selected[@]}"; do
  case "$tool" in
    lua) install_lua ;;
    luarocks) install_luarocks ;;
    rocks) install_rocks ;;
    luacheck) install_luacheck ;;
    stylua) install_stylua ;;
    luals) install_luals ;;
    silverbullet) install_silverbullet ;;
    *)
      echo "unknown tool: $tool (expected one of: ${all_tools[*]})" >&2
      exit 1
      ;;
  esac
done

log "tools ready in ${bin_dir}"
