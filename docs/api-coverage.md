# API coverage

Every endpoint of the banking API v1 found in public sources, and what striga-client does
with it. Compiled 2026-10-15.

Sources:

- **docs**: the API reference (`docs.striga.com/reference/<slug>`, slug in the table) and its
  `llms.txt` index (265 pages). There is no public changelog page.
- **Postman**: the official public collection linked from the reference's "testing with
  Postman" page.
- Public third-party code on GitHub (small example apps and proxies, none licensed). They
  were used only to look for endpoints the reference does not show, and the only ones
  found are listed as such. No official SDK exists in any language.

Status:

- **live**: exercised against the sandbox (the live walk or the CLI), result checked.
- **fixture**: decoded from a documented or recorded body and the request shape is
  pinned offline, not run against the sandbox.
- **wrapped, untested**: implemented from the reference and pinned offline, never run.
- **missing**: not wrapped yet.
- **not planned**: out of scope for a consumer neobank client (business, corporate,
  card tokenisation, travel rule) or not an API-key endpoint.

## Users and KYC

| Endpoint | Evidence (docs slug) | striga-client | Status |
| --- | --- | --- | --- |
| `POST /user/create` | create-user | `User.create` | live |
| `PATCH /user/update` | update-user | `User.update` | fixture |
| `GET /user/{userId}` | get-user-details | `User.get` | live |
| `POST /user/get-by-email` | get-user-by-email | `User.get_by_email` | live |
| `POST /user/verify-email` | verify-email-address | `User.verify_email` | live |
| `POST /user/verify-mobile` | verify-mobile-number | `User.verify_mobile` | live |
| `POST /user/resend-email` | resend-email | `User.resend_email` | wrapped, untested |
| `POST /user/resend-sms` | resend-sms | `User.resend_sms` | wrapped, untested |
| `POST /user/kyc/start` | start-kyc | `User.start_kyc` | live |
| `GET /user/kyc/{userId}` | get-kyc-status | `User.kyc_status` | live |
| `POST /user/pii` | fetch-user-pii-data | - | missing |
| `PATCH /user/update-verified-credentials` | update-verified-credentials | - | missing |
| `POST /user/payment-account/consent` | setpaymentaccountconsent | - | missing |
| `POST /user/payment-account/consent/get` | getpaymentaccountconsent | - | missing |

## Wallets and accounts

| Endpoint | Evidence (docs slug) | striga-client | Status |
| --- | --- | --- | --- |
| `POST /wallets/create` | create-wallet | `Wallet.create` | live |
| `POST /wallets/get` | get-wallet | `Wallet.get` | live |
| `POST /wallets/get/all` | get-all-wallets-for-a-user | `Wallet.get_all` | live |
| `POST /wallets/get/account` | get-account-by-id | `Wallet.get_account` | live |
| `POST /wallets/account/enrich` | enrich-account | `Wallet.enrich_account` | live |
| `POST /wallets/get/account/statement` | get-account-statement | `Wallet.statement` | live |
| `POST /wallets/account/get-transactions-by-id` | get-transactions-by-id-1 | `Wallet.transactions_by_id` | fixture |
| `POST /wallets/validate-ip-region` | validate-ip-region | `Payment.validate_ip_region` | live |

## Payments

