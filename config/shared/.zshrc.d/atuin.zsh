# atuin key bindings, and zsh's own history as a backstop.
#
# ~/.zshrc sets ATUIN_NOBIND=true and then binds Ctrl+R only. That leaves the up
# arrow on zsh's *own* history — a different, initially empty file — which on a
# machine moving from bash to zsh looks exactly like "my history is gone": up
# shows one entry, and Ctrl+R shows nothing either until
# `[search] shells = "all"` is set in ~/.config/atuin/config.toml. In bash atuin
# binds the up key itself; this file puts that behaviour back in zsh.
#
# Drop-ins are sourced last by ~/.zshrc (section 7), after its own bindkey call,
# which is what lets this file win.

command -v atuin &>/dev/null || return

# atuin-up-search only opens the search UI when there is nothing above the
# cursor, so editing a multi-line command still moves the cursor normally.
bindkey '^[[A' atuin-up-search        # up arrow
bindkey '^[OA' atuin-up-search        # up arrow, application/keypad mode
bindkey -M vicmd 'k' atuin-up-search-vicmd

# zsh's own history still matters: it is what survives atuin being absent, and
# what Ctrl+P and the line editor read. oh-my-zsh sets HISTFILE=~/.zsh_history
# with SAVEHIST=10000; these raise it and share it live between panes.
HISTSIZE=100000
SAVEHIST=100000
setopt SHARE_HISTORY INC_APPEND_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS
