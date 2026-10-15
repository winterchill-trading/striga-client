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

### Changed

- The live walk opens an SCA session (SMS login) right after KYC approval and no longer
  waits up to three minutes for an EUR account to be listed.

### Documented

- In the sandbox, `/wallets/get/all` and `/wallets/get` leave out the EUR and USDC
  accounts until the user has an SCA session; they exist from KYC approval on. Without a
  session, `/wallets/account/enrich` and `/wallets/get/account/statement` work by the EUR
  account id while `/wallets/get/account` answers 403 `SCA_REQUIRED` with reason
  `NO_SESSION`. The earlier "EUR appears minutes after approval" note was this filter.
- `PATCH /simulate/accounts/deposit` credits asynchronously, within seconds; amounts are
  cents (a portal deposit of "1M" arrived as 1000000 cents, 10,000.00 EUR).
