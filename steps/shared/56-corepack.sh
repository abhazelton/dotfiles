# name: yarn and pnpm (corepack)
#
# mise installs node and bun but not yarn or pnpm, and adding them to its tool
# list would pin one global version that then fights every project's own
# `packageManager` field. corepack ships inside node and is the supported way:
# it puts `yarn` and `pnpm` shims on PATH which, on first use in a project,
# fetch the exact version that project asks for.
#
# Runs after step 55, which is what provides node in the first place.

PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$PATH"

has node || { warn "no node — run ./install.sh mise first, then this step"; return 0; }
has corepack || { warn "node $(node -v) has no corepack; skipping"; return 0; }

corepack enable

# corepack writes its shims into node's own bin directory, which for a
# mise-managed node is inside mise's install tree — so mise needs to be told to
# regenerate its shims or the new binaries stay invisible.
has mise && mise reshim

# Deliberately not `yarn --version` as the check: that would trigger corepack's
# download of a default version here, at install time, rather than leaving it to
# the first project that actually asks for one.
if [ -x "$(command -v yarn)" ] || command -v yarn >/dev/null 2>&1; then
  ok "yarn and pnpm are on PATH (versions resolve per project)"
else
  warn "corepack ran but yarn is not on PATH — check 'mise reshim' output"
fi
