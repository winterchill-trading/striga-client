# AGENTS.md: test/

Offline inline tests (ppx_expect and Quickcheck). `dune test` runs them with no network and no credentials.

- `fixture.ml` loads `fixtures/*.json`. Add recorded responses there, sanitised: no real IBANs, names,
  card numbers or tokens.
- `test_transport.ml` uses a scripted transport for retries, `Retry-After` and redaction.
- `test_signature.ml` and `test_totp.ml` check against published vectors; keep the source of each vector in its comment.
- `test_tls.ml` checks the host-name check against a public test host and is skipped when offline.
- `live/` is the sandbox walk. It is built by `dune build` but only talks to the sandbox when the
  credentials and `STRIGA_LIVE_TESTS=1` are set. Do not move its side effects into the offline suite.
