# name: tmux plugins (tpm)
#
# tpm is the tmux plugin manager. It is not itself a plugin, so it cannot
# bootstrap itself: something has to clone it before tmux can load it, and on a
# fresh machine that something is this step.
#
# The plugin list is not here. It lives in the tracked
# config/shared/.config/tmux/tmux.conf as `@plugin` lines (section 6), so this
# step never needs editing when a plugin is added or dropped — the same split as
# step 55 and the mise tool list.
#
# Numbered 57 so it lands after mise (55) has installed fzf and tmux, and after
# claude (45): the plugins declared today need all three at *use* time, and
# installing in dependency order keeps a first run from looking broken.

has tmux || die "no tmux — run ./install.sh mise first"

tpm_dir="$HOME/.config/tmux/plugins/tpm"

# tpm finds this directory by itself. Its built-in default is ~/.tmux/plugins,
# but when an XDG config exists it uses the plugins directory beside it, which
# is why the tracked tmux.conf sets no TMUX_PLUGIN_MANAGER_PATH.
[ -f "$HOME/.config/tmux/tmux.conf" ] || die "no tmux config — run ./install.sh symlinks first"

if [ -d "$tpm_dir/.git" ]; then
  info "tpm already cloned"
else
  git clone -q https://github.com/tmux-plugins/tpm "$tpm_dir" || die "tpm clone failed"
  ok "tpm cloned"
fi

# Fetch whatever the tracked config declares. This talks to a tmux server, so it
# works with no terminal attached — which is the case during install.
"$tpm_dir/bin/install_plugins" >/dev/null 2>&1 || warn "some plugins failed to install"

installed=$(find "$HOME/.config/tmux/plugins" -maxdepth 1 -mindepth 1 -type d ! -name tpm | wc -l | tr -d ' ')
ok "$installed plugin(s) installed"

# A running server that predates this step still has no plugin keys bound: tpm
# sources plugins when the config is read, and that already happened. Reload
# rather than restart, so nothing running in a pane is lost.
info "in an existing session: prefix r, or tmux source ~/.config/tmux/tmux.conf"
