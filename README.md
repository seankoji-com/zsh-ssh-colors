# zsh-ssh-colors

Tints the terminal background by SSH destination, and resets when the session
ends. Running the right command on the wrong host is a whole category of
mistake that a glance can prevent.

## Install

```sh
git clone https://github.com/seankoji-com/zsh-ssh-colors \
  ~/.oh-my-zsh_custom/plugins/zsh-ssh-colors
```

```zsh
plugins=(... zsh-ssh-colors)
```

## Configure

```zsh
zstyle ':ssh-colors:host' nas  '#2d1b4d'
zstyle ':ssh-colors:host' pi   '#1a3a2a'
zstyle ':ssh-colors:host' prod '#4d1b1b'
```

Keyed on the destination as you type it, with any `user@` prefix stripped.

Matching is exact, not substring. A substring match on `api` would also tint
`api-staging`, which is precisely the confusion this is meant to prevent. For a
family of hosts, register a pattern:

```zsh
ZSH_SSH_COLORS_PATTERNS+=('prod-*')
zstyle ':ssh-colors:pattern' 'prod-*' '#4d1b1b'
```

Exact host mappings win over patterns.

## How it works

Wraps `ssh`, emitting OSC 11 to set the background before the session and OSC
111 to reset it after, including when the session fails. Both sequences are
widely supported: xterm, WezTerm, iTerm2, kitty, Alacritty, foot. Terminals
that do not understand them ignore them.

Arguments are passed through untouched and the real exit status is preserved.

Finding the destination means skipping flags *and* the values of flags that
take one, so `ssh -l alice nas` reports `nas` rather than `alice`, and
`ssh nas uptime` reports `nas` rather than `uptime`.

## Functions

`ssh_colors_lookup <destination>` returns the mapped colour, non-zero if
unmapped.

`ssh_colors_destination <args...>` extracts the destination from an ssh command
line.

## Licence

MIT
