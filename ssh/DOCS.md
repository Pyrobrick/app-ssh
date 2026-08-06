# Home Assistant Community App: Advanced SSH & Web Terminal

This app allows you to log in to your Home Assistant instance using
SSH or a Web Terminal, giving you access to your folders and
also includes a command-line tool to do things like restart, update,
and check your instance.

This is an enhanced version of the provided
[SSH add-on by Home Assistant][hass-ssh] and focuses on security,
usability, flexibility and also provides access using a web interface.

## WARNING

The advanced SSH & Web Terminal app is very powerful and gives you access
to almost all tools and hardware of your system.

While this app is created and maintained with care and with security in mind,
in the wrong or inexperienced hands, it could damage your system.

## Features

This app, of course, provides an SSH server, based on [OpenSSH][openssh] and
a web-based Terminal (which can be included in your Home Assistant frontend) as
well. Additionally, it comes out of the box with the following:

- Access your command line right from the Home Assistant frontend!
- A secure default configuration of SSH:
  - Only allows login by the configured user, even if more users are created.
  - Only uses known secure ciphers and algorithms.
  - Limits login attempts to hold off brute-force attacks better.
- Comes with an SSH compatibility mode option to allow older clients to connect.
- Support for Mosh allowing roaming and supports intermittent connectivity.
- SFTP support is disabled by default but is user configurable.
- Compatible if Home Assistant was installed via the generic Linux installer.
- Username is configurable, so `root` is no longer mandatory.
- Persists custom SSH client settings & keys between app restarts
- Log levels for allowing you to triage issues easier.
- Hardware access to your audio, uart/serial devices and GPIO pins.
- Runs with more privileges, allowing you to debug and test more situations.
- Has access to the dbus of the host system.
- Has the option to access the Docker instance running on the host system.
- Runs on host level network, allowing you to open ports or run little daemons.
- Have custom Alpine packages installed on start. This allows you to install
  your favorite tools, which will be available every single time you log in.
- Execute custom commands on app start so that you can customize the
  shell to your likings.
- Selectable interactive shells: Zsh with Oh My Zsh remains the compatible
  default, while Fish and Bash are available through the `shell` option.
- Selectable terminal session backends: tmux remains the compatible default,
  while Zellij is available through the `session_backend` option.
- Contains a sensible set of tools right out of the box: curl, Wget, RSync, GIT,
  Nmap, Mosquitto client, MariaDB/MySQL client, Awake ("wake on LAN"), Nano,
  Neovim, tmux, Zellij, and a bunch commonly used networking tools.

## Installation

The installation of this app is pretty straightforward and not different in
comparison to installing any other Home Assistant app.

1. Click the Home Assistant My button below to open the app on your Home
   Assistant instance.

   [![Open this app in your Home Assistant instance.][addon-badge]][addon]

1. Click the "Install" button to install the app.
1. Configure the `username` and `password`/`authorized_keys` options.
1. Start the "Advanced SSH & Web Terminal" app.
1. Check the logs of the "Advanced SSH & Web Terminal" app to see if everything
   went well.

## Configuration

**Note**: _Remember to restart the app when the configuration is changed._

SSH app configuration:

```yaml
log_level: info
ssh:
  username: homeassistant
  password: ""
  authorized_keys:
    - ssh-ed25519 AASDJKJKJFWJFAFLCNALCMLAK234234.....
  sftp: false
  compatibility_mode: false
  allow_agent_forwarding: false
  allow_remote_port_forwarding: false
  allow_tcp_forwarding: false
shell: fish
session_backend: zellij
share_sessions: true
packages:
  - build-base
init_commands:
  - ls -la
```

**Note**: _This is just an example, don't copy and paste it! Create your own!_

### Option: `log_level`

The `log_level` option controls the level of log output by the app and can
be changed to be more or less verbose, which might be useful when you are
dealing with an unknown issue. Possible values are:

- `trace`: Show every detail, like all called internal functions.
- `debug`: Shows detailed debug information.
- `info`: Normal (usually) interesting events.
- `warning`: Exceptional occurrences that are not errors.
- `error`: Runtime errors that do not require immediate action.
- `fatal`: Something went terribly wrong. App becomes unusable.

