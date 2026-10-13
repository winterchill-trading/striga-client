(lang dune 3.17)

(name striga-client)

(generate_opam_files true)

(license MIT)

(maintainers "winterchill-trading")

(authors "winterchill-trading")

(source
 (github winterchill-trading/striga-client))

(package
 (name striga-client)
 (synopsis "Async client and CLI for the Striga crypto and banking API")
 (description
  "HMAC-signed client for the Striga v1 API: users and KYC, wallets and accounts, enrichment, swaps, intraledger/interledger/SEPA/on-chain/Lightning payments with OTP confirmation, virtual cards, standing orders, strong customer authentication, sandbox simulator and webhook signature verification. Sandbox by default.")
 (depends
  (ocaml
   (>= 5.2))
  dune
  core
  core_unix
  async
  async_ssl
  cohttp
  cohttp-async
  conduit-async
  uri
  yojson
  ppx_jane
  ppx_yojson_conv
  ppx_yojson_conv_lib
  cryptokit
  base64))
