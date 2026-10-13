open! Core
open Striga_client

let card f = Fixture.roundtrip f Card.t_of_yojson Card.yojson_of_t Card.equal

let%expect_test "virtual card linked to a BTC account (sandbox)" =
  let c = card "card-create.json" in
  print_s
    [%message
      ""
        ~type_:(c.type_ : Card.Card_type.t option)
        ~status:(c.status : Card.Status.t option)
        ~masked:(c.masked_card_number : string option)
        ~security:(c.security : Card.Security.t option)
        ~daily_purchase:
          (Option.bind c.limits ~f:(fun l -> Card.Limits.find l "dailyPurchase")
           : int option)
        ~limit_fields:(Option.value_map c.limits ~default:0 ~f:List.length : int)];
  let c' = card "card-get.json" in
  print_s [%sexp (String.equal c.id c'.id : bool)];
  [%expect {|
    ((type_ (Virtual)) (status (Active)) (masked (474367******2932))
     (security
      (((contactless_enabled (true)) (withdrawal_enabled (true))
        (internet_purchase_enabled (true)) (overall_limits_enabled (true)))))
     (daily_purchase (10000)) (limit_fields 49))
    true
    |}]
;;

let%expect_test "cards by user (sandbox)" =
  let p =
    Fixture.roundtrip "cards-all.json" Card.Page.t_of_yojson Card.Page.yojson_of_t Card.Page.equal
  in
  print_s
    [%message
      ""
        ~cards:(List.length p.cards : int)
        ~currency:
          (Option.bind (List.hd p.cards) ~f:(fun c -> c.linked_account_currency)
           : string option)];
  [%expect {| ((cards 1) (currency (BTC))) |}]
;;

let%expect_test "card statements: sandbox decline and docs approval" =
  List.iter [ "card-statement.json"; "docs-card-statement.json" ] ~f:(fun f ->
    let p =
      Fixture.roundtrip
        f
        Card.Card_transaction.Page.t_of_yojson
        Card.Card_transaction.Page.yojson_of_t
        Card.Card_transaction.Page.equal
    in
    List.iter p.transactions ~f:(fun t ->
      print_s
        [%message
          ""
            ~type_:(t.type_ : Transaction.Tx_type.t option)
            ~amount:(t.original_amount : string option)
            ~mcc:(t.merchant_category_code : string option)
            ~decline:(t.decline_details : string option)]));
  [%expect {|
    ((type_ (Card_authorization_declined)) (amount (12.34)) (mcc (5812))
     (decline ("Not Sufficient Funds")))
    ((type_ (Card_authorization)) (amount (10.5)) (mcc (5812)) (decline ()))
    |}]
;;

let%expect_test "statuses decode case-insensitively" =
  List.iter [ {|"Created"|}; {|"BLOCKED"|}; {|"LOST"|} ] ~f:(fun s ->
    print_s [%sexp (Card.Status.t_of_yojson (Yojson.Safe.from_string s) : Card.Status.t)]);
  [%expect {|
    Created
    Blocked
    (Other LOST)
    |}]
;;

let%expect_test "PAN UI options need both values and the token stays hidden" =
  let config ?application_id ?ui_secret () =
    ok_exn
      (Config.create ?application_id ?ui_secret ~api_key:"k" ~api_secret:"s" ())
  in
  print_s
    [%sexp
      (Card.Pan_ui.browser_options (config ()) |> Or_error.map ~f:Yojson.Safe.to_string
       : string Or_error.t)];
  print_s
    [%sexp
      (Card.Pan_ui.browser_options (config ~application_id:"app" ~ui_secret:"ui" ())
       |> Or_error.map ~f:Yojson.Safe.to_string
       : string Or_error.t)];
  let c = Card.Consent.t_of_yojson (`Assoc [ "cardAuthToken", `String "eyJ.x.y" ]) in
  print_s [%sexp (c : Card.Consent.t)];
  [%expect {|
    (Error "the card PAN UI needs STRIGA_APPLICATION_ID and STRIGA_UI_SECRET")
    (Ok "{\"uiSecret\":\"ui\",\"applicationId\":\"app\"}")
    ((card_auth_token <hidden>))
    |}]
;;
