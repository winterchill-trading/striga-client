# AGENTS.md: bin/

The `striga` command-line tool (`main.ml`). Subcommands map one to one onto the library's resources.

- Output is JSON with secrets masked. The `-reveal` flag is the only way to print them; keep it explicit.
- `-live` selects the live host. Without it the tool uses the sandbox.
- Add a subcommand only with a test that calls it against the in-memory fixtures, not the network.
