# agent-usage

`agent-usage` prints the current subscription limits for Codex, Claude Code,
and Cursor Agent. It reads credentials that the official CLIs already store on
the machine and sends read-only requests to each provider.

Run it with no arguments:

```sh
agent-usage
```

Install it with the dotfiles agent setup:

```sh
npm run install:agents
```

The CLI supports macOS and Linux. The provider usage endpoints are not public
contracts and can change. The tool never prints credentials. When Claude renews
an expired session, the tool updates the existing Claude Code credential store.

## Domain terms

- A provider gets authentication data, fetches raw usage, and parses a snapshot.
- A snapshot contains the limits for one provider.
- A limit contains a used percentage and an optional reset date-time.
- The CLI converts each used percentage to the percentage that is left.
