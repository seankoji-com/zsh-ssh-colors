# shellcheck shell=bash disable=all
Describe 'zsh-ssh-colors.plugin.zsh'
  Include ./zsh-ssh-colors.plugin.zsh

  Describe 'ssh_colors_destination'
    It 'finds a bare host'
      When call ssh_colors_destination nas
      The output should equal 'nas'
    End

    It 'strips a user@ prefix'
      When call ssh_colors_destination alice@nas
      The output should equal 'nas'
    End

    It 'ignores a trailing command'
      When call ssh_colors_destination nas uptime
      The output should equal 'nas'
    End

    It 'skips bare flags'
      When call ssh_colors_destination -v -A nas
      The output should equal 'nas'
    End

    # `ssh -l alice nas` would otherwise report 'alice' as the destination.
    It 'skips the value of an option that takes one'
      When call ssh_colors_destination -l alice nas
      The output should equal 'nas'
    End

    It 'skips a port argument'
      When call ssh_colors_destination -p 2222 nas
      The output should equal 'nas'
    End

    It 'handles the glued -ovalue form'
      When call ssh_colors_destination -oStrictHostKeyChecking=no nas
      The output should equal 'nas'
    End

    It 'handles several options before the host'
      When call ssh_colors_destination -i ~/.ssh/id -p 22 -A nas ls -la
      The output should equal 'nas'
    End

    It 'fails when there is no destination'
      When call ssh_colors_destination -v
      The status should be failure
    End
  End

  Describe 'ssh_colors_lookup'
    setup() {
      zstyle ':ssh-colors:host' nas '#2d1b4d'
      zstyle ':ssh-colors:host' pi '#1a3a2a'
    }
    cleanup() {
      zstyle -d ':ssh-colors:host'
      zstyle -d ':ssh-colors:pattern'
      ZSH_SSH_COLORS_PATTERNS=()
    }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'returns the colour for a mapped host'
      When call ssh_colors_lookup nas
      The output should equal '#2d1b4d'
    End

    It 'fails for an unmapped host'
      When call ssh_colors_lookup unknown
      The status should be failure
      The output should equal ''
    End

    # Substring matching would tint 'api-staging' the same as 'api', which is
    # exactly the confusion this plugin exists to prevent.
    It 'does not match a host that merely contains a mapped name'
      When call ssh_colors_lookup nas-staging
      The status should be failure
    End

    It 'fails on an empty destination'
      When call ssh_colors_lookup ''
      The status should be failure
    End

    Describe 'patterns'
      It 'matches a registered pattern'
        run_it() {
          ZSH_SSH_COLORS_PATTERNS=('prod-*')
          zstyle ':ssh-colors:pattern' 'prod-*' '#4d1b1b'
          ssh_colors_lookup prod-web-01
        }
        When call run_it
        The output should equal '#4d1b1b'
      End

      It 'prefers an exact host mapping over a pattern'
        run_it() {
          ZSH_SSH_COLORS_PATTERNS=('n*')
          zstyle ':ssh-colors:pattern' 'n*' '#000000'
          ssh_colors_lookup nas
        }
        When call run_it
        The output should equal '#2d1b4d'
      End

      It 'ignores a pattern that does not match'
        run_it() {
          ZSH_SSH_COLORS_PATTERNS=('prod-*')
          zstyle ':ssh-colors:pattern' 'prod-*' '#4d1b1b'
          ssh_colors_lookup dev-web-01
        }
        When call run_it
        The status should be failure
      End
    End
  End

  Describe 'the ssh wrapper'
    setup() {
      zstyle ':ssh-colors:host' nas '#2d1b4d'
      # Stand in for the real binary. `command ssh` bypasses functions, so the
      # fake has to be on PATH.
      FAKEBIN="$(mktemp -d)"
      cat > "$FAKEBIN/ssh" <<'EOF'
#!/bin/sh
echo "ssh called: $*"
exit "${FAKE_SSH_EXIT:-0}"
EOF
      chmod +x "$FAKEBIN/ssh"
      PATH="$FAKEBIN:$PATH"
      hash -r
    }
    cleanup() { rm -rf "$FAKEBIN"; zstyle -d ':ssh-colors:host'; }
    BeforeEach 'setup'
    AfterEach 'cleanup'

    It 'passes every argument through untouched'
      When call ssh -p 22 nas uptime
      The output should include 'ssh called: -p 22 nas uptime'
    End

    It 'sets and resets the background for a mapped host'
      When call ssh nas
      The output should include $'\033]11;#2d1b4d\007'
      The output should include $'\033]111\007'
    End

    It 'emits no escapes for an unmapped host'
      When call ssh someotherhost
      The output should not include $'\033]11;'
      The output should not include $'\033]111'
    End

    It 'preserves the exit status of the real ssh'
      run_it() { FAKE_SSH_EXIT=255 ssh nas; }
      When call run_it
      The status should equal 255
      The output should include 'ssh called'
    End

    # The reset has to happen even when the session failed, or the terminal
    # stays tinted for the rest of its life.
    It 'still resets the background after a failed session'
      run_it() { FAKE_SSH_EXIT=255 ssh nas; }
      When call run_it
      The status should equal 255
      The output should include $'\033]111\007'
    End
  End
End
