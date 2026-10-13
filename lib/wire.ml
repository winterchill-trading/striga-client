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

module Hidden_string = struct
  type t = string [@@deriving equal]

  let sexp_of_t (_ : t) = Sexp.Atom "<hidden>"
  let t_of_yojson = Ppx_yojson_conv_lib.Yojson_conv.string_of_yojson
  let yojson_of_t = Ppx_yojson_conv_lib.Yojson_conv.yojson_of_string
end

module Raw_json = struct
  type t = Yojson.Safe.t

  let equal = Yojson.Safe.equal
  let sexp_of_t t = Sexp.Atom (Yojson.Safe.to_string t)

  let t_of_sexp = function
    | Sexp.Atom s -> Yojson.Safe.from_string s
    | sexp -> raise_s [%message "Raw_json.t_of_sexp: expected an atom" (sexp : Sexp.t)]
  ;;

  let t_of_yojson t = t
  let yojson_of_t t = t
end

module Network_name = struct
  type t = string [@@deriving sexp, equal]

  let t_of_yojson (json : Yojson.Safe.t) =
    match json with
    | `String s -> s
    | `Assoc fields ->
      (match List.Assoc.find fields "name" ~equal:String.equal with
       | Some (`String s) -> s
       | _ ->
         raise
           (Ppx_yojson_conv_lib.Yojson_conv.Of_yojson_error
              (Failure "network object without a name", json)))
    | _ ->
      raise
        (Ppx_yojson_conv_lib.Yojson_conv.Of_yojson_error
           (Failure "expected a network name or object", json))
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
