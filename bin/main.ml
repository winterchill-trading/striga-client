open! Core
open! Async
open Striga_client
module P = Command.Param

(* Output: JSON (redacted: one-time tokens, IBANs and card numbers masked) unless -sexp or
   -reveal is given. *)
module Out = struct
  type t =
    { sexp : bool
    ; reveal : bool
    }

  let param =
    let%map_open.Command sexp = flag "-sexp" no_arg ~doc:" print sexps instead of JSON"
    and reveal =
      flag
        "-reveal"
        no_arg
        ~doc:" do not mask tokens, TOTP secrets and IBANs in JSON output (sandbox only)"
    in
    { sexp; reveal }
  ;;

  let print t ~to_json ~to_sexp v =
    if t.sexp
    then Core.print_s (to_sexp v)
    else (
      let json = to_json v in
      let json = if t.reveal then json else Redact.json json in
      Core.print_endline (Yojson.Safe.pretty_to_string json))
  ;;
end

let ms_ago days = Time_ns.sub (Time_ns.now ()) (Time_ns.Span.of_day (Float.of_int days))

let transport ~verbose ~live =
  let open Or_error.Let_syntax in
  let%map config = Config.of_env ~live () in
  let on_event (e : Transport.Event.t) =
    if verbose then Core.eprint_s [%sexp (e : Transport.Event.t)]
  in
  Transport.create ~on_event config
;;

(* Every subcommand: common flags, then [f tr] and print the result. *)
let cmd ~summary ?readme param ~to_json ~to_sexp =
  Command.async_or_error
    ~summary
    ?readme
    (let%map_open.Command out = Out.param
     and verbose = flag "-verbose" no_arg ~doc:" log each request to stderr"
     and live =
       flag "-live" no_arg ~doc:" allow a non-sandbox STRIGA_BASE_URL (production)"
     and f = param in
     fun () ->
       match transport ~verbose ~live with
       | Error _ as e -> return e
       | Ok tr ->
         let%map r = f tr in
         Or_error.map r ~f:(Out.print out ~to_json ~to_sexp))
;;

let unit_cmd ~summary param =
  cmd
    ~summary
    param
    ~to_json:(fun () -> `Assoc [ "ok", `Bool true ])
    ~to_sexp:(fun () -> Sexp.Atom "ok")
;;

let raw_cmd ~summary param =
  cmd ~summary param ~to_json:Fn.id ~to_sexp:Wire.Raw_json.sexp_of_t
;;

(* Flags shared by many commands. *)
let user = P.flag "-user" (P.required P.string) ~doc:"ID user id"
let account = P.flag "-account" (P.required P.string) ~doc:"ID account id"
let card = P.flag "-card" (P.required P.string) ~doc:"ID card id"
let challenge = P.flag "-challenge" (P.required P.string) ~doc:"ID challenge id"

let code =
  P.flag
    "-code"
    (P.optional_with_default "123456" P.string)
    ~doc:"CODE OTP (sandbox default 123456)"
;;

let ip =
  P.flag
    "-ip"
    (P.optional_with_default "185.46.212.10" P.string)
    ~doc:"IP end user's IP (default: an Estonian address)"
;;

let amount = P.flag "-amount" (P.required P.string) ~doc:"N amount in the smallest unit"
let memo = P.flag "-memo" (P.optional P.string) ~doc:"TEXT memo"

let days =
  P.flag "-days" (P.optional_with_default 30 P.int) ~doc:"N look back N days (default 30)"
;;

let page = P.flag "-page" (P.optional P.int) ~doc:"N page (default 1)"

let method_ =
  P.flag
    "-method"
    (P.optional (P.Arg_type.create Common.Verification_method.of_string))
    ~doc:"sms|totp|passkey second factor"
;;

let now_plus_minute () = Time_ns.add (Time_ns.now ()) Time_ns.Span.minute