Please note that each level automatically includes log messages from a
more severe level, e.g., `debug` also shows `info` messages. By default,
the `log_level` is set to `info`, which is the recommended setting unless
you are troubleshooting.

Using `trace` or `debug` log levels puts the SSH and Terminal daemons into
debug mode. While SSH is running in debug mode, it will be only able to
accept one single connection at the time.

### Option group `ssh`

---

The following options are for the option group: `ssh`. These settings
only apply to the SSH daemon.

#### Option `ssh`: `username`

This option allows you to change to username the use when you log in via SSH.
It is only utilized for the authentication; you will be the `root` user after
you have authenticated. Using `root` as the username is possible, but not
recommended. Usernames will be converted to lower case as per recommended
practises.

**Note**: _Due to limitations, you will need to set this option to `root` in
order to be able to enable the SFTP capabilities._

#### Option `ssh`: `password`

Sets the password to log in with. Leaving it empty disables authenticating with
a password. Using public key authentication instead of password authentication
is highly recommended from a security point of view.

#### Option `ssh` `authorized_keys`

Add one or more public keys to your SSH server to use with authentication.
This is the recommended over setting a password.

Please take a look at the awesome [documentation created by GitHub][github-ssh]
about using public/private key pairs and how to create them.

**Note**: _Please ensure the keys are specified as a list by pasting within the
`[]` comma delimited._

#### Option `ssh`: `sftp`

When set to `true` the app will enable SFTP support on the SSH daemon.
Please only enable it when you plan on using it.

**Note**: _Due to limitations, you will need to set the username to `root` in
order to be able to enable the SFTP capabilities._

#### Option `ssh`: `compatibility_mode`

This SSH app focuses on security and has therefore only enabled known
secure encryption methods. However, some older clients do not support these.
Setting this option to `true` will enable the original default set of methods,
allowing those clients to connect.

**Note**: _Enabling this option, lowers the security of your SSH server!_

#### Option `ssh`: `allow_agent_forwarding`

Specifies whether ssh-agent forwarding is permitted or not.

**Note**: _Enabling this option, lowers the security of your SSH server!
Nevertheless, this warning is debatable._

#### Option `ssh`: `allow_remote_port_forwarding`

Specifies whether remote hosts are allowed to connect to ports forwarded
for the client.

**Note**: _Enabling this affects all remote forwardings, so think carefully
before doing this._

#### Option `ssh`: `allow_tcp_forwarding`

Specifies whether TCP forwarding is permitted or not.

**Note**: _Enabling this option, lowers the security of your SSH server!
Nevertheless, this warning is debatable._

### Shared settings

---

The following options are shared between both the SSH and the Web Terminal.

#### Option: `shell`

Selects the interactive shell used by SSH and the Web Terminal. Supported values
are `fish`, `zsh`, and `bash`. If this option is omitted, the legacy `zsh`
option remains authoritative so existing installations keep their current shell.

The root account itself deliberately keeps Bash as its account shell. The
selected interactive shell is started only after login, which keeps remote SSH
commands and tools such as rsync on a POSIX-compatible command shell.

#### Option: `session_backend`

Selects the terminal multiplexer used by the Web Terminal and, when session
sharing is enabled, SSH. Supported values are `zellij` and `tmux`. If this
option is omitted, tmux remains the default for compatibility with existing
installations.

Zellij uses mirrored sessions and its simplified UI in this app so simultaneous
SSH and Web Terminal clients see the same workspace without requiring special
terminal fonts.

#### Option: `zsh`

This is the legacy shell selector. It remains supported for upgrades: `true`
selects Zsh and `false` selects Bash when `shell` is absent. New
configurations should use `shell` instead.

#### Option: `share_sessions`

When enabled, interactive SSH clients attach to the same multiplexer session as
the Web Terminal. When disabled, SSH starts the selected shell without attaching
to the Web Terminal session. Non-interactive SSH commands never enter a
multiplexer.

#### Option: `packages`

Allows you to specify additional [Alpine packages][alpine-packages] to be
installed in your shell environment (e.g., Python, Joe, Irssi).

The packages are installed using Alpine's package manager, so any package name
from the [Alpine package index][alpine-packages] works. List the package names
exactly as they appear there. For example:

