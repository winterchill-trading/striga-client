# striga-client

OxCaml/Async client and `striga` command line tool for the
[Striga](https://docs.striga.com) v1 API: consumers and KYC, wallets and accounts, IBAN and
crypto deposit details, swaps, intraledger, SEPA, on-chain and Lightning payments with OTP
confirmation, virtual cards, standing orders, strong customer authentication, the sandbox
simulator and webhook verification.

The client talks to the sandbox by default and refuses any other host unless it is
created with `~live:true` (`-live` on the command line).

## Quick start

```sh
cp .env.example .env          # fill in the sandbox credentials from the dashboard
set -a; . ./.env; set +a
dune build
dune exec striga -- ping
dune exec striga -- exchange rates
dune exec striga -- user create -first-name Ada -last-name Sandbox \
  -email hello+striga-demo@winterchill.xyz -mobile 56781234 -dob 1990-01-15 \
  -address "Sepapaja 6" -city Tallinn -postal-code 11415
dune exec striga -- user verify-email -user <id>      # sandbox code 123456
dune exec striga -- user verify-mobile -user <id>
dune exec striga -- user start-kyc -user <id>
dune exec striga -- sim kyc -user <id>                # approve
dune exec striga -- wallet list -user <id>
```

From OCaml:

```ocaml
let open Striga_client in
let tr = Transport.create (ok_exn (Config.of_env ())) in
let%bind user = User.get tr ~user_id in
let%bind rates = Exchange.rates tr in
...
```

Every endpoint function takes the `Transport.t` and returns `'a Or_error.t Deferred.t`.
Non-2xx answers become errors carrying an `Api_error.t`; `Api_error.status_of_error` and
`Api_error.code_of_error` recover Striga's status and `errorCode`.

## Environment

| Variable                | Required | Purpose                                                       |
| ----------------------- | -------- | ------------------------------------------------------------- |
| `STRIGA_API_KEY`        | yes      | `api-key` header; webhook signature key                       |
| `STRIGA_API_SECRET`     | yes      | HMAC request signatures                                       |
| `STRIGA_BASE_URL`       | no       | default `https://www.sandbox.striga.com/api/v1`               |
| `STRIGA_APPLICATION_ID` | no       | card PAN UI component in the browser (`Card.Pan_ui`)          |
| `STRIGA_UI_SECRET`      | no       | card PAN UI component in the browser (`Card.Pan_ui`)          |
| `STRIGA_LIVE_TESTS`     | no       | `1` lets `dune test` run the live sandbox walk                |

The library reads credentials only from the environment. `Config.t`, errors and
`Transport` event logs never print them; the CLI masks one-time tokens, TOTP secrets,
IBANs and card numbers in its JSON output unless `-reveal` is given.

## Modules

| Module           | What it covers                                                                 |
| ---------------- | ------------------------------------------------------------------------------ |
| `Config`         | environment, sandbox guard                                                     |
| `Signature`      | `HMAC <ms>:<hex>` request signatures, webhook signatures                       |
| `Transport`      | signing, retries on 429/5xx for reads, throttling, request ids, redaction     |
| `Tls`            | certificate host-name check that cohttp-async's default config skips           |
| `Redact`         | secrets, IBANs (country + last 4), card numbers (last 4), one-time tokens      |
| `User`           | create, update, get, verify email/mobile, resend codes, start KYC, KYC status, Payment Account consent, verified-email change, PII read |
| `Wallet`         | wallets, accounts, enrichment (IBAN, deposit addresses), statements            |
| `Transaction`    | ledger entries with an open `Tx_type`                                          |
| `Exchange`       | rates, swaps                                                                   |
| `Payment`        | intraledger, interledger, SEPA, on-chain (with fee estimate), Lightning in/out, OTP confirm and resend, whitelisted addresses and IBANs |
| `Card`           | virtual cards, freeze, limits, settings, 3-D Secure, PIN, statements, PAN consent, replace, physical activation |
| `Standing_order` | create, confirm, cancel, list, get, resume                                     |
| `Sca`            | TOTP enrollment, unified login, security events, trusted beneficiaries, passkeys, 2FA reset |
| `Totp`           | RFC 6238 codes (acts as the user's authenticator in tests and dev tools)       |
| `Simulator`      | sandbox KYC/KYB decisions, KYC share token, 2FA reset liveness, EUR deposits, SEPA outcomes, card status and payments, webhook ping |
| `Webhook`        | signature check and decoding by channel (`/kyc`, `/tx`, `/card/watch`, `/ping`), typed notices (`Webhook.notice`) |

## Endpoint coverage

"Live" means exercised against the sandbox (by `test/live` or the CLI) with the result
shown; "fixture" means decoded from a recorded or documented body in `test/fixtures` and
pinned by the request-shape test; "wrapped" means implemented from the reference only.
`docs/api-coverage.md` lists every endpoint found in public sources, with its evidence
and status, plus the webhook catalogue and error codes.

| Endpoint                                              | Function                              | Verified |
| ----------------------------------------------------- | ------------------------------------- | -------- |
| `POST /ping`                                          | `Transport.unit`                      | live     |
| `POST /user/create`                                   | `User.create`                         | live     |
| `PATCH /user/update`                                  | `User.update`                         | fixture  |
| `GET /user/{id}`, `POST /user/get-by-email`           | `User.get`, `User.get_by_email`       | live     |
| `POST /user/verify-email`, `/user/verify-mobile`      | `User.verify_email`, `verify_mobile`  | live     |
| `POST /user/resend-email`, `/user/resend-sms`         | `User.resend_email`, `resend_sms`     | wrapped  |
| `POST /user/kyc/start`, `GET /user/kyc/{id}`          | `User.start_kyc`, `User.kyc_status`   | live     |
| `POST /wallets/create`, `/wallets/get`, `/wallets/get/all` | `Wallet.create`, `get`, `get_all` | live     |
| `POST /wallets/get/account`                           | `Wallet.get_account`                  | live     |
| `POST /wallets/account/enrich` (EUR, BTC, ETH)        | `Wallet.enrich_account`               | live     |
| `POST /wallets/get/account/statement`                 | `Wallet.statement`                    | live     |
| `POST /wallets/account/get-transactions-by-id`        | `Wallet.transactions_by_id`           | fixture  |
| `POST /trade/rates`                                   | `Exchange.rates`                      | live     |
| `POST /wallets/swap` + confirm (EUR to USDC)          | `Exchange.swap`                       | live     |
| `POST /wallets/send/intra/initiate`                   | `Payment.intraledger`                 | live (EUR)      |
| `POST /wallets/send/inter/initiate`                   | `Payment.interledger`                 | wrapped  |
| `POST /wallets/send/initiate/bank` + confirm           | `Payment.sepa`                        | live     |
| `POST /wallets/validate-sepa-beneficiary`             | `Payment.validate_sepa_beneficiary`   | live     |
| `POST /wallets/validate-ip-region`                    | `Payment.validate_ip_region`          | live     |
| `POST /wallets/send/initiate/onchain/fee-estimate`    | `Payment.onchain_fee_estimate`        | fixture  |
| `POST /wallets/send/initiate/onchain`                 | `Payment.onchain_withdrawal`          | fixture  |
| `POST /wallets/account/lightning/topup`               | `Payment.lightning_deposit`           | live     |
| `POST /wallets/send/initiate/lightning`               | `Payment.lightning_withdrawal`        | live (see gaps) |
| `POST /wallets/transaction/confirm`                   | `Payment.confirm`                     | live     |
| `POST /wallets/transaction/resend-otp`                | `Payment.resend_otp`                  | fixture  |
| `POST /wallets/whitelist-address`, `/wallets/get/whitelisted-addresses` | `Payment.whitelist_address`, `whitelisted_addresses` | live |
| `POST /wallets/whitelist-iban`, `/wallets/get/whitelisted-ibans`, `/wallets/deactivate-iban` | `Payment.whitelist_iban`, ... | fixture |
| `POST /card/create` (virtual), `GET /card/{id}`, `POST /card/get-all` | `Card.create`, `get`, `get_all` | live |
| `POST /card/block`, `/card/unblock`, `/card/burn`     | `Card.block`, `unblock`, `burn`       | live     |
| `PATCH /card/limits`, `/card/security`                | `Card.update_limits`, `update_security` | live   |
| `PATCH /card/3ds`, `/card/set-pin`, `/card/link-account`, `POST /card/report-missing` | `Card.update_3ds`, ... | wrapped |
| `POST /card/statement`                                | `Card.statement`                      | live     |
| `POST /card/confirm-consent`, `/card/resend-consent-code` | `Card.confirm_consent`, ...       | wrapped (needs the browser plugin) |
| `POST /card/revoke-consents`                          | `Card.revoke_consents`                | live     |
| `POST /standing-orders/create`                        | `Standing_order.create`               | live (challenge) |
| `/standing-orders/confirm`, `cancel`, `get-all`, `get-by-id`, `resume`, `resend-otp`, `wallet-create` | `Standing_order.*` | wrapped |
| `POST /user/start/setup-two-factor`, `/user/resume/setup-two-factor` | `Sca.start_totp`, `complete_totp` | live |
| `POST /user/login/start`, `/user/login/complete` (totp, sms start) | `Sca.login_start`, `login_complete` | live |
| `POST /user/record-event`, trusted beneficiary endpoints, `/user/passkey/list` | `Sca.*`     | wrapped  |
| `PATCH /simulate/user/kyc`                            | `Simulator.kyc`                       | live     |
| `PATCH /simulate/accounts/deposit`                    | `Simulator.deposit`                   | live     |
| `PATCH /simulate/sepa`                                | `Simulator.sepa_outcome`              | live     |
| `POST /simulate/card/authorization`                   | `Simulator.card_authorization`        | live (approved and declined) |
| `POST /simulate/payment-accounts/state`               | `Simulator.payment_accounts_state`    | live     |
| `POST /simulate/webhook/ping`                         | `Simulator.webhook_ping`              | live     |
| `PATCH /simulate/business/kyb`, `/simulate/card/status` | `Simulator.kyb`, `card_status`      | wrapped  |
| `POST /user/payment-account/consent`, `/consent/get`   | `User.set_payment_account_consent`, `payment_account_consent` | live |
| `POST /user/2fa/reset/initiate`, `/status`, `/complete` | `Sca.reset_2fa_*`                    | live (sms) |
| `POST /simulate/auth/2fa/reset/liveness`, `/simulate/kyc/share-token` | `Simulator.reset_2fa_liveness`, `kyc_share_token` | live |
| `POST /card/replace`                                  | `Card.replace`                        | live     |
| `POST /card/activate`                                 | `Card.activate`                       | wrapped  |
| `/user/passkey/register/*`, `/user/passkey/delete*`, `/wallets/passkey/approval/start` | `Sca.*_passkey*`, `Payment.confirm_with_passkey` | wrapped (passkeys are off for the sandbox application) |
| `PATCH /user/update-verified-credentials`, `POST /user/pii` | `User.update_verified_credentials`, `User.pii` | wrapped |
| Webhooks (`/kyc`, `/kyb`, `/tx`, `/card/watch`, `/ping`) | `Webhook.verify_and_parse`, `Webhook.notice` | fixture (documented payloads) |

Business (KYB) onboarding, business wallets, corporate accounts, travel rule, card
tokenization (Apple/Google Pay) and anonymous cards are not wrapped;
`/standing-orders/update-fees` is not wrapped because its body is not published.

## Tests

- `dune test` runs the offline suite: signature vectors from the docs' Node sample, TOTP
  vectors from RFC 6238, a scripted transport (retries, Retry-After, redaction), every
  fixture decoded and round-tripped, the request path and body of every resource pinned
  against an in-memory server, webhook routing, and TLS host checks against badssl.com
  (skipped offline).
- `STRIGA_LIVE_TESTS=1 dune test` (with `.env` loaded) also runs `test/live`: two new
  sandbox users through email and mobile verification, KYC and simulated approval,
  wallets, IBAN and crypto enrichment, a simulated EUR deposit, a swap to USDC and a SEPA
  payout each confirmed with the OTP, a simulated SEPA settlement, TOTP enrollment and
  SCA login, address whitelisting, Lightning invoices, a virtual card (freeze, limits,
  settings, an approved simulated payment, statement, close), a standing order challenge,
  statements and a webhook ping. Without the variables it prints one line and passes,
  which is what CI does.

## Known gaps

- EUR and USDC accounts are listed only for a user with an SCA session. After KYC
  approval `/wallets/get/all` and `/wallets/get` return only BNB, BTC, ETH, POL and SOL;
  the EUR and USDC accounts already exist (their `createdAt` matches the crypto accounts,
  and enrich by the EUR id works) but stay unlisted, which earlier runs misread as a
  provisioning delay. After `Sca.login_start`/`login_complete` (SMS, sandbox code
  `123456`) the same wallet lists EUR and USDC at once. Without a session
  `/wallets/get/account` on the EUR account answers 403 `SCA_REQUIRED` (reason
  `NO_SESSION`); with one it answers 200. The live walk opens the session right after
  KYC approval. One EUR enrich response seen without a session had no `accountId`, so
  `Wallet.Enrichment.account_id` is optional; with a session it carried one.
- Moving crypto needs a balance and the sandbox cannot fund crypto accounts (no faucet,
  Lightning invoices are regtest), so on-chain withdrawals, crypto intraledger transfers
  and Lightning payouts are exercised only up to Striga's balance check
  (`31090`) or invoice check ("Invalid Lightning Invoice" when paying another sandbox
  user's invoice).
- Intraledger between two wallets of the same user is refused (`30030` Ruleset
  violation). EUR intraledger between two users (initiate and OTP confirm) passed in the
  live walk of 2026-10-15 once both users had an SCA session.
- Standing orders: only the creation challenge is verified; non-EUR pairs are refused
  (`64005`), and confirmation needs a funded flow.
- Card PAN display needs Striga's browser plugin (it sends the consent OTP); the server
  half (`confirm-consent`) is wrapped but not exercised.
- `PATCH /simulate/payment-accounts` changes an application setting and is not wrapped;
  third-party SEPA beneficiaries (`name`) need Payment Accounts enabled.
- `deactivate-iban` documents its fields as headers; the client sends them in the body
  like every other endpoint (unverified).

See `docs/api-notes.md` for authentication details, error codes and sandbox behaviour.
