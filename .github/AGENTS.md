# AGENTS.md: .github/

`workflows/ci.yml`: the `ox-setup` composite action (no extra pins, since this client has no sibling
dependencies) and `dune build` and `dune test`, plus the `obj-magic` reusable workflow.

- CI has no credentials, so the live walk does not run here; that is expected.
- Check runs with `gh run list --limit 1`; at most one `gh run watch <id> --exit-status`. No loops.
