open! Core
open! Async
open Striga_client

(* Each step either must work ([Must]) or may fail for a reason the sandbox application
   controls ([May]: currencies not enabled, no balance to move). A [May] failure is a
   known gap, printed with Striga's error code; a [Must] failure fails the run. *)
type expect =
  | Must
  | May

let failures = ref 0
let gaps = ref 0

let short_error e =
  let code = Api_error.code_of_error e in
  let status = Api_error.status_of_error e in
  let msg =
    match Error.sexp_of_t e with
    | sexp ->
      let rec find = function
        | Sexp.List [ Atom "message"; List [ Atom m ] ] -> Some m
        | Sexp.List l -> List.find_map l ~f:find
        | Atom _ -> None
      in
      Option.value (find sexp) ~default:(Error.to_string_hum e)
  in
  let msg = if String.length msg > 160 then String.prefix msg 160 ^ "..." else msg in
  sprintf
    "%s %s %s"
    (Option.value_map status ~default:"-" ~f:Int.to_string)
    (Option.value code ~default:"-")
    msg
;;

let step ?(expect = Must) name f =
  match%map Monitor.try_with_or_error ~extract_exn:true f >>| Or_error.join with
  | Ok v ->
    Core.printf "ok    %s\n%!" name;
    Some v
  | Error e ->
    (match expect with
     | Must ->
       incr failures;
       Core.printf "FAIL  %s: %s\n%!" name (short_error e)
     | May ->
       incr gaps;
       Core.printf "gap   %s: %s\n%!" name (short_error e));
    None
;;

let ip = "185.46.212.10"
let code = "123456"

let rec poll ~tries ~every f =
  match%bind f () with
  | Ok (Some v) -> return (Ok v)
  | Error _ as e when tries <= 1 -> return e
  | Ok None when tries <= 1 -> return (Or_error.error_string "timed out waiting")
  | _ ->
    let%bind () = Clock_ns.after every in
    poll ~tries:(tries - 1) ~every f
;;

let new_user tr ~tag =
  let stamp = Time_ns.to_int_ns_since_epoch (Time_ns.now ()) / 1_000_000 in
  User.create
    tr
    ~first_name:"Ada"
    ~last_name:("Sandbox" ^ tag)
    ~email:(sprintf "hello+striga-%d-%s@winterchill.xyz" stamp (String.lowercase tag))
    ~mobile:{ country_code = "+372"; number = sprintf "5%07d" (stamp % 10_000_000) }
    ~date_of_birth:(Common.Date_of_birth.create ~year:1990 ~month:1 ~day:15)
    ~address:
      { address_line1 = "Sepapaja 6"
      ; address_line2 = None
      ; city = "Tallinn"
      ; postal_code = "11415"
      ; state = None
      ; country = "EE"
      }
    ()
;;

(* Create, verify and approve a user, then wait for the default wallet. *)
let onboard tr ~tag =
  let open Deferred.Option.Let_syntax in
  let%bind u = step ("create user " ^ tag) (fun () -> new_user tr ~tag) in
  let user_id = u.User.user_id in
  let%bind () =
    step ("verify email " ^ tag) (fun () -> User.verify_email tr ~user_id ~code)
  in
  let%bind () =
    step ("verify mobile " ^ tag) (fun () -> User.verify_mobile tr ~user_id ~code)
  in
  let%bind (_ : User.Kyc_start.t) =
    step ("start KYC " ^ tag) (fun () -> User.start_kyc tr ~user_id ())
  in
  let%bind () =
    step ("simulate KYC approval " ^ tag) (fun () ->
      Simulator.kyc tr ~user_id ~decision:Approved ~tier:1 ())
  in
  let%bind (_ : User.Kyc.t) =
    step ("KYC approved " ^ tag) (fun () ->
      poll ~tries:15 ~every:(Time_ns.Span.of_sec 2.) (fun () ->
        User.kyc_status tr ~user_id
        >>|? fun k ->
        Option.some_if ([%equal: User.Kyc_status.t option] k.status (Some Approved)) k))
  in
  let%map wallet =
    step ("default wallet provisioned " ^ tag) (fun () ->
      poll ~tries:15 ~every:(Time_ns.Span.of_sec 2.) (fun () ->
        Wallet.get_all
          tr
          ~user_id
          ~start:(Time_ns.sub (Time_ns.now ()) Time_ns.Span.day)
          ~stop:(Time_ns.add (Time_ns.now ()) Time_ns.Span.minute)
          ()
        >>|? fun p -> List.hd p.wallets))
  in
  user_id, wallet
;;

let account_id (w : Wallet.t) currency =
  Option.map (Wallet.account w ~currency) ~f:(fun a -> a.Wallet.Account.account_id)
;;

let ignore_d d = Deferred.ignore_m d

(* The EUR leg of the walk. The sandbox leaves EUR accounts out of /wallets/get and
   /wallets/get/all, so this runs only when a listed wallet carries one. *)
let eur_walk tr ~a ~wa ~b ~wb =
  match account_id wa "EUR", account_id wb "EUR" with
  | None, _ | _, None ->
    incr gaps;
    Core.printf
      "gap   EUR walk (enrich IBAN, simulated deposit, swap to USDC, intraledger, SEPA \
       with OTP): no EUR account listed by /wallets/get (listed: %s); the EUR account is \
       not returned there and its id has to come from elsewhere (webhook or portal)\n\
       %!"
      (String.concat ~sep:"," (List.map wa.Wallet.accounts ~f:fst));
    return ()
  | Some eur_a, Some eur_b ->
    let initiate_and_confirm ?(expect = Must) name f =
      match%bind step ~expect (name ^ " (initiate)") f with
      | None -> return None
      | Some (i : Payment.Initiated.t) ->
        step ~expect (name ^ " (confirm OTP)") (fun () ->
          Payment.confirm tr ~user_id:a ~challenge_id:i.challenge_id ~code ~ip ())
    in
    let%bind (_ : Wallet.Enrichment.t option) =
      step "enrich EUR (IBAN)" (fun () ->
        Wallet.enrich_account tr ~user_id:a ~account_id:eur_a)
    in
    let%bind (_ : unit option) =
      step "simulate EUR deposit 100.00" (fun () ->
        Simulator.deposit
          tr
          ~account_id:eur_a
          ~amount_cents:"10000"
          ~sender_name:"Ada Sandbox"
          ~reference:"walk"
          ())
    in
    let%bind (_ : Wallet.Account.t option) =
      step "deposit credited" (fun () ->
        poll ~tries:15 ~every:(Time_ns.Span.of_sec 2.) (fun () ->
          Wallet.get_account tr ~user_id:a ~account_id:eur_a
          >>|? fun acct ->
          match acct.available_balance with
          | Some { amount = Some amount; _ } when not (String.equal amount "0") ->
            Some acct
          | _ -> None))
    in
    let%bind (_ : Transaction.t option) =
      match account_id wa "USDC" with
      | None ->
        incr gaps;
        Core.printf "gap   swap EUR to USDC: no USDC account\n%!";
        return None
      | Some usdc ->
        initiate_and_confirm "swap EUR to USDC" (fun () ->
          Exchange.swap
            tr
            ~user_id:a
            ~source_account_id:eur_a
            ~destination_account_id:usdc
            ~amount:"2000"
            ~ip
            ())
    in
    let%bind (_ : Wallet.Enrichment.t option) =
      step ~expect:May "enrich EUR of B" (fun () ->
        Wallet.enrich_account tr ~user_id:b ~account_id:eur_b)
    in
    let%bind (_ : Transaction.t option) =
      initiate_and_confirm ~expect:May "intraledger EUR A to B" (fun () ->
        Payment.intraledger
          tr
          ~user_id:a
          ~source_account_id:eur_a
          ~destination_account_id:eur_b
          ~amount:"500"
          ~memo:"walk"
          ())
    in
    (* Paying out to the account's own Striga IBAN is refused (31003, "use the inter/intra
       methods"); the sandbox accepts the textbook example IBAN. *)
    let%bind tx =
      initiate_and_confirm "SEPA payout" (fun () ->
        Payment.sepa
          tr
          ~user_id:a
          ~source_account_id:eur_a
          ~amount:"1000"
          ~iban:"DE89370400440532013000"
          ~bic:"COBADEFFXXX"
          ~memo:"walk"
          ())
    in
    (match tx with
     | Some { id = Some transaction_id; _ } ->
       step "simulate SEPA settlement" (fun () ->
         Simulator.sepa_outcome tr ~transaction_id ~account_id:eur_a ~completed:true)
       |> ignore_d
     | _ -> return ())
;;

let walk tr =
  let open Deferred.Let_syntax in
  let%bind (_ : unit option) =
    step "ping" (fun () -> Transport.unit tr `POST "/ping" ())
  in
  let%bind (_ : Exchange.Rates.t option) = step "rates" (fun () -> Exchange.rates tr) in
  let%bind (_ : Wire.Raw_json.t option) =
    step "payment accounts state" (fun () -> Simulator.payment_accounts_state tr)
  in
  match%bind onboard tr ~tag:"A" with
  | None -> return ()
  | Some (a, wa) ->
    (match%bind onboard tr ~tag:"B" with
     | None -> return ()
     | Some (b, wb) ->
       let%bind (_ : Wallet.t option) =
         step "create a second wallet" (fun () -> Wallet.create tr ~user_id:a)
       in
       (* No wait for EUR: the sandbox never lists the EUR account in /wallets/get, so
          polling the wallet (the old three-minute wait) only delayed the gap. *)
       let%bind () = eur_walk tr ~a ~wa ~b ~wb in
       let btc_a = Option.value_exn (account_id wa "BTC") in
       let btc_b = Option.value_exn (account_id wb "BTC") in
       let%bind (_ : Wallet.Enrichment.t option) =
         step "enrich BTC (deposit address)" (fun () ->
           Wallet.enrich_account tr ~user_id:a ~account_id:btc_a)
       in
       let%bind eth_b =
         match account_id wb "ETH" with
         | None -> return None
         | Some eth ->
           step "enrich ETH of B" (fun () ->
             Wallet.enrich_account tr ~user_id:b ~account_id:eth)
       in
       let%bind invoice_b =
         step "Lightning deposit invoice for B" (fun () ->
           Payment.lightning_deposit
             tr
             ~user_id:b
             ~account_id:btc_b
             ~amount_sats:"1000"
             ~memo:"walk"
             ~ttl_minutes:30
             ())
       in
       let%bind (_ : Wallet.Account.t option) =
         step "account with balance" (fun () ->
           Wallet.get_account tr ~user_id:a ~account_id:btc_a)
       in
       (* SCA: enroll TOTP for A, then log in with it. *)
       let%bind enrollment =
         step "start TOTP enrollment" (fun () -> Sca.start_totp tr ~user_id:a)
       in
       let%bind totp =
         match enrollment with
         | Some { secret; secret_base32_encoded = Some b32; _ } ->
           step "complete TOTP enrollment" (fun () ->
             match Totp.code_of_base32 b32 (Time_ns.now ()) with
             | Error _ as e -> return e
             | Ok code -> Sca.complete_totp tr ~user_id:a ~secret ~code >>|? fun _ -> b32)
         | _ -> return None
       in
       let%bind (_ : Sca.Login_challenge.t option) =
         step "SCA login start (totp)" (fun () ->
           Sca.login_start tr ~user_id:a ~verification_method:Totp)
       in
       let%bind (_ : Wire.Raw_json.t option) =
         match totp with
         | None -> return None
         | Some b32 ->
           step "SCA login complete (totp)" (fun () ->
             match Totp.code_of_base32 b32 (Time_ns.now ()) with
             | Error _ as e -> return e
             | Ok code ->
               Sca.login_complete tr ~user_id:a ~verification_method:Totp ~ip ~code ())
       in
       (* Crypto money movement: no balance in the sandbox, so these stop at the balance
          check; the requests and error decoding are what is exercised. *)
       let%bind () =
         match eth_b, account_id wa "ETH" with
         | Some { blockchain_deposit_address = Some address; _ }, Some eth_a ->
           let open Deferred.Let_syntax in
           (* Whitelisting needs an enriched account of the same currency first. *)
           let%bind (_ : Wallet.Enrichment.t option) =
             step "enrich ETH of A" (fun () ->
               Wallet.enrich_account tr ~user_id:a ~account_id:eth_a)
           in
           (match%bind
              step "whitelist B's ETH address for A" (fun () ->
                Payment.whitelist_address
                  tr
                  ~user_id:a
                  ~address
                  ~currency:"ETH"
                  ~network:"ETH"
                  ~label:"walk"
                  ())
            with
            | None -> return ()
            | Some w ->
              let%bind (_ : Common.Fee_estimate.t option) =
                step ~expect:May "on-chain fee estimate" (fun () ->
                  Payment.onchain_fee_estimate
                    tr
                    ~user_id:a
                    ~source_account_id:eth_a
                    ~whitelisted_address_id:w.id
                    ~amount:"1000000000000000")
              in
              let%map (_ : Payment.Initiated.t option) =
                step ~expect:May "on-chain withdrawal (initiate)" (fun () ->
                  Payment.onchain_withdrawal
                    tr
                    ~user_id:a
                    ~source_account_id:eth_a
                    ~whitelisted_address_id:w.id
                    ~amount:"1000000000000000"
                    ())
              in
              ())
         | _ -> return ()
       in
       let%bind (_ : Payment.Initiated.t option) =
         step ~expect:May "intraledger BTC A to B (initiate)" (fun () ->
           Payment.intraledger
             tr
             ~user_id:a
             ~source_account_id:btc_a
             ~destination_account_id:btc_b
             ~amount:"1000"
             ~verification_method:Totp
             ())
       in
       let%bind () =
         match invoice_b with
         | None -> return ()
         | Some inv ->
           step
             ~expect:May
             "Lightning withdrawal paying B's invoice (initiate)"
             (fun () ->
                Payment.lightning_withdrawal
                  tr
                  ~user_id:a
                  ~source_account_id:btc_a
                  ~invoice:inv.invoice
                  ())
           |> ignore_d
       in
       (* Cards. *)
       (* Link to the funded EUR account when there is one, so the simulated payment is
          approved; a BTC card has no balance and is declined. *)
       let eur_a = account_id wa "EUR" in
       let%bind card =
         step
           (if Option.is_some eur_a
            then "create virtual card on EUR"
            else "create virtual card on BTC")
           (fun () ->
             Card.create
               tr
               ~user_id:a
               ~name_on_card:"Ada Sandbox"
               ~three_d_secure_password:"Walk#Pass2026"
               ~type_:Virtual
               ~account_id_to_link:(Option.value eur_a ~default:btc_a)
               ())
       in
       let%bind () =
         match card with
         | None -> return ()
         | Some c ->
           let card_id = c.id in
           let%bind (_ : unit option) =
             step "freeze card" (fun () -> Card.block tr ~card_id)
           in
           let%bind (_ : Card.t option) =
             step "card is blocked" (fun () ->
               Card.get tr ~card_id
               >>| Or_error.bind ~f:(fun (c : Card.t) ->
                 if [%equal: Card.Status.t option] c.status (Some Blocked)
                 then Ok c
                 else
                   Or_error.error_s
                     [%message "unexpected status" (c.status : Card.Status.t option)]))
           in
           let%bind (_ : unit option) =
             step "unfreeze card" (fun () -> Card.unblock tr ~card_id)
           in
           let%bind (_ : Card.t option) =
             step "card limits" (fun () ->
               Card.update_limits tr ~card_id ~limits:[ "dailyPurchase", 500 ])
           in
           let%bind (_ : Card.t option) =
             step "card settings" (fun () ->
               Card.update_security
                 tr
                 ~card_id
                 ~contactless:false
                 ~withdrawal:false
                 ~internet_purchase:true)
           in
           let%bind (_ : Card.Page.t option) =
             step "cards by user" (fun () -> Card.get_all tr ~user_id:a ())
           in
           let%bind (_ : Simulator.Card_authorization.t option) =
             step "simulate card payment 12.34 EUR" (fun () ->
               Simulator.card_authorization
                 tr
                 ~card_id
                 ~amount_eur_cents:1234
                 ~mcc:"5812"
                 ()
               >>| Or_error.bind ~f:(fun (r : Simulator.Card_authorization.t) ->
                 match eur_a, r.response with
                 | Some _, Some "APPROVED" | None, Some "DECLINED" -> Ok r
                 | _ ->
                   Or_error.error_s
                     [%message "unexpected decision" (r.response : string option)]))
           in
           let%bind (_ : Card.Card_transaction.Page.t option) =
             step "card statement" (fun () ->
               Card.statement
                 tr
                 ~card_id
                 ~start:(Time_ns.sub (Time_ns.now ()) Time_ns.Span.day)
                 ~stop:(Time_ns.add (Time_ns.now ()) Time_ns.Span.minute)
                 ())
           in
           let%bind (_ : unit option) =
             step "revoke PAN consents" (fun () -> Card.revoke_consents tr ~user_id:a)
           in
           step "close virtual card" (fun () -> Card.burn tr ~card_id) |> ignore_d
       in
       let%bind (_ : Common.Challenge.t option) =
         step ~expect:May "standing order BTC swap-only" (fun () ->
           Standing_order.create
             tr
             ~user_id:a
             ~account_id:btc_a
             ~action:Swap_only
             ~destination_currency:"EUR"
             ())
       in
       let%bind (_ : Transaction.Page.t option) =
         step "account statement" (fun () ->
           Wallet.statement
             tr
             ~user_id:a
             ~account_id:btc_a
             ~start:(Time_ns.sub (Time_ns.now ()) Time_ns.Span.day)
             ~stop:(Time_ns.add (Time_ns.now ()) Time_ns.Span.minute)
             ())
       in
       step ~expect:May "webhook ping" (fun () ->
         Simulator.webhook_ping tr ~payload:(`Assoc [ "walk", `Bool true ]))
       |> ignore_d)
;;

let () =
  let live = Option.equal String.equal (Sys.getenv "STRIGA_LIVE_TESTS") (Some "1") in
  if not (live && Config.env_available ())
  then
    (* Core's printer: the Async scheduler never starts on this path. *)
    Core.print_endline
      "striga live walk skipped (set STRIGA_API_KEY, STRIGA_API_SECRET and \
       STRIGA_LIVE_TESTS=1)"
  else
    Command_unix.run
      (Command.async
         ~summary:"live sandbox walk"
         (Command.Param.return (fun () ->
            match Config.of_env () with
            | Error e ->
              Core.eprint_s [%sexp (e : Error.t)];
              Stdlib.exit 1
            | Ok config ->
              let tr = Transport.create config in
              let%map () = walk tr in
              Core.printf "walk done: %d failed, %d known gaps\n%!" !failures !gaps;
              if !failures > 0 then Stdlib.exit 1)))
;;
