# name: Stray ~/.tmux.conf
#
# tmux reads /etc/tmux.conf, then ~/.tmux.conf, then
# $XDG_CONFIG_HOME/tmux/tmux.conf — and it loads every one of them that exists,
# rather than stopping at the first. So an old ~/.tmux.conf left over from
# before this repo does NOT lose to the config step 10 just symlinked: it wins
# every option the tracked file does not set, and loses every option it does.
#
# The result is a hybrid nobody wrote, and the failure is silent. What it looked
# like in practice: a stale `unbind C-b` from the old file with a tracked config
# that only set the prefix later, leaving a session with no working prefix at
# all and a config file that looked correct.
#
# Numbered 11 so it runs immediately after the symlinks that create the tracked
# config. Never deletes: same ~/.dotfiles-backup/ as step 10.

stray="$HOME/.tmux.conf"

[ -e "$stray" ] || [ -L "$stray" ] || { ok "no stray ~/.tmux.conf"; return 0; }

backup="$HOME/.dotfiles-backup"
mkdir -p "$backup"

# Never clobber an earlier backup of a different file.
dest="$backup/.tmux.conf"
if [ -e "$dest" ]; then
  dest="$backup/.tmux.conf.$(date +%Y%m%d-%H%M%S)"
fi

mv "$stray" "$dest"
warn "moved ~/.tmux.conf to ~/${dest#"$HOME"/}"
info "it would have shadowed ~/.config/tmux/tmux.conf option by option"
info "anything in it you still want belongs in config/shared/.config/tmux/tmux.conf"
