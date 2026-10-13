open! Core
open Ppx_yojson_conv_lib.Yojson_conv.Primitives

module Tx_type = struct
  module T = struct
    type t =
      | Intra_ledger_send
      | Intra_ledger_send_denied
      | Inter_ledger_send
      | Inter_ledger_send_denied
      | Sepa_payin_completed
      | Sepa_payin_denied
      | Sepa_payin_failed
      | Sepa_payin_reverted
      | Sepa_payout_initiated
      | Sepa_payout_completed
      | Sepa_payout_failed
      | Sepa_payout_denied
      | Sepa_payout_reverted
      | Ln_incoming_pending
      | Ln_incoming_confirmed
      | Ln_incoming_expired
      | Ln_incoming_denied
      | Ln_outgoing_initiated
      | Ln_outgoing_confirmed
      | Ln_outgoing_failed
      | Ln_outgoing_denied
      | On_chain_deposit_pending
      | On_chain_deposit_confirmed
      | On_chain_deposit_denied
      | On_chain_withdrawal_initiated
      | On_chain_withdrawal_pending
      | On_chain_withdrawal_confirmed
      | On_chain_withdrawal_failed
      | On_chain_withdrawal_denied
      | Swap_currency_initiated
      | Currency_exchange
      | Exchange_debit
      | Exchange_credit
      | Card_authorization
      | Card_authorization_declined
      | Card_authorization_reversal
      | Card_authorization_release
      | Card_authorization_settlement_confirmed
      | Manual_adjustment
      | Other of string
    [@@deriving sexp, equal, compare]

    let table =
      [ Intra_ledger_send, "INTRA_LEDGER_SEND"
      ; Intra_ledger_send_denied, "INTRA_LEDGER_SEND_DENIED"
      ; Inter_ledger_send, "INTER_LEDGER_SEND"
      ; Inter_ledger_send_denied, "INTER_LEDGER_SEND_DENIED"
      ; Sepa_payin_completed, "SEPA_PAYIN_COMPLETED"
      ; Sepa_payin_denied, "SEPA_PAYIN_DENIED"
      ; Sepa_payin_failed, "SEPA_PAYIN_FAILED"
      ; Sepa_payin_reverted, "SEPA_PAYIN_REVERTED"
      ; Sepa_payout_initiated, "SEPA_PAYOUT_INITIATED"
      ; Sepa_payout_completed, "SEPA_PAYOUT_COMPLETED"
      ; Sepa_payout_failed, "SEPA_PAYOUT_FAILED"
      ; Sepa_payout_denied, "SEPA_PAYOUT_DENIED"
      ; Sepa_payout_reverted, "SEPA_PAYOUT_REVERTED"
      ; Ln_incoming_pending, "LN_INCOMING_PENDING"
      ; Ln_incoming_confirmed, "LN_INCOMING_CONFIRMED"
      ; Ln_incoming_expired, "LN_INCOMING_EXPIRED"
      ; Ln_incoming_denied, "LN_INCOMING_DENIED"
      ; Ln_outgoing_initiated, "LN_OUTGOING_INITIATED"
      ; Ln_outgoing_confirmed, "LN_OUTGOING_CONFIRMED"
      ; Ln_outgoing_failed, "LN_OUTGOING_FAILED"
      ; Ln_outgoing_denied, "LN_OUTGOING_DENIED"
      ; On_chain_deposit_pending, "ON_CHAIN_DEPOSIT_PENDING"
      ; On_chain_deposit_confirmed, "ON_CHAIN_DEPOSIT_CONFIRMED"
      ; On_chain_deposit_denied, "ON_CHAIN_DEPOSIT_DENIED"
      ; On_chain_withdrawal_initiated, "ON_CHAIN_WITHDRAWAL_INITIATED"
      ; On_chain_withdrawal_pending, "ON_CHAIN_WITHDRAWAL_PENDING"
      ; On_chain_withdrawal_confirmed, "ON_CHAIN_WITHDRAWAL_CONFIRMED"
      ; On_chain_withdrawal_failed, "ON_CHAIN_WITHDRAWAL_FAILED"
      ; On_chain_withdrawal_denied, "ON_CHAIN_WITHDRAWAL_DENIED"
      ; Swap_currency_initiated, "SWAP_CURRENCY_INITIATED"
      ; Currency_exchange, "CURRENCY_EXCHANGE"
      ; Exchange_debit, "EXCHANGE_DEBIT"
      ; Exchange_credit, "EXCHANGE_CREDIT"
      ; Card_authorization, "CARD_AUTHORIZATION"
      ; Card_authorization_declined, "CARD_AUTHORIZATION_DECLINED"
      ; Card_authorization_reversal, "CARD_AUTHORIZATION_REVERSAL"
      ; Card_authorization_release, "CARD_AUTHORIZATION_RELEASE"
      ; Card_authorization_settlement_confirmed, "CARD_AUTHORIZATION_SETTLEMENT_CONFIRMED"
      ; Manual_adjustment, "MANUAL_ADJUSTMENT"
      ]
    ;;

    let other s = Other s

    let to_other = function
      | Other s -> Some s
      | _ -> None
    ;;
  end

  include T
  include Wire.Enum.Make (T)