module User_cmd = struct
  let user_out = User.yojson_of_t, User.sexp_of_t

  let create =
    let to_json, to_sexp = user_out in
    cmd
      ~summary:"create a consumer (sends email and SMS codes)"
      (let%map_open.Command first_name = flag "-first-name" (required string) ~doc:"NAME"
       and last_name = flag "-last-name" (required string) ~doc:"NAME"
       and email = flag "-email" (required string) ~doc:"EMAIL"
       and country_code =
         flag
           "-country-code"
           (optional_with_default "+372" string)
           ~doc:"+CC (default +372)"
       and number = flag "-mobile" (required string) ~doc:"NUMBER without country code"
       and dob =
         flag
           "-dob"
           (optional (Arg_type.create Date.of_string))
           ~doc:"YYYY-MM-DD date of birth"
       and line1 = flag "-address" (optional string) ~doc:"LINE address line 1"
       and city = flag "-city" (optional string) ~doc:"CITY"
       and postal_code = flag "-postal-code" (optional string) ~doc:"CODE"
       and country =
         flag "-country" (optional_with_default "EE" string) ~doc:"CC (default EE)"
       in
       fun tr ->
         let date_of_birth =
           Option.map dob ~f:(fun d ->
             Common.Date_of_birth.create
               ~year:(Date.year d)
               ~month:(Month.to_int (Date.month d))
               ~day:(Date.day d))
         in
         let address =
           match line1, city, postal_code with
           | Some address_line1, Some city, Some postal_code ->
             Some
               { Common.Address.address_line1
               ; address_line2 = None
               ; city
               ; postal_code
               ; state = None
               ; country
               }
           | _ -> None
         in
         User.create
           tr
           ~first_name
           ~last_name
           ~email
           ~mobile:{ country_code; number }
           ?date_of_birth
           ?address
           ())
      ~to_json
      ~to_sexp
  ;;

  let get =
    let to_json, to_sexp = user_out in
    cmd
      ~summary:"get a user by id or email"
      (let%map_open.Command user_id = flag "-user" (optional string) ~doc:"ID user id"
       and email = flag "-email" (optional string) ~doc:"EMAIL" in
       fun tr ->
         match user_id, email with
         | Some user_id, None -> User.get tr ~user_id
         | None, Some email -> User.get_by_email tr ~email
         | _ -> return (Or_error.error_string "pass exactly one of -user and -email"))
      ~to_json
      ~to_sexp
  ;;

  let verify which =
    unit_cmd
      ~summary:(sprintf "verify the user's %s with the code" which)
      (let%map.Command user_id = user
       and code in
       fun tr ->
         if String.equal which "email"
         then User.verify_email tr ~user_id ~code
         else User.verify_mobile tr ~user_id ~code)
  ;;

  let resend which =
    unit_cmd
      ~summary:(sprintf "resend the %s verification code" which)
      (let%map.Command user_id = user in
       fun tr ->
         if String.equal which "email"
         then User.resend_email tr ~user_id
         else User.resend_sms tr ~user_id)
  ;;

  let start_kyc =
    cmd
      ~summary:"start KYC; prints the SumSub SDK token (masked unless -reveal)"
      (let%map.Command user_id = user
       and tier = P.flag "-tier" (P.optional P.int) ~doc:"1|2 KYC tier" in
       fun tr -> User.start_kyc tr ~user_id ?tier ())
      ~to_json:User.Kyc_start.yojson_of_t
      ~to_sexp:User.Kyc_start.sexp_of_t
  ;;

  let kyc_status =
    cmd
      ~summary:"KYC status and tiers"
      (let%map.Command user_id = user in
       fun tr -> User.kyc_status tr ~user_id)
      ~to_json:User.Kyc.yojson_of_t
      ~to_sexp:User.Kyc.sexp_of_t
  ;;

  let consent =
    cmd
      ~summary:"record or withdraw the Payment Account consent, or read it with -get"
      (let%map_open.Command user_id = user
       and get = flag "-get" no_arg ~doc:" read the stored consent instead"
       and withdraw = flag "-withdraw" no_arg ~doc:" record accepted=false"
       and terms_version = flag "-terms-version" (optional string) ~doc:"V terms version"
       and terms_uri = flag "-terms-uri" (optional string) ~doc:"URI terms document"
       and ip = flag "-ip" (optional string) ~doc:"IP end user's IP" in
       fun tr ->
         if get
         then User.payment_account_consent tr ~user_id
         else
           User.set_payment_account_consent
             tr
             ~user_id
             ~accepted:(not withdraw)
             ?terms_version
             ?terms_uri
             ?ip
             ())
      ~to_json:User.Payment_account_consent.Record.yojson_of_t
      ~to_sexp:User.Payment_account_consent.Record.sexp_of_t
  ;;

  let command =
    Command.group
      ~summary:"consumers and KYC"
      [ "create", create
      ; "get", get
      ; "verify-email", verify "email"
      ; "verify-mobile", verify "mobile"
      ; "resend-email", resend "email"
      ; "resend-sms", resend "sms"
      ; "start-kyc", start_kyc
      ; "kyc-status", kyc_status
      ; "consent", consent
      ]
  ;;
end

module Wallet_cmd = struct
  let wallet_cmd ~summary param =
    cmd ~summary param ~to_json:Wallet.yojson_of_t ~to_sexp:Wallet.sexp_of_t
  ;;

  let create =
    wallet_cmd
      ~summary:"create another wallet"
      (let%map.Command user_id = user in
       fun tr -> Wallet.create tr ~user_id)
  ;;

  let get =
    wallet_cmd
      ~summary:"get one wallet"
      (let%map.Command user_id = user
       and wallet_id = P.flag "-wallet" (P.required P.string) ~doc:"ID wallet id" in
       fun tr -> Wallet.get tr ~user_id ~wallet_id)
  ;;

  let list =
    cmd
      ~summary:"wallets created in the last -days"
      (let%map.Command user_id = user
       and days
       and page in
       fun tr ->
         Wallet.get_all
           tr
           ~user_id
           ~start:(ms_ago days)
           ~stop:(now_plus_minute ())
           ?page
           ())
      ~to_json:Wallet.Page.yojson_of_t
      ~to_sexp:Wallet.Page.sexp_of_t
  ;;

  let account_ =
    cmd
      ~summary:"get one account with its balance"
      (let%map.Command user_id = user
       and account_id = account in
       fun tr -> Wallet.get_account tr ~user_id ~account_id)
      ~to_json:Wallet.Account.yojson_of_t
      ~to_sexp:Wallet.Account.sexp_of_t
  ;;

  let enrich =
    cmd
      ~summary:"get deposit details (IBAN or address) for an account"
      (let%map.Command user_id = user
       and account_id = account in
       fun tr -> Wallet.enrich_account tr ~user_id ~account_id)
      ~to_json:Wallet.Enrichment.yojson_of_t
      ~to_sexp:Wallet.Enrichment.sexp_of_t
  ;;

  let page_out = Transaction.Page.yojson_of_t, Transaction.Page.sexp_of_t

  let statement =
    let to_json, to_sexp = page_out in
    cmd
      ~summary:"account statement for the last -days"
      (let%map.Command user_id = user
       and account_id = account
       and days
       and page
       and limit = P.flag "-limit" (P.optional P.int) ~doc:"N page size" in
       fun tr ->
         Wallet.statement
           tr
           ~user_id
           ~account_id
           ~start:(ms_ago days)
           ~stop:(now_plus_minute ())
           ?page
           ?limit
           ())
      ~to_json
      ~to_sexp
  ;;

  let tx =
    let to_json, to_sexp = page_out in
    cmd
      ~summary:"ledger entries of one transaction"
      (let%map.Command user_id = user
       and account_id = account
       and tx_id = P.flag "-tx" (P.required P.string) ~doc:"ID transaction id" in
       fun tr -> Wallet.transactions_by_id tr ~user_id ~account_id ~tx_id)
      ~to_json
      ~to_sexp
  ;;

  let command =
    Command.group
      ~summary:"wallets, accounts and statements"
      [ "create", create
      ; "get", get
      ; "list", list
      ; "account", account_
      ; "enrich", enrich
      ; "statement", statement
      ; "tx", tx
      ]
  ;;
