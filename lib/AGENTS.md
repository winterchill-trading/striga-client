# AGENTS.md: lib/

The `striga_client` library. Each module has an `.mli`; change it first and keep it documented.

- `transport.ml`: signing, retries on 429 and 5xx for reads only, throttling, request ids, redaction. All
  requests go through it.
- `signature.ml`, `webhook.ml`, `totp.ml`: request and webhook signatures, and RFC 6238 codes.
- `tls.ml`: the host-name check the HTTP library's default configuration does not perform.
- `secret.ml`, `redact.ml`, `config.ml`: credentials, redaction, and the sandbox guard for `~live`.
- `api_error.ml`, `wire.ml`, `common.ml`: error decoding and the shared wire types.
- One module per resource: `user`, `wallet`, `transaction`, `exchange`, `payment`, `card`, `standing_order`,
  `sca`, `simulator`. Each builds requests and decodes responses with `ppx_yojson_conv`.
- `striga_client.ml`: the top-level module that re-exports the public surface.

Rule: a request path or body change needs its pin in the offline suite, and a fixture for the response.
