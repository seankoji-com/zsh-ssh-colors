# zsh-ssh-colors — tint the terminal background by SSH destination.
#
# Running the same command on the wrong host is a whole category of mistake
# that a glance can prevent. This wraps ssh so the terminal background changes
# colour for hosts you have mapped, and resets when the session ends.
#
# Configure with zstyle, keyed on the destination as you type it:
#
#     zstyle ':ssh-colors:host' nas '#2d1b4d'
#     zstyle ':ssh-colors:host' prod '#4d1b1b'
#
# Matching is exact against the host argument with any user@ prefix stripped.
# Exact, not glob: a substring match on 'api' would also tint 'api-staging',
# which is precisely the confusion this is meant to prevent. To match a family
# of hosts, map each one, or set a pattern explicitly:
#
#     zstyle ':ssh-colors:pattern' 'prod-*' '#4d1b1b'
#
# Uses OSC 11 to set the background and OSC 111 to reset it. Both are widely
# supported (xterm, WezTerm, iTerm2, kitty, Alacritty, foot). Terminals that
# do not understand them ignore them.

# Patterns to try after an exact lookup misses. zstyle has no "enumerate keys"
# API, so the pattern list has to live somewhere it can be iterated.
typeset -ga ZSH_SSH_COLORS_PATTERNS

# Look up the colour for a destination. Exact zstyle first, then patterns.
# Public, so a prompt or another wrapper can ask the same question.
ssh_colors_lookup() {
  local dest=$1 color='' pattern
  [[ -n "$dest" ]] || return 1

  if zstyle -s ':ssh-colors:host' "$dest" color && [[ -n "$color" ]]; then
    print -r -- "$color"
    return 0
  fi

  # zstyle has no "list every key" API, so patterns are kept in an array the
  # user appends to.
  for pattern in "${ZSH_SSH_COLORS_PATTERNS[@]}"; do
    if [[ "$dest" == ${~pattern} ]]; then
      if zstyle -s ':ssh-colors:pattern' "$pattern" color && [[ -n "$color" ]]; then
        print -r -- "$color"
        return 0
      fi
    fi
  done
  return 1
}

# Pull the destination out of an ssh command line: the first non-option
# argument, with any user@ prefix removed.
#
# The skip list matters. `ssh -l alice nas` would otherwise report 'alice' as
# the destination, and `ssh nas uptime` has to still resolve to 'nas' rather
# than 'uptime'.
ssh_colors_destination() {
  local arg skip=0
  for arg in "$@"; do
    if (( skip )); then skip=0; continue; fi
    case "$arg" in
      # Options that take a separate value.
      -[bcDEeFIiJLlmOopQRSWw]) skip=1 ;;
      # A bare flag, or the glued -ovalue form.
      -*) ;;
      *) print -r -- "${arg##*@}"; return 0 ;;
    esac
  done
  return 1
}

ssh() {
  local dest color=''
  dest=$(ssh_colors_destination "$@") && color=$(ssh_colors_lookup "$dest")

  [[ -n "$color" ]] && printf '\033]11;%s\007' "$color"

  command ssh "$@"
  local exit_code=$?

  [[ -n "$color" ]] && printf '\033]111\007'

  return $exit_code
}