| Endpoint | Evidence (docs slug) | striga-client | Status |
| --- | --- | --- | --- |
| `POST /wallets/send/initiate/bank` | initiate-sepa-payment | `Payment.sepa` | live |
| `POST /wallets/send/intra/initiate` | initiate-intraledger-transaction | `Payment.intraledger` | live |
| `POST /wallets/send/inter/initiate` | initiate-interledger-transaction | `Payment.interledger` | wrapped, untested |
| `POST /wallets/send/initiate/onchain` | initiate-onchain-withdrawal | `Payment.onchain_withdrawal` | fixture |
| `POST /wallets/send/initiate/onchain/fee-estimate` | get-onchain-withdrawal-fee-estimates | `Payment.onchain_fee_estimate` | fixture |
| `POST /wallets/send/initiate/lightning` | initiate-bitcoin-via-lightning | `Payment.lightning_withdrawal` | live |
| `POST /wallets/account/lightning/topup` | initiate-topup-via-lightning | `Payment.lightning_deposit` | live |
| `POST /wallets/transaction/confirm` | confirm-transaction-with-otp | `Payment.confirm` | live |
| `POST /wallets/transaction/resend-otp` | resend-otp-for-transaction | `Payment.resend_otp` | fixture |
| `POST /wallets/passkey/approval/start` | startpasskeyapproval | - | missing |
| `POST /wallets/whitelist-iban` | whitelist-destination-iban | `Payment.whitelist_iban` | fixture |
| `POST /wallets/get/whitelisted-ibans` | get-whitelisted-ibans | `Payment.whitelisted_ibans` | fixture |
| `POST /wallets/deactivate-iban` | deactivate-whitelisted-iban | `Payment.deactivate_iban` | fixture |
| `POST /wallets/validate-sepa-beneficiary` | validate-sepa-beneficiary | `Payment.validate_sepa_beneficiary` | live |
| `POST /wallets/whitelist-address` | whitelist-destination-address | `Payment.whitelist_address` | live |
| `POST /wallets/get/whitelisted-addresses` | get-whitelisted-user-destination-addresses | `Payment.whitelisted_addresses` | live |
| `POST /wallets/send/contract` | third-party proxy repo only | - | not planned |

## Trade

| Endpoint | Evidence (docs slug) | striga-client | Status |
| --- | --- | --- | --- |
| `POST /trade/rates` | exchange-rates | `Exchange.rates` | live |
| `POST /wallets/swap` | swap-currency | `Exchange.swap` | live |

## Cards

| Endpoint | Evidence (docs slug) | striga-client | Status |
| --- | --- | --- | --- |
| `POST /card/create` | create-card | `Card.create` | live |
| `GET /card/{cardId}` | get-card-api | `Card.get` | live |
| `POST /card/get-all` | get-cards-by-user | `Card.get_all` | live |
| `POST /card/block` | block-card | `Card.block` | live |
| `POST /card/unblock` | unblock-card | `Card.unblock` | live |
| `POST /card/burn` | burner-cards-close-a-virtual-card | `Card.burn` | live |
| `POST /card/report-missing` | report-card-lost | `Card.report_missing` | wrapped, untested |
| `POST /card/replace` | replace-card | - | missing |
| `POST /card/activate` | activate-card | - | missing |
| `POST /card/activate-anonymous` | activate-anonymous-card | - | not planned |
| `PATCH /card/limits` | update-card-limits | `Card.update_limits` | live |
| `PATCH /card/security` | update-card-settings | `Card.update_security` | live |
| `PATCH /card/3ds` | update-3ds-settings | `Card.update_3ds` | wrapped, untested |
| `PATCH /card/set-pin` | set-pin | `Card.set_pin` | wrapped, untested |
| `PATCH /card/link-account` | link-account | `Card.link_account` | wrapped, untested |
| `POST /card/statement` | get-card-statements | `Card.statement` | live |
| `POST /card/confirm-consent` | confirm-consent-ui | `Card.confirm_consent` | wrapped, untested |
| `POST /card/resend-consent-code` | resend-consent-code-ui | `Card.resend_consent_code` | wrapped, untested |
| `POST /card/revoke-consents` | revoke-consent-ui | `Card.revoke_consents` | live |
| `POST /card/provisioning/token, /tokens, /token/{activate,suspend,resume,deactivate}` | get-token and siblings | - | not planned |
| `POST /card/apple-pay/push-provisioning, /card/google-pay/push-provisioning` | apple-pay-push, google-pay-push | - | not planned |

## Standing orders

| Endpoint | Evidence (docs slug) | striga-client | Status |
| --- | --- | --- | --- |
| `POST /standing-orders/create` | post_create | `Standing_order.create` | live |
| `POST /standing-orders/confirm` | post_confirm | `Standing_order.confirm` | wrapped, untested |
| `POST /standing-orders/cancel` | post_cancel | `Standing_order.cancel` | wrapped, untested |
| `POST /standing-orders/get-all` | post_get-all | `Standing_order.get_all` | wrapped, untested |
| `POST /standing-orders/get-by-id` | post_get-by-id | `Standing_order.get_by_id` | wrapped, untested |
| `POST /standing-orders/resend-otp` | post_resend-otp | `Standing_order.resend_otp` | wrapped, untested |
| `POST /standing-orders/resume` | post_resume | `Standing_order.resume` | wrapped, untested |
| `POST /standing-orders/wallet-create` | post_wallet-create | `Standing_order.wallet_create` | wrapped, untested |
| `POST /standing-orders/update-fees` | post_update-fees | - | missing |

