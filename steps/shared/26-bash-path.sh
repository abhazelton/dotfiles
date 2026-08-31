# name: mise on PATH for bash
#
# mise is activated in ~/.zshrc, and only there. That is fine for a shell you
# sit in, but it leaves node, yarn, tmux and the rest invisible to anything that
# never reaches zsh:
#
#   * login and script shells — `bash -lc 'yarn --version'`, cron, CI
#   * coding agents that run their tools through a non-interactive bash
#   * anything started before step 25's trampoline execs zsh
#
# So: prepend mise's shims directory to PATH in ~/.bashrc and ~/.profile. Both
# are untracked machine files, which is the only reason appending to them is
# allowed here — never do this to ~/.zshrc, which is a symlink into this repo.
#
# Placed ABOVE step 25's `exec zsh -l` trampoline when that is present, so the
# line is reached before the handover and is exported into zsh as well. Order
# does not otherwise matter: zsh's `mise activate` puts the same directory
# first, and `typeset -U path` dedupes it.

shims="$HOME/.local/share/mise/shims"
marker='# dotfiles: mise shims on PATH'
trampoline='# dotfiles: use zsh (the login shell could not be changed)'

block="
$marker
# So node/yarn/pnpm/bun/tmux/fzf resolve in shells that never reach zsh, where
# \`mise activate\` would have done it. See steps/shared/26-bash-path.sh.
[ -d \"\$HOME/.local/share/mise/shims\" ] && export PATH=\"\$HOME/.local/share/mise/shims:\$PATH\"
"

for rc in "$HOME/.bashrc" "$HOME/.profile"; do
  [ -f "$rc" ] || continue

  if grep -qF "$marker" "$rc"; then
    info "$(basename "$rc") already has it"
    continue
  fi

  if grep -qF "$trampoline" "$rc"; then
    # Insert above the trampoline: awk rather than sed, so the block's slashes
    # and quotes need no escaping.
    tmp=$(mktemp)
    awk -v blk="$block" -v pat="$trampoline" '
      index($0, pat) && !done { printf "%s\n", blk; done = 1 }
      { print }
    ' "$rc" > "$tmp" && cat "$tmp" > "$rc" && rm -f "$tmp"
    ok "$(basename "$rc") — inserted above the zsh trampoline"
  else
    printf '%s\n' "$block" >> "$rc"
    ok "$(basename "$rc") — appended"
  fi
done

if [ -d "$shims" ]; then
  ok "shims dir exists: $shims"
else
  info "shims dir appears once mise has installed something (step 55)"
fi
