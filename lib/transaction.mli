(** Ledger transactions, as they appear in account statements, transaction lookups,
    OTP confirmations and the [/tx] webhook. Amounts are in the smallest unit of the
    account currency. *)

open! Core

module Tx_type : sig
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
  [@@deriving sexp, equal, compare, yojson]

  val to_string : t -> string
end

type t =
  { id : string option
  ; account_id : string option
  ; synced_owner_id : string option
  ; source_synced_owner_id : string option
  ; destination_synced_owner_id : string option
  ; source_account_id : string option
  ; destination_account_id : string option
  ; credit : Wire.Num_string.t option
  ; debit : Wire.Num_string.t option
  ; amount : Wire.Num_string.t option
  ; currency : string option
  ; timestamp : string option
  ; datetime : string option
  ; status : string option (** e.g. [PENDING_2FA_CONFIRMATION], [COMMITTED] *)
  ; tx_type : Tx_type.t option
  ; tx_sub_type : string option
  ; memo : string option
  ; memo_payer : string option
  ; exchange_rate : Wire.Num_string.t option
  ; order : Wire.Raw_json.t option
  ; balance_before : Common.Balance.t option
  ; balance_after : Common.Balance.t option
  ; parent_wallet_id : string option
  ; tx_hash : string option
  ; hash : string option
  ; blockchain_network : Wire.Network_name.t option
  ; blockchain_source_address : string option
  ; blockchain_deposit_address : string option
  ; blockchain_destination_address : string option
  ; blockchain_confirmations : int option
  ; other_crypto_identifier : string option (** e.g. the Lightning invoice *)
  ; iban : string option
  ; bic : string option
  ; banking_transaction_id : string option
  ; banking_sender_iban : string option
  ; banking_sender_bic : string option
  ; banking_sender_name : string option
  ; banking_payment_type : string option
  ; related_card_transaction_id : string option
  ; fee_estimate : Common.Fee_estimate.t option
  }
[@@deriving sexp, equal, yojson]

(** A page of transactions: [{"transactions": [...], "count", "total"}]. *)
type transaction = t [@@deriving sexp, equal, yojson]

module Page : sig
  type t =
    { transactions : transaction list
    ; count : int option
    ; total : int option
    }
  [@@deriving sexp, equal, yojson]
end