## SCA, sessions and factors

| Endpoint | Evidence (docs slug) | striga-client | Status |
| --- | --- | --- | --- |
| `POST /user/login/start` | startlogin | `Sca.login_start` | live |
| `POST /user/login/complete` | completelogin | `Sca.login_complete` | live |
| `POST /user/start/setup-two-factor` | starttotpenrollment | `Sca.start_totp` | live |
| `POST /user/resume/setup-two-factor` | completetotpenrollment | `Sca.complete_totp` | live |
| `POST /user/record-event` | recorduserevent | `Sca.record_event` | wrapped, untested |
| `POST /user/passkey/register/start` | startpasskeyenrollment | - | missing |
| `POST /user/passkey/register/complete` | completepasskeyenrollment | - | missing |
| `POST /user/passkey/list` | listpasskeys | `Sca.list_passkeys` | wrapped, untested |
| `POST /user/passkey/delete` | deletepasskey | - | missing |
| `POST /user/passkey/delete/confirm` | confirmpasskeydeletion | - | missing |
| `POST /user/2fa/reset/initiate` | initiatereset2fa | - | missing |
| `POST /user/2fa/reset/complete` | completereset2fa | - | missing |
| `POST /user/2fa/reset/status` | getreset2fastatus | - | missing |
| `POST /wallets/beneficiary/{iban,address}/trust` | initiateibantrust, initiateaddresstrust | `Sca.trust` | wrapped, untested |
| `POST /wallets/beneficiary/{iban,address}/untrust` | initiateibanuntrust, initiateaddressuntrust | `Sca.untrust` | wrapped, untested |
| `POST /wallets/beneficiary/confirm-trust` | confirmbeneficiarytrust | `Sca.confirm_trust` | wrapped, untested |
| `POST /wallets/beneficiary/confirm-untrust` | confirmbeneficiaryuntrust | `Sca.confirm_untrust` | wrapped, untested |

## Simulator (sandbox only)

| Endpoint | Evidence (docs slug) | striga-client | Status |
| --- | --- | --- | --- |
| `PATCH /simulate/user/kyc` | sandbox-simulator | `Simulator.kyc` | live |
| `POST /simulate/kyc/share-token` | sandbox-simulator | - | missing |
| `PATCH /simulate/business/kyb` | sandbox-simulator | `Simulator.kyb` | wrapped, untested |
| `POST /simulate/auth/2fa/reset/liveness` | sandbox-simulator | - | missing |
| `PATCH /simulate/accounts/deposit` | sandbox-simulator | `Simulator.deposit` | live |
| `PATCH /simulate/sepa` | sandbox-simulator | `Simulator.sepa_outcome` | live |
| `PATCH /simulate/card/status` | sandbox-simulator | `Simulator.card_status` | wrapped, untested |
| `POST /simulate/card/authorization` | sandbox-simulator | `Simulator.card_authorization` | live |
| `PATCH /simulate/payment-accounts` | sandbox-simulator | - | not planned |
| `POST /simulate/payment-accounts/state` | sandbox-simulator | `Simulator.payment_accounts_state` | live |
| `POST /simulate/webhook/ping` | sandbox-simulator | `Simulator.webhook_ping` | live |

## Application and misc

| Endpoint | Evidence (docs slug) | striga-client | Status |
| --- | --- | --- | --- |
| `POST /ping` | Postman collection | `Transport.unit` | live |
| `POST /application/login, GET /application` | Postman collection (dashboard login, not the API key) | - | not planned |
| `POST /grid/beneficiaries/list, /grid/payouts/list` | listgridbeneficiaries, listgridpayouts | - | not planned |

## Not wrapped by design

| Area | Evidence | Status |
| --- | --- | --- |
| Business (KYB) users, `/business/*` (create, update, get, verify, KYB start and members, login, TOTP, passkeys, 2FA reset, record-event, beneficiary trust, payment-account consent) | about 31 pages, `business*` slugs | not planned |
| Business wallets, `/wallets/business/*` (mirror of every consumer wallet and payment route, keyed by `businessId`) | about 22 pages | not planned |
| Business standing orders, `/standing-orders/business/*` | 9 pages | not planned |
| Corporate (application-owned) accounts, `/corporate/*` and `/wallets/corporate/*` | 9 pages, Postman collection | not planned |
| Travel rule, `/travel-rule/*` (counterparty, VASPs, wallet verification, widget sessions) | 14 pages | not planned |

