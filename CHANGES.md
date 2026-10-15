# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## Unreleased

### Fixed

- `Wallet.Enrichment`: the sandbox's EUR enrich response has no `accountId`, and decoding
  failed with "record elements were undefined: account_id". `account_id` is now optional,
  and the response's `routingCodeEntries` (kept as raw JSON), `bban` and `bankPostalCode`
  are decoded. Unknown fields are still ignored.

### Documented

- In the sandbox, EUR accounts are not returned by `/wallets/get/all` or `/wallets/get`
  (they list only BNB, BTC, ETH, POL and SOL). With the EUR account id from elsewhere
  (webhook or portal), `/wallets/account/enrich` and `/wallets/get/account/statement`
  work, while `/wallets/get/account` answers 403 `SCA_REQUIRED` with reason
  `NO_SESSION`. The live walk now reports the EUR account as unlisted instead of missing.
