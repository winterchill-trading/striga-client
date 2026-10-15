# AGENTS.md: striga-client

## Purpose

striga-client is an OxCaml/Async client and command-line tool for one banking API v1: consumers and
KYC, wallets, payments with OTP confirmation, virtual cards, standing orders, strong customer
authentication and webhook verification. It talks to the sandbox unless it is created with `~live:true`.

## Layout

| Path | Holds |
| --- | --- |
| `lib/` | The `striga-client` library: one module per resource, transport, signatures, redaction, TLS, TOTP, webhooks |
| `bin/` | The `striga` command-line tool (`main.ml`) |
| `test/` | Offline tests: signatures, TOTP vectors, transport, every fixture decoded and round-tripped |
| `test/fixtures/` | Recorded JSON responses and webhook payloads used by the offline tests |
| `test/live/` | The live sandbox walk, run only with credentials and `STRIGA_LIVE_TESTS=1` |
| `docs/` | `api-notes.md`: API behaviour the code depends on, as seen in the sandbox |
| `.github/` | `ci.yml` |
| `README.md` | Quick start, environment, modules, endpoint coverage, tests, known gaps |

## Build, test, docs

Run from the repository root, inside the workspace (`..` is the workspace root):

```sh
opam exec --switch 5.2.0+ox -- dune build --root .. @striga-client/all
opam exec --switch 5.2.0+ox -- dune build --root .. @striga-client/runtest
```

For parallel work, set `DUNE_BUILD_DIR=_build-striga-client-<task>` (resolved from the workspace
root, because of `--root ..`).

Standalone (outside the workspace): add the organisation opam repository
(`opam repo add winterchill https://github.com/winterchill-trading/opam-repository.git`),
install the dependencies with `opam install --deps-only .`, then `dune build` and `dune test`.

`dune test` runs offline. The live walk needs the credentials from README's Environment section
and `STRIGA_LIVE_TESTS=1`; without them it prints one line and passes.

## Conventions

- Format only this repository: `dune build --root .. @striga-client/fmt --auto-promote`. Never run
  `dune fmt` at the workspace root.
- Every module has an `.mli`. Use labelled arguments, `open! Core`, `ppx_jane` and `ppx_yojson_conv`.
- Credentials are read from the environment only. `Config.t`, errors and `Transport` logs never print
  them. Any new log line or error message needs a check that it carries no secret, token, IBAN or card number.
- Tokens, TOTP secrets, IBANs and card numbers are masked in the CLI's JSON output unless `-reveal` is given.
  Keep that default.
- A new resource gets its module, a fixture in `test/fixtures/`, a decode round-trip test, and a request
  path and body pin in the offline suite.
- Comments for humans: where a workaround or a library quirk drives the code (for example the host-name
  check in `Tls`, which the HTTP library's default configuration skips), say why at that place.
- Promote expect output with `dune promote` only after reading the diff.

## Dependencies and dependents

striga-client depends on `cohttp`, `cohttp-async`, `conduit-async`, `async_ssl`, `cryptokit`, `uri` and
`yojson`. Nothing in the organisation is a dependency of it. The provider adapter `../striga-provider`
depends on it; it is pinned in that repository's CI, so a signature change here reaches it.

## CI

`.github/workflows/ci.yml` runs the `ox-setup` composite action from `winterchill-trading/infra` (no
pins), then `dune build` and `dune test`, plus the `obj-magic` reusable workflow. CI has no credentials,
so the live walk is skipped there.
To check a run, use `gh run list --limit 1`, and at most one `gh run watch <id> --exit-status`.
Do not poll in a loop.

## Pitfalls

- The sandbox's `/wallets/get` and `/wallets/get/all` never list the EUR account, although it exists and
  is `ACTIVE` (enrich by id works). It is not a provisioning delay: waiting for it to appear in a wallet
  listing does not help. The live walk records a gap when it has no EUR account id.
- Some payouts cannot be exercised in the sandbox (no crypto funding, regtest invoices). The README's
  known gaps list which paths stop at a provider balance or invoice check; a test must not claim more.
- Each live run creates two sandbox users. Run it deliberately, not in a loop.
- The request signature covers the MD5 of the parsed JSON body, not the bytes sent. Send compact JSON
  (no spaces after `:` or `,`), or the check fails although the digest was taken over what went out.
- Webhook signatures are keyed with the API key, not the secret.
- Error bodies echo the application id. Add it to the redaction list.
- The `.env` file in the working tree is gitignored and may hold real values. Never print it, never
  `cat` it into a log, and never commit it; `.env.example` is the tracked template.

## Where to read more

- `README.md` (environment, modules, endpoint coverage, tests, known gaps), `docs/api-notes.md`.
- `../striga-provider/docs/mapping.md`, to see how the adapter uses this client.
- `../specs/repos/striga-client.md` for the repository summary.
- `../oxcaml-claude-skills/AGENTS.md` (workspace guide) and the skill
  `../oxcaml-claude-skills/skills/async-http-websocket/` for the HTTP and TLS side.
- `../oxcaml-claude-skills/GOTCHAS.md`, section "Fiat rails: striga-client" (the repository's gotchas).

## Never do

- Install an opam package that changes the compiler, `core`, `base`, `async` or `ppx_jane` on the
  shared `5.2.0+ox` switch. Dry-run first: `opam install --switch 5.2.0+ox --dry-run <pkg>`.
- Commit `.env`, a key, a secret, a token or a recorded response with personal data. Fixtures must be sanitised.
- Point the client at a live host from a test or a script; `~live:true` is for an explicit user action.
- Publish, tag or release.
