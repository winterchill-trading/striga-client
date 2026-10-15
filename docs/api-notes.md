# Striga API notes

What we learned building `striga-client` against the v1 sandbox, from the reference at
<https://docs.striga.com> (every page is available as Markdown by appending `.md`; the
index is `https://docs.striga.com/llms.txt`) and from live calls in October 2026.

## Hosts and versions

- Sandbox: `https://www.sandbox.striga.com/api/v1`. Production URLs are handed out on
  request. Sandbox and production share request formats; only the host and the keys
  differ, so the client refuses any host but the sandbox unless `~live:true`.
- One version, `v1`, in the path. v0 signed the full path; v1 signs the path below
  `/api/v1`.
- Unknown routes answer with an Express HTML page (`Cannot GET /ping`), not JSON.
- Responses come through Cloudflare.

## Authentication

Two headers on every request:

- `api-key`: the API key.
- `Authorization: HMAC <ms>:<hex>` where `<hex>` is HMAC-SHA256 keyed with the API
  secret over `ms ^ METHOD ^ path ^ hex(MD5(body))`.
  - `ms` is the Unix time in milliseconds as a decimal string.
  - `path` is the request path without `/api/v1` (for example `/user/create`).
  - The body digest covers the JSON text; a GET signs the MD5 of `{}`
    (`99914b932bd37a50b983c5e7c90ae93b`).
- **The server re-serialises the parsed body with `JSON.stringify` before hashing**, so the
  body must be compact JSON (no spaces after `:` or `,`). A body sent as
  `{"userId": "x"}` fails with `401 30014 "HMAC's did not match"` even though its MD5 was
  computed over exactly those bytes. Yojson's `to_string` is compact and matches.
- `POST /ping` answers `pong` and is the cheapest credential check; `GET /ping` is a 404.
- The pinned test vector in `test/test_signature.ml` comes from the docs' Node sample run
  with a fixed time and a fake secret.

## Credentials in the dashboard

| Variable                | Used for                                                                 |
| ----------------------- | ------------------------------------------------------------------------ |
| `STRIGA_API_KEY`        | `api-key` header; also the HMAC key of webhook signatures                 |
| `STRIGA_API_SECRET`     | HMAC key of request signatures                                            |
| `STRIGA_APPLICATION_ID` | card PAN UI component: `StrigaUXPlugin.create(UI_SECRET, {applicationId})`; also reported as `parentApplicationId` on accounts and whitelisted IBANs |
| `STRIGA_UI_SECRET`      | card PAN UI component only (the browser iframe); never sent to the REST API |

The REST API needs only the key and the secret. The application id and UI secret belong to
the browser-side card display component; the server's part of that flow is
`POST /card/confirm-consent` (see Cards).

## Rate limits, retries and idempotency

- Responses carry `retry-after: 1` and `x-ratelimit-reset` (a date one second ahead) even
  when not throttled; the limit itself is not documented. The client honours
  `Retry-After` on 429.
- There are no idempotency keys. Striga uses `POST` for most reads
  (`/wallets/get`, `/wallets/get/account/statement`, `/card/get-all`, `/trade/rates`), so
  the client retries a POST only when the endpoint is known to be a read; every
  initiation and confirmation runs once.
- Confirmations allow 5 attempts per challenge; OTP resends are capped at 5.

## Errors

Bodies are JSON with an `errorCode` string:

- `{"message", "errorCode", "errorDetails"}` where details are a string or a list of
  `{msg, param, location}` field errors (code `00002` "Invalid fields").
- `{"status", "errorCode", "errorDetails": {"message", ...}}` (older endpoints).

Codes seen or documented: `00002` invalid fields, `30005` user does not exist, `30007` user
not verified, `30014` bad HMAC, `30030` "Ruleset violation" (intraledger between two
wallets of the same user), `30043` user suspended or inaccessible, `30046` restricted
jurisdiction, `30070` SCA session required, `31002` account not enriched, `31090` with
message `"0"` (intraledger with no balance), `31123` only EUR deposits can be simulated,
`41009`/`41010` OTP missing or invalid, `61004` insufficient balance, `640xx` standing
orders.

## Pagination and dates

- Lists take `page` (1-based) and sometimes `limit` (max 100); responses carry `count` and
  `total`. Cards use `limit`/`offset` instead.
- Date filters are Unix milliseconds. `startDate: 0` is rejected ("Invalid startDate"); a
  recent start works.

## Users and KYC

- `POST /user/create` needs first and last name, email and mobile; date of birth and
  address are needed before KYC (`missingFields`). Codes are `123456` in the sandbox and
  no email or SMS is sent. The sandbox replaces the mobile number with a random one.
- Responses return `dateOfBirth` fields as strings although they are sent as numbers.
- `POST /user/kyc/start` returns a SumSub token and a hosted `verificationLink`; both are
  short-lived credentials for the user and are masked by the client's output.
- `PATCH /simulate/user/kyc {"status":"APPROVED","tier":1}` approves at once. Crypto
  accounts (BTC, ETH, BNB, POL, SOL) are listed a few seconds later. **The EUR account is
  never listed** by `/wallets/get` or `/wallets/get/all`, although it exists and is
  `ACTIVE` (enrich by its id works); what looked like a provisioning delay was the
  account being unlisted.
- Tiers 0 to 3 each report limits in EUR cents (`inboundLimitAllowed.all = 2500000` for
  tier 1).

