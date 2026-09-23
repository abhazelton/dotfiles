# Terminal input modes — clearing what a dropped connection left behind.
#
# The problem in one line: close the laptop, lose the ssh connection, come back
# and every mouse movement types garbage into the terminal.
#
# Why it happens. A terminal only reports mouse movement because a program asked
# it to, and tmux asks: `set -g mouse on` and `set -g focus-events on` in
# ~/.config/tmux/tmux.conf. Those are requests made to *your laptop's* terminal,
# over the wire, and they are meant to be withdrawn when tmux exits. Kill the
# connection instead of tmux and the withdrawal never arrives. The remote side
# is fine — tmux is still sitting there, happy. The laptop is the casualty: its
# terminal is still faithfully reporting every pixel of mouse movement to
# whatever now holds the foreground, which is a shell that has no idea what
# those bytes mean and echoes them at you.
#
# Why the fix belongs at the prompt. The stuck mode outlives the program that
# asked for it, so nothing that program does can help — by the time you see the
# damage, it is gone. But the giveaway is that you *see the characters echoed*,
# and that only happens at a shell prompt. precmd runs immediately before each
# prompt is drawn, including the one drawn the instant a dead ssh finally
# returns, so the repair lands exactly where the symptom does.
#
# Note there is deliberately no `[[ -z $TMUX ]]` guard. It is tempting — the
# stuck terminal is always the local one, never the remote shell inside tmux —
# but it would be a bet on every multiplexer setting $TMUX, and a wrong bet
# silently disables the whole file. Running inside tmux costs one harmless
# printf per prompt instead, and tmux keeps its own mouse setting regardless of
# what programs in its panes ask for, which is why vim can turn mouse reporting
# on and off all day inside a pane without tmux losing its own.
#
# DOTFILES_INPUT_MODE_RESET=0 in ~/.zshrc.local turns it off for one machine.

[[ ${DOTFILES_INPUT_MODE_RESET:-1} == 1 ]] || return
[[ -o interactive ]]                       || return
[[ -t 1 ]]                                 || return
[[ $TERM != dumb ]]                        || return

# _reset_input_modes — withdraw every request a dead program left standing.
#
#   1000  mouse clicks
#   1002  clicks and drags
#   1003  every movement, button or not — this is the one filling your screen
#   1004  focus in/out, which strands ^[[I and ^[[O on each window switch
#   1005  \
#   1006   > the coordinate encodings tmux enables alongside mouse mode, since
#   1015  /  plain 1000-series reporting cannot express a wide window
#   25h   show the cursor, in case a killed full-screen program hid it
#
# Bracketed paste (2004) is missing on purpose. It belongs in a hand-typed
# `reset`, but zsh enables it itself for safe multi-line pasting, so turning it
# off here would quietly cost you that on every prompt to fix nothing.
_reset_input_modes() {
  local off=$'\e[?1000l\e[?1002l\e[?1003l\e[?1004l\e[?1005l\e[?1006l\e[?1015l\e[?25h'
  print -rn -- "$off"

  # Second copy, for the prompt that is inside tmux.
  #
  # The printf above does not reach the terminal there. tmux reads it, applies
  # it to its model of this pane, and goes on driving the real terminal from its
  # own idea of what the modes should be — so the stuck reporting outlives it.
  # Wrapping the same bytes in tmux's DCS passthrough (allow-passthrough on, set
  # in section 1 of the tmux config) hands them to the outer terminal untouched.
  # Inner escapes have to be doubled; that is the passthrough's own escaping.
  [[ -n $TMUX ]] || return
  # Only when this tmux is not itself using the mouse. With mouse on there is
  # nothing to fix — tmux is consuming the reports, which is why they are not
  # landing in your shell as text — and withdrawing them would break its
  # scrolling and pane clicks until the next redraw.
  [[ $(command tmux show-options -gv mouse 2>/dev/null) == off ]] || return
  # esc is a variable because zsh does not expand $'...' in the replacement half
  # of ${//}: written inline it substitutes the seven literal characters $'\e\e'
  # and the passthrough carries nonsense the terminal prints.
  local esc=$'\e'
  print -rn -- $'\ePtmux;'"${off//$esc/$esc$esc}"$'\e\\'
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _reset_input_modes