## Webhooks

Deliveries go to the configured URL plus a path; `Webhook.parse` routes on it.

| Path | Event `type` values (docs) | striga-client |
| --- | --- | --- |
| `/kyc` | KYC status changes (`NOT_STARTED` ... `REJECTED_FINAL`, `SUSPENDED`, `TERMINATED`); `USER_ACCOUNT_ACTION_NEEDED` (missing tax id) | `Kyc`; others `Other` |
| `/kyb` | KYB status changes | `Other` |
| `/tx` | ledger rows by `txType`: intra/inter-ledger, SEPA payin and payout (`*_COMPLETED`, `*_FAILED`, `*_DENIED`, `*_REVERTED`), Lightning and on-chain in and out, exchange, fees, `ACCOUNT_ENRICHED`, `PENDING_ACCOUNT_ENRICHMENT` | `Transaction` |
| `/tx` | card authorizations (14 `CARD_AUTHORIZATION*` kinds) | `Card_transaction` |
| `/tx` | `TRANSACTION_UNDER_REVIEW`, `STANDING_ORDER_FAILED`, `USER_ACCOUNT_DEBT_ADDED` | `Other` |
| `/tx` | travel rule (`COUNTERPARTY_DECLARATION_REQUIRED`, `WALLET_VERIFICATION_*`, `BLOCKED_DUE_TO_TRAVEL_RULE`, ...) | `Other` |
| `/card/watch` | card status (`EXPIRED`, `CLOSED`, `DISPATCHED`), `INCOMPLETE_PROVISIONING`, `SUCCESSFUL_TRANSACTION` | `Card_status` |
| `/ping` | `TEST` | `Ping` |

## Sessions and SCA

- `POST /user/login/start` + `/user/login/complete` (SMS, TOTP or passkey) open a 180-day SCA
  session and revoke the previous one. The docs say an active session is needed to read
  EUR and USDC balances and statements older than 90 days need a fresh SCA event; their
  error for a missing session is `30070`.
- Seen in the sandbox (2026-10-15): without a session `/wallets/get` and
  `/wallets/get/all` leave the EUR and USDC accounts out and `/wallets/get/account` on EUR
  answers 403 `SCA_REQUIRED`, reason `NO_SESSION`; after an SMS login both are listed and
  the account read answers 200.
- `POST /user/record-event` with `RESET_PASSWORD_COMPLETED` revokes every session; failed
  logins lock the user for growing periods and suspend at 9.
- Debits are confirmed per operation (`/wallets/transaction/confirm`, or a passkey
  assertion from `/wallets/passkey/approval/start`); trusted beneficiaries skip dynamic
  linking for TOTP.

## Error codes (docs)

| Code | Meaning |
| --- | --- |
| `00002` | invalid fields (`errorDetails` names them) |
| `00401` | invalid API key or signature |
| `30003` | too many verification attempts |
| `30005` | user or business not found |
| `30007` | user not verified |
| `30031` | invalid code or dynamic-linking mismatch |
| `30042` | application lacks the route permission |
| `30043` | user suspended or inaccessible |
| `30046` | restricted jurisdiction |
| `30070` | SCA session required or expired |
| `30073` | whitelisted id not found or not activated |
| `30074` | `verificationMethod` sent but SCA not enabled |
| `31002` | account not active or not enriched; unsupported IBAN or BIC |
| `31004` | insufficient balance at confirm |
| `31063` / `31064` / `31065` | challenge expired / wrong code / too many attempts |
| `31097` / `31099` / `31100` | factor not enrolled / not allowed / no resend for passkey |
| `31122` to `31125` | deposit simulator: account not found, not EUR, no banking record, failed |
| `32017` | user terminated |
| `33003` | tier 2 EUR deposit threshold not met |
| `42001` to `42008` | travel rule |
| `64009` to `64011` | standing orders: beneficiary must be trusted, factor not enrolled |
| `100004` | passkey limit (5) reached |
