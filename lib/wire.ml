open! Core

module Num_string = struct
  type t = string [@@deriving sexp, equal, compare]

  let t_of_yojson (json : Yojson.Safe.t) =
    match json with
    | `String s -> s
    | `Int i -> Int.to_string i
    | `Intlit s -> s
    | `Float f ->
      (* Yojson prints floats in their shortest round-trip form ("12.34", "5e-08"). *)
      Yojson.Safe.to_string (`Float f)
    | _ ->
      raise
        (Ppx_yojson_conv_lib.Yojson_conv.Of_yojson_error
           (Failure "expected a number or a string", json))
  ;;

  let yojson_of_t t : Yojson.Safe.t = `String t
end

module Enum = struct
  module type Arg = sig
    type t

    val table : (t * string) list
    val other : string -> t
    val to_other : t -> string option
  end

  module Make (X : Arg) = struct
    let to_string t =
      match X.to_other t with
      | Some s -> s
      | None ->
        List.find_map_exn X.table ~f:(fun (v, s) -> Option.some_if (phys_equal v t) s)
    ;;

    let of_string s =
      match List.find X.table ~f:(fun (_, name) -> String.equal name s) with
      | Some (v, _) -> v
      | None -> X.other s
    ;;

    let t_of_yojson (json : Yojson.Safe.t) =
      match json with
      | `String s -> of_string s
      | _ ->
        raise
          (Ppx_yojson_conv_lib.Yojson_conv.Of_yojson_error
             (Failure "expected a string", json))
    ;;

    let yojson_of_t t : Yojson.Safe.t = `String (to_string t)
  end
end

let obj fields =
  `Assoc (List.filter_map fields ~f:(fun (k, v) -> Option.map v ~f:(fun v -> k, v)))
;;

let decode name of_yojson json =
  match of_yojson json with
  | v -> Ok v
  | exception Ppx_yojson_conv_lib.Yojson_conv.Of_yojson_error (exn, _) ->
    Or_error.error_s [%message "unexpected JSON shape" name ~_:(exn : exn)]
  | exception exn -> Or_error.error_s [%message "unexpected JSON shape" name ~_:(exn : exn)]
;;