## Wallets and accounts

- KYC approval creates a `DEFAULT` wallet; `POST /wallets/create` adds more, each with one
  account per enabled currency, keyed by currency in an object.
- Balances are strings in the smallest unit with the unit named
  (`cents`, `satoshis`, `wei`, `lamports`). Wei amounts overflow a 63-bit int past about
  4.6 ETH; the client keeps amounts as strings.
- `POST /wallets/account/enrich` returns deposit addresses (crypto) or IBAN details (EUR);
  repeating it returns the same details. Sandbox BTC is testnet3 (`tb1...`), ETH Sepolia.
- EUR accounts are not returned by `/wallets/get/all` or `/wallets/get` in the sandbox
  (they list BNB, BTC, ETH, POL and SOL only). Given the EUR account id from elsewhere
  (webhook, portal), enrich and statement work; `/wallets/get/account` answers 403
  `SCA_REQUIRED`, reason `NO_SESSION`. The EUR enrich body has no `accountId`.
- `blockchainNetwork` is an object in account responses and a plain string in statements.

## Money movement

- Initiate, then confirm with `POST /wallets/transaction/confirm` and the user's code. The
  confirm body needs the end user's `ip`; the sandbox accepted any IP we tried
  (`/wallets/validate-ip-region` passed for a US address too).
- Intraledger moves between users of the same kind; between two wallets of one user it
  fails with `30030 Ruleset violation` (use a swap).
- Whitelisted address networks are `BTC`, `ETH`, `BSC`, `POLYGON`, `SOL`, not the long names.
- USDT operations are stopped on the sandbox.
- Lightning deposits return regtest invoices (`lnbcrt...`). Paying another sandbox user's
  invoice from a BTC account is refused as "Invalid Lightning Invoice".
- Since 1 July 2026 swaps also go through initiate/confirm (SCA).

## Strong customer authentication

- `POST /user/start/setup-two-factor` returns `secret` (20 printable characters, not
  base32), `secretBase32Encoded` and an `otpauth://` URI. Authenticator codes are RFC 6238
  (SHA-1, 30 s, 6 digits) over the base32-decoded `secretBase32Encoded`; the completion
  call takes the raw `secret` plus a code. It returns recovery codes once.
- Unified login: `login/start` with `totp` answers `{"ok":true}`; `login/complete` with a
  current code answers `{"status":"success"}` and opens a 180-day session. With `sms` the
  start returns a challenge id.
- TOTP cannot carry dynamic linking, so EUR/USDC debits to non-trusted beneficiaries need
  `sms` or `passkey`.

## Cards

- Virtual cards can link to any account (including BTC); the card is `ACTIVE` at once.
  Responses carry `maskedCardNumber` (first 6, last 4) and the misspelt `expiryData`.
- Block, unblock, limits (`PATCH /card/limits`), settings (`PATCH /card/security`) and burn
  all work on virtual cards. `limits` holds the settable limits plus `...Available` and
  `...Used` counters (49 numeric fields).
- `POST /simulate/card/authorization` decides against the linked account's balance; with
  no balance it answers `DECLINED` and the card statement shows
  `CARD_AUTHORIZATION_DECLINED` with `declineDetails: "Not Sufficient Funds"`.
- PAN, CVV and PIN display: the browser loads Striga's UI plugin with the UI secret and
  application id and calls `requestConsent({userId})` (an OTP goes to the user); the
  server calls `POST /card/confirm-consent` with the challenge id and code and passes the
  returned `cardAuthToken` (24 hours) to the plugin's `render`. `POST /card/revoke-consents`
  invalidates the tokens.

## Standing orders

- Paths are under `/standing-orders/...`. Setup and cancel return a challenge; confirm
  with `/standing-orders/confirm` (5 attempts).
- Pairs go through EUR: a BTC source with `SWAP_ONLY` into ETH is refused (`64005` "Invalid
  currency pair"); BTC into EUR is accepted.

## Simulator

`/simulate/...` exists only on the sandbox and is signed like everything else. The client
wraps KYC/KYB decisions, EUR deposits, SEPA outcomes, card status, card authorizations,
reading Payment Accounts settings and webhook pings, and refuses to call them against a
non-sandbox host. `PATCH /simulate/payment-accounts` flips an application-wide setting and
is deliberately not wrapped.

- The EUR deposit simulator is `PATCH /simulate/accounts/deposit`; it answers at once and
  the credit lands on the account asynchronously, within seconds. Poll the statement or
  the balance rather than reading it right after the call.
- Amounts are EUR cents everywhere: a portal deposit entered as "1M" arrived as
  `1000000` cents, that is 10,000.00 EUR.

## Webhooks

- Configured in the dashboard; Striga posts to the URL plus `/kyc`, `/kyb`, `/tx`,
  `/card/watch` and `/ping`, retrying up to 5 times until a 2xx.
- The `signature` header is hex HMAC-SHA256 keyed with the **API key** over
  `JSON.stringify(payload)`. Verify over the raw body; the client also tries the compact
  re-serialisation in case a proxy re-encoded the JSON.
- `/tx` carries ledger transactions (with `txType`), card authorizations (with `cardId` and
  merchant fields) and travel-rule notices on one path; tell them apart by fields.
- `POST /simulate/webhook/ping` sends a signed `TEST` delivery to the configured URL and
  answers 200 whether or not the endpoint accepted it.
