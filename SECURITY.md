# Security & trust

Burrow is a GUI that drives the [`mo` (Mole)](https://github.com/tw93/Mole)
CLI. It is pre-1.0 and **not yet code-signed** — this page is the honest
account of what it does, what touches the network, and how it handles
admin rights, so you can decide before you run it. The actual
cleaning/scanning is done by `mo` (MIT, © tw93); audit that too.

## Code signing

Burrow is currently **unsigned and un-notarized**. Code signing is a real
security mechanism (a cryptographic identity macOS can rely on), not a
formality — a signed/notarized build is on the roadmap. Until then:

- Install via the Homebrew cask (it strips the quarantine flag for you), or
- after copying the app, run `xattr -cr /Applications/Burrow.app`.

If you're not comfortable running an unsigned app that can ask for admin
rights, **wait for the signed release** or build it yourself from source.

## Privileged (admin) operations — no background helper

This is the part people rightly scrutinize in cleaners. Burrow's model:

- **Burrow installs no privileged/background helper and no XPC root
  service.** There is nothing persistently running as root and nothing for
  another local process to connect to.
- When **Clean** or **Optimize** needs admin rights, **macOS's own
  authorization dialog** asks for your password, and Burrow runs the
  matching `mo` command for that single action, then exits. You see and
  approve every elevation. (See `CommandRunner.runElevated` in
  `Sources/TaskReport.swift`.)
- **Honest caveat:** that elevation runs your Homebrew-installed `mo` as
  root. On a default Apple-Silicon Homebrew, `/opt/homebrew` is
  user-writable, so treat `mo` like any binary you'd `sudo` — only as
  trustworthy as your Homebrew install. If your threat model is strict,
  review `mo` and the elevation path before granting admin, or skip the
  admin-only system caches (Burrow runs fine without them).

## Network & privacy

- **No telemetry, no analytics, no crash reporting, no account, no
  sign-in, no third-party SDKs, no ads, no "upgrade to Pro."**
- Burrow has **no backend** — there is nowhere for it to phone home to, and
  it uploads nothing about you, ever.
- **Local-only surfaces:**
  - The MCP **HTTP query server** binds `127.0.0.1:9277` (loopback only;
    toggle it off in Settings). It serves your local metrics to local MCP
    clients; it is not reachable off-device.
  - The **stdio MCP server** (`Burrow --mcp`) is a local subprocess.
  - History is a local **SQLite** file under
    `~/Library/Application Support/Burrow/`.
- **The only outbound network path is opt-in:** the Software → **Updates**
  tab runs `brew outdated`, which contacts Homebrew's update feeds — the
  same check `brew` does for itself. It reads version info; it sends
  nothing about you.

## Reporting a vulnerability

Open a [GitHub issue](https://github.com/caezium/Burrow/issues) or a
private security advisory on the repo. Because Burrow can run privileged
cleanup, security reports are taken seriously — please include the file and
line if you can.
