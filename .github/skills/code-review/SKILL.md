---
name: code-review
description: Review priorities for zsh-ssh-colors pull requests — where to focus (the ssh argument parser and the wrapper's reset guarantee) and what to skip (docs, licensing, test-framework boilerplate). Use for every PR review.
---

# Review priorities

This repo's whole plugin is one file (`zsh-ssh-colors.plugin.zsh`) plus its shellspec suite. There's no recurring bug pattern in the PR history yet — the four PRs so far were all CI/template-sync attempts, none touched the plugin logic — so these priorities come from what the code itself does, not from history.

## Spend real attention here

- `ssh_colors_destination`'s flag-skip list (`-[bcDEeFIiJLlmOopQRSWw]`) is a hardcoded enumeration of every `ssh(1)` option that takes a separate value. Get one wrong (missing, extra, or misclassified as glued-only) and the destination is silently misidentified — a flag's value gets tinted as the host, or the host is missed entirely. Any PR touching this case statement deserves a check against real `ssh(1)` flags, not just against the existing test cases.
- The control flow inside the `ssh()` wrapper between the OSC 11 emit and the OSC 111 reset. There's no `trap`/finally — the "resets even when the session fails" guarantee (the plugin's whole reason to exist) depends on every line in between running to completion. An early `return`, a newly inserted command that can abort the function, or reordering breaks that guarantee silently.
- Any bare `ssh` call inside the wrapper or the functions it calls, instead of `command ssh`. `ssh` is redefined as a shell function here, so an unwrapped call recurses.
- Exact-vs-pattern precedence in `ssh_colors_lookup` (exact match must always win over a `ZSH_SSH_COLORS_PATTERNS` entry). It's the documented behavior distinguishing this from a plain substring-match tool, called out explicitly in the README.

## Do not spend attention here

- README.md, LICENSE — prose and licensing, no behavior.
- spec/spec_helper.sh, .shellspec — shellspec framework wiring, not plugin logic.
- Style/formatting nits anywhere — there's no linter or formatter configured in this repo, so don't burn comments on it. Behavior only. (Exception: in shell/zsh, quoting affects behavior — unquoting a variable enables word-splitting and globbing, and re-quoting changes $@/"$@" expansion. Keep quoting that changes behavior in scope; skip only cosmetic quote style like single- vs double-quote choice.)

## Comment style

- One comment per real issue, not one per file it repeats in.
- Skip restating what spec/zsh-ssh-colors_spec.sh already exercises (option-skip cases, exact-vs-pattern precedence, reset-after-failure, exit-status passthrough are all covered there) — flag gaps in that coverage, not behavior it already asserts.