```yaml
packages:
  - iperf3
  - socat
  - joe
```

This installs the packages on every start, so they are always available when
you log in. Note that package names are not always the same as the command
they provide (for example, the `ncat` command comes from the `nmap-ncat`
package).

**Note**: _Adding many packages will result in a longer start-up
time for the app._

#### Option: `init_commands`

Customize your shell environment even more with the `init_commands` option.
Add one or more shell commands to the list, and they will be executed every
single time this app starts.

## Clipboard: copying and pasting

The Web Terminal is based on xterm.js, which follows X11-style clipboard
conventions that may differ from what you expect:

- **Copy**: hold `Shift` and select the text with your mouse. The selection is
  copied to your system clipboard right away (a small scissors icon briefly
  pops up). There is no need to press `Ctrl+C`.
- **Paste**: press `Ctrl+Shift+V`, or right-click and choose paste, depending
  on your browser.

This applies to the Web Terminal in the Home Assistant frontend. A regular SSH
client uses the clipboard behavior of its own terminal instead.

## Known issues and limitations

- When SFTP is enabled, the username MUST be set to `root`.

## Running the `ha` command or Supervisor API non-interactively

Non-interactive SSH commands always run under Bash and never enter the selected
multiplexer. With the default non-root SSH username, the login wrapper executes
the command through root's Bash login environment. When logging in directly as
root, OpenSSH invokes root's Bash account shell and imports the
`SUPERVISOR_TOKEN` from the permitted SSH environment:

```shell
ssh your-instance "ha core info"
```

The command's output and exit status are returned directly to the SSH client.
Interactive SSH and Web Terminal logins still use the configured `shell` and,
when enabled, the configured shared-session backend.

Mosh bootstraps through non-interactive SSH command mode. It therefore starts
Bash and does not attach to the configured shared-session backend.

## Changelog & Releases

This repository keeps a change log using [GitHub's releases][releases]
functionality.

Releases are based on [Semantic Versioning][semver], and use the format
of `MAJOR.MINOR.PATCH`. In a nutshell, the version will be incremented
based on the following:

- `MAJOR`: Incompatible or major changes.
- `MINOR`: Backwards-compatible new features and enhancements.
- `PATCH`: Backwards-compatible bugfixes and package updates.

## Support

Got questions?

You have several options to get them answered:

- The [Home Assistant Community Apps Discord chat server][discord] for app
  support and feature requests.
- The [Home Assistant Discord chat server][discord-ha] for general Home
  Assistant discussions and questions.
- The Home Assistant [Community Forum][forum].
- Join the [Reddit subreddit][reddit] in [/r/homeassistant][reddit]

You could also [open an issue here][issue] on GitHub.

## Authors & contributors

The original setup of this repository is by [Franck Nijhof][frenck].

For a full list of all authors and contributors,
check [the contributors page][contributors].

## License

MIT License

Copyright (c) 2017-2026 Franck Nijhof

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

[addon-badge]: https://my.home-assistant.io/badges/supervisor_addon.svg
[addon]: https://my.home-assistant.io/redirect/supervisor_addon/?addon=a0d7b954_ssh&repository_url=https%3A%2F%2Fgithub.com%2Fhassio-addons%2Frepository
[alpine-packages]: https://pkgs.alpinelinux.org/packages
[contributors]: https://github.com/hassio-addons/app-ssh/graphs/contributors
[discord-ha]: https://discord.gg/c5DvZ4e
[discord]: https://discord.me/hassioaddons
[forum]: https://community.home-assistant.io/t/community-hass-io-add-on-ssh-web-terminal/33820?u=frenck
[frenck]: https://github.com/frenck
[github-ssh]: https://help.github.com/articles/connecting-to-github-with-ssh/
[hass-ssh]: https://github.com/home-assistant/addons/tree/master/ssh
[issue]: https://github.com/hassio-addons/app-ssh/issues
[ohmyzsh]: http://ohmyz.sh/
[openssh]: https://www.openssh.com/
[reddit]: https://reddit.com/r/homeassistant
[releases]: https://github.com/hassio-addons/app-ssh/releases
[semver]: https://semver.org/spec/v2.0.0.html
[zsh]: https://en.wikipedia.org/wiki/Z_shell