end

module Pay_cmd = struct
  let initiated ~summary param =
    cmd
      ~summary
      param
      ~to_json:Payment.Initiated.yojson_of_t
      ~to_sexp:Payment.Initiated.sexp_of_t
  ;;

  let ledger which =
    initiated
      ~summary:(sprintf "initiate an %s transfer (then: confirm)" which)
      (let%map.Command user_id = user
       and source_account_id =
         P.flag "-from" (P.required P.string) ~doc:"ID source account"
       and destination_account_id =
         P.flag "-to" (P.required P.string) ~doc:"ID destination account"
       and amount
       and memo
       and verification_method = method_ in
       fun tr ->
         (if String.equal which "intraledger"
          then Payment.intraledger
          else Payment.interledger)
           tr
           ~user_id
           ~source_account_id
           ~destination_account_id
           ~amount
           ?memo
           ?verification_method
           ())
  ;;

  let sepa =
    initiated
      ~summary:"initiate a SEPA payout from an enriched EUR account"
      (let%map.Command user_id = user
       and source_account_id = P.flag "-from" (P.required P.string) ~doc:"ID EUR account"
       and amount
       and iban = P.flag "-iban" (P.required P.string) ~doc:"IBAN destination"
       and bic = P.flag "-bic" (P.required P.string) ~doc:"BIC destination"
       and memo
       and name = P.flag "-name" (P.optional P.string) ~doc:"NAME third-party beneficiary"
       and verification_method = method_ in
       fun tr ->
         Payment.sepa
           tr
           ~user_id
           ~source_account_id
           ~amount
           ~iban
           ~bic
           ?memo
           ?name
           ?verification_method
           ())
  ;;

  let address =
    P.flag "-address-id" (P.required P.string) ~doc:"ID whitelisted address id"
  ;;

  let onchain_fee =
    cmd
      ~summary:"fee estimate for an on-chain withdrawal"
      (let%map.Command user_id = user
       and source_account_id = P.flag "-from" (P.required P.string) ~doc:"ID account"
       and whitelisted_address_id = address
       and amount in
       fun tr ->
         Payment.onchain_fee_estimate
           tr
           ~user_id
           ~source_account_id
           ~whitelisted_address_id
           ~amount)
      ~to_json:Common.Fee_estimate.yojson_of_t
      ~to_sexp:Common.Fee_estimate.sexp_of_t
  ;;

  let onchain =
    initiated
      ~summary:"initiate an on-chain withdrawal to a whitelisted address"
      (let%map.Command user_id = user
       and source_account_id = P.flag "-from" (P.required P.string) ~doc:"ID account"
       and whitelisted_address_id = address
       and amount
       and verification_method = method_ in
       fun tr ->
         Payment.onchain_withdrawal
           tr
           ~user_id
           ~source_account_id
           ~whitelisted_address_id
           ~amount
           ?verification_method
           ())
  ;;

  let ln_withdraw =
    initiated
      ~summary:"pay a Lightning invoice from a BTC account"
      (let%map.Command user_id = user
       and source_account_id = P.flag "-from" (P.required P.string) ~doc:"ID BTC account"
       and invoice = P.flag "-invoice" (P.required P.string) ~doc:"BOLT11 invoice"
       and verification_method = method_ in
       fun tr ->
         Payment.lightning_withdrawal
           tr
           ~user_id
           ~source_account_id
           ~invoice
           ?verification_method
           ())
  ;;

  let ln_deposit =
    cmd
      ~summary:"create a Lightning invoice that credits a BTC account"
      (let%map.Command user_id = user
       and account_id = account
       and amount_sats = P.flag "-sats" (P.required P.string) ~doc:"N satoshis"
       and memo
       and ttl_minutes = P.flag "-ttl" (P.optional P.int) ~doc:"MIN expiry (10-1440)" in
       fun tr ->
         Payment.lightning_deposit
           tr
           ~user_id
           ~account_id
           ~amount_sats
           ?memo
           ?ttl_minutes
           ())
      ~to_json:Payment.Lightning_invoice.yojson_of_t
      ~to_sexp:Payment.Lightning_invoice.sexp_of_t
  ;;

  let confirm =
    cmd
      ~summary:"confirm an initiated transfer or swap with the OTP"
      (let%map.Command user_id = user
       and challenge_id = challenge
       and code
       and ip
       and verification_method = method_ in
       fun tr ->
         Payment.confirm tr ~user_id ~challenge_id ~code ~ip ?verification_method ())
      ~to_json:Transaction.yojson_of_t
      ~to_sexp:Transaction.sexp_of_t
  ;;

  let resend_otp =
    cmd
      ~summary:"resend the OTP of a challenge"
      (let%map.Command user_id = user
       and challenge_id = challenge in
       fun tr -> Payment.resend_otp tr ~user_id ~challenge_id)
      ~to_json:Common.Challenge.yojson_of_t
      ~to_sexp:Common.Challenge.sexp_of_t
  ;;

  let whitelist_address =
    cmd
      ~summary:"whitelist a crypto destination address"
      (let%map.Command user_id = user
       and address = P.flag "-address" (P.required P.string) ~doc:"ADDR destination"
       and currency = P.flag "-currency" (P.required P.string) ~doc:"CCY e.g. ETH"
       and network =
         P.flag "-network" (P.required P.string) ~doc:"NET BTC, ETH, BSC, POLYGON or SOL"
       and label = P.flag "-label" (P.optional P.string) ~doc:"TEXT unique label" in
       fun tr ->
         Payment.whitelist_address tr ~user_id ~address ~currency ~network ?label ())
      ~to_json:Payment.Whitelisted_address.yojson_of_t
      ~to_sexp:Payment.Whitelisted_address.sexp_of_t
  ;;

  let addresses =
    cmd
      ~summary:"list whitelisted addresses"
      (let%map.Command user_id = user
       and currency = P.flag "-currency" (P.optional P.string) ~doc:"CCY filter"
       and page in
       fun tr -> Payment.whitelisted_addresses tr ~user_id ?currency ?page ())
      ~to_json:Payment.Address_page.yojson_of_t
      ~to_sexp:Payment.Address_page.sexp_of_t
  ;;

  let iban = P.flag "-iban" (P.required P.string) ~doc:"IBAN"
  let bic = P.flag "-bic" (P.required P.string) ~doc:"BIC"

  let whitelist_iban =
    cmd
      ~summary:"whitelist a destination IBAN"
      (let%map.Command user_id = user
       and iban
       and bic
       and label = P.flag "-label" (P.optional P.string) ~doc:"TEXT unique label"
       and name =
         P.flag "-name" (P.optional P.string) ~doc:"NAME third-party beneficiary"
       in
       fun tr -> Payment.whitelist_iban tr ~user_id ~iban ~bic ?label ?name ())
      ~to_json:Payment.Whitelisted_iban.yojson_of_t
      ~to_sexp:Payment.Whitelisted_iban.sexp_of_t
  ;;

  let ibans =
    cmd
      ~summary:"list whitelisted IBANs"
      (let%map.Command user_id = user
       and page in
       fun tr -> Payment.whitelisted_ibans tr ~user_id ?page ())
      ~to_json:Payment.Iban_page.yojson_of_t
      ~to_sexp:Payment.Iban_page.sexp_of_t
  ;;

  let deactivate_iban =
    cmd
      ~summary:"deactivate a whitelisted IBAN"
      (let%map.Command user_id = user
       and iban in
       fun tr -> Payment.deactivate_iban tr ~user_id ~iban)
      ~to_json:Payment.Whitelisted_iban.yojson_of_t
      ~to_sexp:Payment.Whitelisted_iban.sexp_of_t
  ;;

  let validate_sepa =
    cmd
      ~summary:"check which SEPA schemes reach an IBAN"
      (let%map.Command user_id = user
       and source_account_id = P.flag "-from" (P.required P.string) ~doc:"ID EUR account"
       and iban
       and bic in
       fun tr ->
         Payment.validate_sepa_beneficiary tr ~user_id ~source_account_id ~iban ~bic)
      ~to_json:(fun l -> `List (List.map l ~f:Payment.Sepa_validation.yojson_of_t))
      ~to_sexp:[%sexp_of: Payment.Sepa_validation.t list]
  ;;

  let validate_ip =
    unit_cmd
      ~summary:"check that an IP is outside restricted jurisdictions"
      (let%map.Command user_id = user
       and ip in
       fun tr -> Payment.validate_ip_region tr ~user_id ~ip)
  ;;

  let command =
    Command.group
      ~summary:"money movement and OTP confirmation"
      [ "intraledger", ledger "intraledger"
      ; "interledger", ledger "interledger"
      ; "sepa", sepa
      ; "onchain-fee", onchain_fee
      ; "onchain", onchain
      ; "ln-withdraw", ln_withdraw
      ; "ln-deposit", ln_deposit
      ; "confirm", confirm
      ; "resend-otp", resend_otp
      ; "whitelist-address", whitelist_address
      ; "addresses", addresses
      ; "whitelist-iban", whitelist_iban
      ; "ibans", ibans
      ; "deactivate-iban", deactivate_iban
      ; "validate-sepa", validate_sepa
      ; "validate-ip", validate_ip
      ]
  ;;
end

module Exchange_cmd = struct
  let rates =
    cmd
      ~summary:"current exchange rates"
      (P.return (fun tr -> Exchange.rates tr))
      ~to_json:Exchange.Rates.yojson_of_t
      ~to_sexp:Exchange.Rates.sexp_of_t
  ;;

  let swap =
    cmd
      ~summary:"initiate a swap between two accounts of a user (then: pay confirm)"
      (let%map.Command user_id = user
       and source_account_id =
         P.flag "-from" (P.required P.string) ~doc:"ID source account"
       and destination_account_id =
         P.flag "-to" (P.required P.string) ~doc:"ID destination account"
       and amount
       and ip
       and memo
       and verification_method = method_ in
       fun tr ->
         Exchange.swap
           tr
           ~user_id
           ~source_account_id
           ~destination_account_id
           ~amount
           ~ip
           ?memo
           ?verification_method
           ())
      ~to_json:Payment.Initiated.yojson_of_t
      ~to_sexp:Payment.Initiated.sexp_of_t
  ;;

  let command = Command.group ~summary:"rates and swaps" [ "rates", rates; "swap", swap ]
end

module Card_cmd = struct
  let card_cmd ~summary param =
    cmd ~summary param ~to_json:Card.yojson_of_t ~to_sexp:Card.sexp_of_t
  ;;

  let create =
    card_cmd
      ~summary:"create a virtual card"
      (let%map.Command user_id = user
       and name_on_card = P.flag "-name" (P.required P.string) ~doc:"NAME name on card"
       and three_d_secure_password =
         P.flag "-3ds-password" (P.required P.string) ~doc:"PASS 8-36 characters"
       and account_id_to_link =
         P.flag "-account" (P.optional P.string) ~doc:"ID account to link"
       in
       fun tr ->
         Card.create
           tr
           ~user_id
           ~name_on_card
           ~three_d_secure_password
           ~type_:Virtual
           ?account_id_to_link
           ())
  ;;

  let get =
    card_cmd
      ~summary:"get a card"
      (let%map.Command card_id = card in
       fun tr -> Card.get tr ~card_id)
  ;;

  let list =
    cmd
      ~summary:"cards of a user"
      (let%map.Command user_id = user in
       fun tr -> Card.get_all tr ~user_id ())
      ~to_json:Card.Page.yojson_of_t
      ~to_sexp:Card.Page.sexp_of_t
  ;;

  let simple ~summary f =
    unit_cmd
      ~summary
      (let%map.Command card_id = card in
       fun tr -> f tr ~card_id)
  ;;

  let limits =
    card_cmd
      ~summary:"set limits, e.g. -set dailyPurchase=500 -set monthlyWithdrawal=1000"
      (let%map.Command card_id = card
       and limits =
         P.flag
           "-set"
           (P.listed
              (P.Arg_type.create (fun s ->
                 match String.lsplit2 s ~on:'=' with
                 | Some (k, v) -> k, Int.of_string v
                 | None -> failwith "expected NAME=EUR")))
           ~doc:"NAME=EUR limit to set"
       in
       fun tr -> Card.update_limits tr ~card_id ~limits)
  ;;

  let security =
    card_cmd
      ~summary:"turn contactless, ATM and online payments on or off"
      (let%map.Command card_id = card
       and contactless = P.flag "-contactless" (P.required P.bool) ~doc:"BOOL"
       and withdrawal = P.flag "-atm" (P.required P.bool) ~doc:"BOOL"
       and internet_purchase = P.flag "-online" (P.required P.bool) ~doc:"BOOL" in
       fun tr ->
         Card.update_security tr ~card_id ~contactless ~withdrawal ~internet_purchase)
  ;;

  let set_pin =
    unit_cmd
      ~summary:"set the PIN of an active physical card"
      (let%map.Command card_id = card
       and pin = P.flag "-pin" (P.required P.string) ~doc:"PIN 4 digits" in
       fun tr -> Card.set_pin tr ~card_id ~pin)
  ;;

  let three_ds =
    unit_cmd
      ~summary:"change the 3-D Secure password"
      (let%map.Command card_id = card
       and three_d_secure_password =
         P.flag "-password" (P.required P.string) ~doc:"PASS"
       in
       fun tr -> Card.update_3ds tr ~card_id ~three_d_secure_password)
  ;;

  let link =
    raw_cmd
      ~summary:"link the card to another account"
      (let%map.Command card_id = card
       and account_id = account in
       fun tr -> Card.link_account tr ~card_id ~account_id)
  ;;

  let statement =
    cmd
      ~summary:"card transactions for the last -days"
      (let%map.Command card_id = card
       and days
       and page in
       fun tr ->
         Card.statement
           tr
           ~card_id
           ~start:(ms_ago days)
           ~stop:(now_plus_minute ())
           ?page
           ())
      ~to_json:Card.Card_transaction.Page.yojson_of_t
      ~to_sexp:Card.Card_transaction.Page.sexp_of_t
  ;;

  let confirm_consent =
    cmd
      ~summary:"exchange a PAN consent OTP for a card auth token (masked unless -reveal)"
      (let%map.Command user_id = user
       and challenge_id = challenge
       and code in
       fun tr -> Card.confirm_consent tr ~user_id ~challenge_id ~code)
      ~to_json:Card.Consent.yojson_of_t
      ~to_sexp:Card.Consent.sexp_of_t
  ;;

  let revoke_consents =
    unit_cmd
      ~summary:"invalidate every card auth token of a user"
      (let%map.Command user_id = user in
       fun tr -> Card.revoke_consents tr ~user_id)
  ;;

  let command =
    Command.group
      ~summary:"cards"
      [ "create", create
      ; "get", get
      ; "list", list
      ; "block", simple ~summary:"freeze a card" Card.block
      ; "unblock", simple ~summary:"unfreeze a card" Card.unblock
      ; ( "burn"
        , card_cmd
            ~summary:"close a virtual card for good"
            (let%map.Command card_id = card in
             fun tr -> Card.burn tr ~card_id) )
      ; "limits", limits
      ; "security", security
      ; "set-pin", set_pin
      ; "3ds", three_ds
      ; "link", link
      ; "statement", statement
      ; "confirm-consent", confirm_consent
      ; "revoke-consents", revoke_consents
      ]
  ;;
end

module So_cmd = struct
  let challenge_out = Common.Challenge.yojson_of_t, Common.Challenge.sexp_of_t
  let so_id = P.flag "-order" (P.required P.string) ~doc:"ID standing order id"

  let create =
    let to_json, to_sexp = challenge_out in
    cmd
      ~summary:"create a standing order (then: so confirm)"
      (let%map.Command user_id = user
       and account_id = account
       and whitelisted_address_id =
         P.flag "-address-id" (P.optional P.string) ~doc:"ID payout address"
       and whitelisted_iban_id =
         P.flag "-iban-id" (P.optional P.string) ~doc:"ID payout IBAN"
       and swap_only =
         P.flag "-swap-only" P.no_arg ~doc:" convert in the wallet, no payout"
       and destination_currency =
         P.flag "-to-currency" (P.optional P.string) ~doc:"CCY for -swap-only"
       and verification_method = method_ in
       fun tr ->
         Standing_order.create
           tr
           ~user_id
           ~account_id
           ?whitelisted_address_id
           ?whitelisted_iban_id
           ?action:(Option.some_if swap_only Standing_order.Action.Swap_only)
           ?destination_currency
           ?verification_method
           ())
      ~to_json
      ~to_sexp
  ;;

  let confirm =
    cmd
      ~summary:"confirm a standing order create or cancel with the OTP"
      (let%map.Command user_id = user
       and challenge_id = challenge
       and code
       and ip
       and verification_method = method_ in
       fun tr ->
         Standing_order.confirm
           tr
           ~user_id
           ~challenge_id
           ~code
           ~ip
           ?verification_method
           ())
      ~to_json:Standing_order.Confirmed.yojson_of_t
      ~to_sexp:Standing_order.Confirmed.sexp_of_t
  ;;

  let cancel =
    let to_json, to_sexp = challenge_out in
    cmd
      ~summary:"cancel a standing order (then: so confirm)"
      (let%map.Command user_id = user
       and standing_order_id = so_id in
       fun tr -> Standing_order.cancel tr ~user_id ~standing_order_id ())
      ~to_json
      ~to_sexp
  ;;

  let list =
    cmd
      ~summary:"standing orders created in the last -days"
      (let%map.Command user_id = user
       and days in
       fun tr ->
         Standing_order.get_all
           tr
           ~user_id
           ~start:(ms_ago days)
           ~stop:(now_plus_minute ())
           ())
      ~to_json:Standing_order.Page.yojson_of_t
      ~to_sexp:Standing_order.Page.sexp_of_t
  ;;

  let get =
    cmd
      ~summary:"one standing order"
      (let%map.Command user_id = user
       and standing_order_id = so_id in
       fun tr -> Standing_order.get_by_id tr ~user_id ~standing_order_id)
      ~to_json:Standing_order.yojson_of_t
      ~to_sexp:Standing_order.sexp_of_t
  ;;

  let command =
    Command.group
      ~summary:"standing orders"
      [ "create", create; "confirm", confirm; "cancel", cancel; "list", list; "get", get ]
  ;;
end

module Sca_cmd = struct
  let totp_start =
    cmd
      ~summary:"start TOTP enrollment; prints the secret only with -reveal"
      (let%map.Command user_id = user in
       fun tr -> Sca.start_totp tr ~user_id)
      ~to_json:Sca.Totp_enrollment.yojson_of_t
      ~to_sexp:Sca.Totp_enrollment.sexp_of_t
  ;;

  let totp_complete =
    cmd
      ~summary:"finish TOTP enrollment with the raw secret and a code from -base32"
      (let%map.Command user_id = user
       and secret = P.flag "-secret" (P.required P.string) ~doc:"SECRET from totp-start"
       and base32 =
         P.flag "-base32" (P.required P.string) ~doc:"B32 secretBase32Encoded"
       in
       fun tr ->
         match Totp.code_of_base32 base32 (Time_ns.now ()) with
         | Error _ as e -> return e
         | Ok code -> Sca.complete_totp tr ~user_id ~secret ~code)
      ~to_json:Sca.Recovery_codes.yojson_of_t
      ~to_sexp:Sca.Recovery_codes.sexp_of_t
  ;;

  let totp_code =
    Command.basic
      ~summary:
        "print the current TOTP code for a base32 secret (acts as an authenticator)"
      (let%map.Command base32 = P.anon (P.( %: ) "BASE32-SECRET" P.string) in
       fun () ->
         match Totp.code_of_base32 base32 (Time_ns.now ()) with
         | Ok code -> Core.print_endline code
         | Error e ->
           Core.eprint_s [%sexp (e : Error.t)];
           Stdlib.exit 1)
  ;;

  let login_start =
    cmd
      ~summary:"start the unified SCA login"
      (let%map.Command user_id = user
       and verification_method =
         P.flag
           "-method"
           (P.required (P.Arg_type.create Common.Verification_method.of_string))
           ~doc:"sms|totp|passkey"
       in
       fun tr -> Sca.login_start tr ~user_id ~verification_method)
      ~to_json:Sca.Login_challenge.yojson_of_t
      ~to_sexp:Sca.Login_challenge.sexp_of_t
  ;;

  let login_complete =
    raw_cmd
      ~summary:"complete the SCA login (opens a 180-day session)"
      (let%map.Command user_id = user
       and verification_method =
         P.flag
           "-method"
           (P.required (P.Arg_type.create Common.Verification_method.of_string))
           ~doc:"sms|totp"
       and ip
       and challenge_id = P.flag "-challenge" (P.optional P.string) ~doc:"ID for sms"
       and code in
       fun tr ->
         Sca.login_complete tr ~user_id ~verification_method ~ip ?challenge_id ~code ())
  ;;

  let record_event =
    raw_cmd
      ~summary:"report a failed login or a completed password reset"
      (let%map.Command user_id = user
       and failed = P.flag "-failed-login" P.no_arg ~doc:" a failed login attempt"
       and reset = P.flag "-password-reset" P.no_arg ~doc:" a completed password reset" in
       fun tr ->
         match failed, reset with
         | true, false -> Sca.record_event tr ~user_id ~event:Failed_login_attempt
         | false, true -> Sca.record_event tr ~user_id ~event:Reset_password_completed
         | _ ->
           return (Or_error.error_string "pass one of -failed-login, -password-reset"))
  ;;

  let beneficiary =
    let%map.Command iban =
      P.flag "-iban-id" (P.optional P.string) ~doc:"ID whitelisted IBAN"
    and address =
      P.flag "-address-id" (P.optional P.string) ~doc:"ID whitelisted USDC address"
    in
    match iban, address with
    | Some id, None -> Ok (`Iban id)
    | None, Some id -> Ok (`Address id)
    | _ -> Or_error.error_string "pass one of -iban-id, -address-id"
  ;;

  let trust which =
    raw_cmd
      ~summary:(sprintf "start %s a beneficiary" which)
      (let%map.Command user_id = user
       and b = beneficiary
       and verification_method = method_ in
       fun tr ->
         match b with
         | Error _ as e -> return e
         | Ok b ->
           (if String.equal which "trusting" then Sca.trust else Sca.untrust)
             tr
             ~user_id
             b
             ?verification_method
             ())
  ;;

  let confirm_trust which =
    raw_cmd
      ~summary:(sprintf "confirm %s a beneficiary" which)
      (let%map.Command user_id = user
       and b = beneficiary
       and verification_method = method_
       and challenge_id = P.flag "-challenge" (P.optional P.string) ~doc:"ID for sms"
       and code in
       fun tr ->
         match b with
         | Error _ as e -> return e
         | Ok b ->
           (if String.equal which "trusting"
            then Sca.confirm_trust
            else Sca.confirm_untrust)
             tr
             ~user_id
             b
             ?verification_method
             ?challenge_id
             ~code
             ())
  ;;

  let reset_id = P.flag "-reset" (P.required P.string) ~doc:"ID reset id"

  let reset_start =
    cmd
      ~summary:
        "start a 2FA reset (prints the identity-check token, masked unless -reveal)"
      (let%map.Command user_id = user
       and factor =
         P.flag
           "-factor"
           (P.required (P.Arg_type.create Common.Verification_method.of_string))
           ~doc:"sms|totp|passkey factor to reset"
       in
       fun tr -> Sca.reset_2fa_initiate tr ~user_id ~factor)
      ~to_json:Sca.Reset_2fa.Initiated.yojson_of_t
      ~to_sexp:Sca.Reset_2fa.Initiated.sexp_of_t
  ;;

  let reset_status =
    cmd
      ~summary:"status of a 2FA reset"
      (let%map.Command user_id = user
       and reset_id in
       fun tr -> Sca.reset_2fa_status tr ~user_id ~reset_id)
      ~to_json:Sca.Reset_2fa.Status.yojson_of_t
      ~to_sexp:Sca.Reset_2fa.Status.sexp_of_t
  ;;

  let reset_complete =
    cmd
      ~summary:"complete a 2FA reset after the liveness check (-mobile for sms)"
      (let%map.Command user_id = user
       and reset_id
       and number =
         P.flag "-mobile" (P.optional P.string) ~doc:"NUMBER new mobile, sms resets"
       and country_code =
         P.flag
           "-country-code"
           (P.optional_with_default "+372" P.string)
           ~doc:"+CC (default +372)"
       in
       fun tr ->
         let mobile =
           Option.map number ~f:(fun number -> { Common.Mobile.country_code; number })
         in
         Sca.reset_2fa_complete tr ~user_id ~reset_id ?mobile ())
      ~to_json:Sca.Reset_2fa.Completed.yojson_of_t
      ~to_sexp:Sca.Reset_2fa.Completed.sexp_of_t
  ;;

  let command =
    Command.group
      ~summary:"strong customer authentication"
      [ "totp-start", totp_start
      ; "totp-complete", totp_complete
      ; "totp-code", totp_code
      ; "login-start", login_start
      ; "login-complete", login_complete
      ; "record-event", record_event
      ; "trust", trust "trusting"
      ; "untrust", trust "untrusting"
      ; "confirm-trust", confirm_trust "trusting"
      ; "confirm-untrust", confirm_trust "untrusting"
      ; "reset-start", reset_start
      ; "reset-status", reset_status
      ; "reset-complete", reset_complete
      ; ( "passkeys"
        , raw_cmd
            ~summary:"list enrolled passkeys"
            (let%map.Command user_id = user in
             fun tr -> Sca.list_passkeys tr ~user_id) )
      ]
  ;;
end

module Sim_cmd = struct
  let kyc =
    unit_cmd
      ~summary:"simulate a KYC decision"
      (let%map.Command user_id = user
       and reject = P.flag "-reject" P.no_arg ~doc:" reject instead of approve"
       and tier = P.flag "-tier" (P.optional P.int) ~doc:"1|2 tier" in
       fun tr ->
         Simulator.kyc
           tr
           ~user_id
           ~decision:(if reject then Rejected else Approved)
           ?tier
           ())
  ;;

  let deposit =
    unit_cmd
      ~summary:"simulate an incoming SEPA payment to an enriched EUR account"
      (let%map.Command account_id = account
       and amount_cents = P.flag "-cents" (P.required P.string) ~doc:"N amount in cents"
       and reference = P.flag "-reference" (P.optional P.string) ~doc:"TEXT" in
       fun tr -> Simulator.deposit tr ~account_id ~amount_cents ?reference ())
  ;;

  let sepa =
    unit_cmd
      ~summary:"settle or fail an outgoing SEPA payment"
      (let%map.Command transaction_id =
         P.flag "-tx" (P.required P.string) ~doc:"ID transaction"
       and account_id = account
       and failed = P.flag "-fail" P.no_arg ~doc:" fail it instead" in
       fun tr ->
         Simulator.sepa_outcome tr ~transaction_id ~account_id ~completed:(not failed))
  ;;

  let card_auth =
    cmd
      ~summary:"simulate a card payment"
      (let%map.Command card_id = card
       and amount_eur_cents = P.flag "-cents" (P.required P.int) ~doc:"N EUR cents"
       and mcc =
         P.flag "-mcc" (P.optional P.string) ~doc:"MCC merchant category (ATM = cash)"
       in
       fun tr -> Simulator.card_authorization tr ~card_id ~amount_eur_cents ?mcc ())
      ~to_json:Simulator.Card_authorization.yojson_of_t
      ~to_sexp:Simulator.Card_authorization.sexp_of_t
  ;;

  let command =
    Command.group
      ~summary:"sandbox simulator"
      [ "kyc", kyc
      ; "deposit", deposit
      ; "sepa", sepa
      ; "card-auth", card_auth
      ; ( "card-status"
        , unit_cmd
            ~summary:"dispatch (default) or activate a physical card"
            (let%map.Command card_id = card
             and active = P.flag "-active" P.no_arg ~doc:" activate" in
             fun tr -> Simulator.card_status tr ~card_id ~active) )
      ; ( "liveness"
        , cmd
            ~summary:"pass the liveness check of a pending 2FA reset"
            (let%map.Command reset_id = P.flag "-reset" (P.required P.string) ~doc:"ID" in
             fun tr -> Simulator.reset_2fa_liveness tr ~reset_id)
            ~to_json:Sca.Reset_2fa.Status.yojson_of_t
            ~to_sexp:Sca.Reset_2fa.Status.sexp_of_t )
      ; ( "share-token"
        , cmd
            ~summary:"issue a KYC share token (masked unless -reveal)"
            (P.return (fun tr -> Simulator.kyc_share_token tr))
            ~to_json:(fun t -> `Assoc [ "shareToken", `String t ])
            ~to_sexp:Wire.Hidden_string.sexp_of_t )
      ; ( "payment-accounts"
        , raw_cmd
            ~summary:"read the application's Payment Accounts settings"
            (P.return (fun tr -> Simulator.payment_accounts_state tr)) )
      ; ( "webhook-ping"
        , unit_cmd
            ~summary:"send a signed TEST webhook to the configured URL"
            (let%map.Command payload =
               P.flag
                 "-payload"
                 (P.optional_with_default {|{"ping":true}|} P.string)
                 ~doc:"JSON"
             in
             fun tr ->
               Simulator.webhook_ping tr ~payload:(Yojson.Safe.from_string payload)) )
      ]
  ;;
end

let webhook_verify =
  Command.basic
    ~summary:"verify a webhook delivery read from stdin and print the decoded event"
    (let%map.Command path = P.flag "-path" (P.required P.string) ~doc:"PATH e.g. /tx"
     and signature =
       P.flag "-signature" (P.required P.string) ~doc:"HEX signature header"
     in
     fun () ->
       let body = In_channel.input_all In_channel.stdin in
       match
         Result.bind (Config.of_env ()) ~f:(fun config ->
           Webhook.verify_and_parse
             ~api_key:config.api_key
             ~path
             ~headers:[ "signature", signature ]
             ~body)
       with
       | Ok e -> Core.print_s [%sexp (e : Webhook.Event.t)]
       | Error e ->
         Core.eprint_s [%sexp (e : Error.t)];
         Stdlib.exit 1)
;;

let config_cmd =
  Command.basic
    ~summary:"show the configuration read from the environment (secrets hidden)"
    (let%map.Command live = P.flag "-live" P.no_arg ~doc:" allow a non-sandbox host" in
     fun () ->
       match Config.of_env ~live () with
       | Ok c -> Core.print_s [%sexp (c : Config.t)]
       | Error e ->
         Core.eprint_s [%sexp (e : Error.t)];
         Stdlib.exit 1)
;;

let ping =
  unit_cmd
    ~summary:"check the credentials ([POST /ping])"
    (P.return (fun tr -> Transport.unit tr `POST "/ping" ()))
;;

let () =
  Command_unix.run
    (Command.group
       ~summary:
         "Striga API client (sandbox by default; credentials from STRIGA_* variables)"
       [ "config", config_cmd
       ; "ping", ping
       ; "user", User_cmd.command
       ; "wallet", Wallet_cmd.command
       ; "exchange", Exchange_cmd.command
       ; "pay", Pay_cmd.command
       ; "card", Card_cmd.command
       ; "so", So_cmd.command
       ; "sca", Sca_cmd.command
       ; "sim", Sim_cmd.command
       ; "webhook-verify", webhook_verify
       ])
;;
