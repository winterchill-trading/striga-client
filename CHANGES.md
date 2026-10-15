# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## Unreleased

### Added

- `User.set_payment_account_consent` and `User.payment_account_consent` (Payment Account
  terms), `User.update_verified_credentials`, `User.pii`, and `?share_token` on
  `User.start_kyc`.
- `Sca`: the 2FA reset flow (`reset_2fa_initiate`, `reset_2fa_status`,
  `reset_2fa_complete`), passkey registration and two-step deletion, and
  `start_passkey_approval`; `Payment.confirm_with_passkey`.
- `Simulator.reset_2fa_liveness` and `Simulator.kyc_share_token`.
- `Card.replace` and `Card.activate`.
- `Webhook.notice`: typed `ACCOUNT_ENRICHED`, `TRANSACTION_UNDER_REVIEW`,
  `STANDING_ORDER_FAILED`, `USER_ACCOUNT_DEBT_ADDED`, `USER_ACCOUNT_ACTION_NEEDED`, KYB and
  travel-rule deliveries, next to the unchanged `Webhook.Event.t`.
- `Api_error.is_sca_session_required` (error `30070`).
- `Wallet.Banking_details`: `routing_code_entries`, `bban`, `bank_postal_code`.
- CLI: `user consent`, `sca reset-start|reset-status|reset-complete`,
  `sca passkey-register-start`, `sim liveness`, `sim share-token`, `card replace|activate`;
  `webhook verify` also prints the typed notice.
- `docs/api-coverage.md`: every endpoint found in public sources with evidence and status.

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
