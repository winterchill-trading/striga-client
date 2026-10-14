# AGENTS.md: test/fixtures/

Recorded JSON responses and webhook payloads. Each file is one response, read by `test/fixture.ml`.

- Sanitise before committing: replace IBANs, names, e-mail addresses, card numbers and tokens with
  obviously fake values of the same shape.
- A new fixture gets a decode round-trip in the test that owns its resource.
- Do not edit a fixture to make a test pass; check the decoder against the documented shape first.
