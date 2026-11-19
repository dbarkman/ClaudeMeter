# ClaudeMeter

A macOS menu bar meter for your Claude plan usage. It shows how much of the current
session and the current week you have used, so you can pace a long working day without
opening Claude Code's `/usage` screen.

The menu bar item reads `51/25`: 51% of the current session used, 25% of the week used.
Its color follows the higher of the two.

## What the panel shows

Hover over the menu bar item, or click it, to open the panel.

- **Current session**: percent used, percent left, and when the session resets.
- **This week**: percent used, with a tick marking how far through the week you are, so
  you can see at a glance whether you are on pace or ahead of it.
- **Open at login** and **Quit**.

The numbers refresh every 5 minutes, and again when you open the panel. If a refresh
fails, the meter keeps the last good numbers and says what went wrong.

## Requirements

- macOS 14 or later
- Swift 6 toolchain (Xcode 16 or later)
- [Claude Code](https://claude.com/claude-code) installed and signed in with a Claude plan

## Build and install

```bash
./build.sh            # builds build/ClaudeMeter.app
./build.sh --install  # also copies it to /Applications and starts it
```

Run the tests with `swift test`.

## How it works

ClaudeMeter reads the Claude Code sign-in from your login Keychain and asks the same
usage endpoint that Claude Code's `/usage` screen uses. Your sign-in is sent only to
Anthropic, and nothing is stored outside the Keychain item Claude Code already keeps.

ClaudeMeter never renews the sign-in itself. When it is about to expire, ClaudeMeter asks
the `claude` command-line tool to renew it, because two programs renewing independently
would sign each other out.

| Part | Role |
|---|---|
| `Sources/ClaudeMeterCore` | Reading the sign-in, the usage request, parsing, and reset-time math. No UI, covered by tests. |
| `Sources/ClaudeMeter` | The menu bar item, the hover panel, and the SwiftUI views. |

## Caveats

ClaudeMeter is an unofficial tool and is not affiliated with Anthropic. The usage
endpoint is undocumented and can change or stop working without notice.

## License

MIT. See [LICENSE](LICENSE).