end

type t =
  { id : string option
       [@default None] [@yojson_drop_if Option.is_none]
  ; account_id : string option
       [@key "accountId"] [@default None] [@yojson_drop_if Option.is_none]
  ; synced_owner_id : string option
       [@key "syncedOwnerId"] [@default None] [@yojson_drop_if Option.is_none]
  ; source_synced_owner_id : string option
       [@key "sourceSyncedOwnerId"] [@default None] [@yojson_drop_if Option.is_none]
  ; destination_synced_owner_id : string option
       [@key "destinationSyncedOwnerId"] [@default None] [@yojson_drop_if Option.is_none]
  ; source_account_id : string option
       [@key "sourceAccountId"] [@default None] [@yojson_drop_if Option.is_none]
  ; destination_account_id : string option
       [@key "destinationAccountId"] [@default None] [@yojson_drop_if Option.is_none]
  ; credit : Wire.Num_string.t option
       [@default None] [@yojson_drop_if Option.is_none]
  ; debit : Wire.Num_string.t option
       [@default None] [@yojson_drop_if Option.is_none]
  ; amount : Wire.Num_string.t option
       [@default None] [@yojson_drop_if Option.is_none]
  ; currency : string option
       [@default None] [@yojson_drop_if Option.is_none]
  ; timestamp : string option
       [@default None] [@yojson_drop_if Option.is_none]
  ; datetime : string option
       [@default None] [@yojson_drop_if Option.is_none]
  ; status : string option
       [@default None] [@yojson_drop_if Option.is_none]
  ; tx_type : Tx_type.t option
       [@key "txType"] [@default None] [@yojson_drop_if Option.is_none]
  ; tx_sub_type : string option
       [@key "txSubType"] [@default None] [@yojson_drop_if Option.is_none]
  ; memo : string option
       [@default None] [@yojson_drop_if Option.is_none]
  ; memo_payer : string option
       [@key "memoPayer"] [@default None] [@yojson_drop_if Option.is_none]
  ; exchange_rate : Wire.Num_string.t option
       [@key "exchangeRate"] [@default None] [@yojson_drop_if Option.is_none]
  ; order : Wire.Raw_json.t option
       [@default None] [@yojson_drop_if Option.is_none]
  ; balance_before : Common.Balance.t option
       [@key "balanceBefore"] [@default None] [@yojson_drop_if Option.is_none]
  ; balance_after : Common.Balance.t option
       [@key "balanceAfter"] [@default None] [@yojson_drop_if Option.is_none]
  ; parent_wallet_id : string option
       [@key "parentWalletId"] [@default None] [@yojson_drop_if Option.is_none]
  ; tx_hash : string option
       [@key "txHash"] [@default None] [@yojson_drop_if Option.is_none]
  ; hash : string option
       [@default None] [@yojson_drop_if Option.is_none]
  ; blockchain_network : Wire.Network_name.t option
       [@key "blockchainNetwork"] [@default None] [@yojson_drop_if Option.is_none]
  ; blockchain_source_address : string option
       [@key "blockchainSourceAddress"] [@default None] [@yojson_drop_if Option.is_none]
  ; blockchain_deposit_address : string option
       [@key "blockchainDepositAddress"] [@default None] [@yojson_drop_if Option.is_none]
  ; blockchain_destination_address : string option
       [@key "blockchainDestinationAddress"] [@default None] [@yojson_drop_if Option.is_none]
  ; blockchain_confirmations : int option
       [@key "blockchainConfirmations"] [@default None] [@yojson_drop_if Option.is_none]
  ; other_crypto_identifier : string option
       [@key "otherCryptoIdentifier"] [@default None] [@yojson_drop_if Option.is_none]
  ; iban : string option
       [@default None] [@yojson_drop_if Option.is_none]
  ; bic : string option
       [@default None] [@yojson_drop_if Option.is_none]
  ; banking_transaction_id : string option
       [@key "bankingTransactionId"] [@default None] [@yojson_drop_if Option.is_none]
  ; banking_sender_iban : string option
       [@key "bankingSenderIban"] [@default None] [@yojson_drop_if Option.is_none]
  ; banking_sender_bic : string option
       [@key "bankingSenderBic"] [@default None] [@yojson_drop_if Option.is_none]
  ; banking_sender_name : string option
       [@key "bankingSenderName"] [@default None] [@yojson_drop_if Option.is_none]
  ; banking_payment_type : string option
       [@key "bankingPaymentType"] [@default None] [@yojson_drop_if Option.is_none]
  ; related_card_transaction_id : string option
       [@key "relatedCardTransactionId"] [@default None] [@yojson_drop_if Option.is_none]
  ; fee_estimate : Common.Fee_estimate.t option
       [@key "feeEstimate"] [@default None] [@yojson_drop_if Option.is_none]
  }
[@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]

type transaction = t [@@deriving sexp, equal, yojson]

module Page = struct
  type t =
    { transactions : transaction list [@default []]
    ; count : int option [@default None] [@yojson_drop_if Option.is_none]
    ; total : int option [@default None] [@yojson_drop_if Option.is_none]
    }
  [@@deriving sexp, equal, yojson] [@@yojson.allow_extra_fields]
end
