(* Js_of_ocaml compiler
 * http://www.ocsigen.org/js_of_ocaml/
 * Copyright (C) 2013 Hugo Heuzard
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *)

open! Stdlib
open Code
open Flow

let static_env = Hashtbl.create 17

let clear_static_env () = Hashtbl.clear static_env

let set_static_env s value = Hashtbl.add static_env s value

let get_static_env s = try Some (Hashtbl.find static_env s) with Not_found -> None

module Int = Int32

let int_binop l w f =
  match l with
  | [ Int i; Int j ] -> Some (Int (w (f i j)))
  | _ -> None

let shift l w t f =
  match l with
  | [ Int i; Int j ] -> Some (Int (w (f (t i) (Int32.to_int j land 0x1f))))
  | _ -> None

let float_binop_aux (l : constant list) (f : float -> float -> 'a) : 'a option =
  let args =
    match l with
    | [ Float i; Float j ] -> Some (i, j)
    | [ Int i; Int j ] -> Some (Int32.to_float i, Int32.to_float j)
    | [ Int i; Float j ] -> Some (Int32.to_float i, j)
    | [ Float i; Int j ] -> Some (i, Int32.to_float j)
    | _ -> None
  in
  match args with
  | None -> None
  | Some (i, j) -> Some (f i j)

let float_binop (l : constant list) (f : float -> float -> float) : constant option =
  match float_binop_aux l f with
  | Some x -> Some (Float x)
  | None -> None

let float_unop (l : constant list) (f : float -> float) : constant option =
  match l with
  | [ Float i ] -> Some (Float (f i))
  | [ Int i ] -> Some (Float (f (Int32.to_float i)))
  | _ -> None

let bool' b = Int (if b then 1l else 0l)

let bool b = Some (bool' b)

let float_binop_bool l f =
  match float_binop_aux l f with
  | Some b -> bool b
  | None -> None

let eval_prim ~target x =
  match x with
  | Not, [ Int i ] -> bool Int32.(i = 0l)
  | Lt, [ Int i; Int j ] -> bool Int32.(i < j)
  | Le, [ Int i; Int j ] -> bool Int32.(i <= j)
  | Eq, [ Int i; Int j ] -> bool Int32.(i = j)
  | Neq, [ Int i; Int j ] -> bool Int32.(i <> j)
  | Ult, [ Int i; Int j ] -> bool (Int32.(j < 0l) || Int32.(i < j))
  | Extern name, l -> (
      let name = Primitive.resolve name in
      let wrap =
        match target with
        | `JavaScript -> fun i -> i
        | `Wasm -> Int31.wrap
      in
      match name, l with
      (* int *)
      | "%int_add", _ -> int_binop l wrap Int.add
      | "%int_sub", _ -> int_binop l wrap Int.sub
      | "%direct_int_mul", _ -> int_binop l wrap Int.mul
      | "%direct_int_div", [ _; Int 0l ] -> None
      | "%direct_int_div", _ -> int_binop l wrap Int.div
      | "%direct_int_mod", _ -> int_binop l wrap Int.rem
      | "%int_and", _ -> int_binop l wrap Int.logand
      | "%int_or", _ -> int_binop l wrap Int.logor
      | "%int_xor", _ -> int_binop l wrap Int.logxor
      | "%int_lsl", _ -> shift l wrap Fun.id Int.shift_left
      | "%int_lsr", _ ->
          shift
            l
            wrap
            (match target with
            | `JavaScript -> Fun.id
            | `Wasm -> fun i -> Int.logand i 0x7fffffffl)
            Int.shift_right_logical
      | "%int_asr", _ -> shift l wrap Fun.id Int.shift_right
      | "%int_neg", [ Int i ] -> Some (Int (Int.neg i))
      (* float *)
      | "caml_eq_float", _ -> float_binop_bool l Float.( = )
      | "caml_neq_float", _ -> float_binop_bool l Float.( <> )
      | "caml_ge_float", _ -> float_binop_bool l Float.( >= )
      | "caml_le_float", _ -> float_binop_bool l Float.( <= )
      | "caml_gt_float", _ -> float_binop_bool l Float.( > )
      | "caml_lt_float", _ -> float_binop_bool l Float.( < )
      | "caml_add_float", _ -> float_binop l ( +. )
      | "caml_sub_float", _ -> float_binop l ( -. )
      | "caml_mul_float", _ -> float_binop l ( *. )
      | "caml_div_float", _ -> float_binop l ( /. )
      | "caml_fmod_float", _ -> float_binop l mod_float
      | "caml_int_of_float", [ Float f ] -> Some (Int (Int.of_float f))
      | "to_int", [ Float f ] -> Some (Int (Int.of_float f))
      | "to_int", [ Int i ] -> Some (Int i)
      (* Math *)
      | "caml_neg_float", _ -> float_unop l ( ~-. )
      | "caml_abs_float", _ -> float_unop l abs_float
      | "caml_acos_float", _ -> float_unop l acos
      | "caml_asin_float", _ -> float_unop l asin
      | "caml_atan_float", _ -> float_unop l atan
      | "caml_atan2_float", _ -> float_binop l atan2
      | "caml_ceil_float", _ -> float_unop l ceil
      | "caml_cos_float", _ -> float_unop l cos
      | "caml_exp_float", _ -> float_unop l exp
      | "caml_floor_float", _ -> float_unop l floor
      | "caml_log_float", _ -> float_unop l log
      | "caml_power_float", _ -> float_binop l ( ** )
      | "caml_sin_float", _ -> float_unop l sin
      | "caml_sqrt_float", _ -> float_unop l sqrt
      | "caml_tan_float", _ -> float_unop l tan
      | ("caml_string_get" | "caml_string_unsafe_get"), [ String s; Int pos ] ->
          let pos = Int32.to_int pos in
          if Config.Flag.safe_string () && pos >= 0 && pos < String.length s
          then Some (Int (Int32.of_int (Char.code s.[pos])))
          else None
      | "caml_string_equal", [ String s1; String s2 ] -> bool (String.equal s1 s2)
      | "caml_string_notequal", [ String s1; String s2 ] ->
          bool (not (String.equal s1 s2))
      | "caml_sys_getenv", [ String s ] -> (
          match get_static_env s with
          | Some env -> Some (String env)
          | None -> None)
      | "caml_sys_const_word_size", [ _ ] -> Some (Int 32l)
      | "caml_sys_const_int_size", [ _ ] ->
          Some
            (Int
               (match target with
               | `JavaScript -> 32l
               | `Wasm -> 31l))
      | "caml_sys_const_big_endian", [ _ ] -> Some (Int 0l)
      | "caml_sys_const_naked_pointers_checked", [ _ ] -> Some (Int 0l)
      | _ -> None)
  | _ -> None

let the_length_of info x =
  get_approx
    info
    (fun x ->
      match info.info_defs.(Var.idx x) with
      | Expr (Constant (String s)) -> Some (Int32.of_int (String.length s))
      | Expr (Prim (Extern "caml_create_string", [ arg ]))
      | Expr (Prim (Extern "caml_create_bytes", [ arg ])) -> the_int info arg
      | _ -> None)
    None
    (fun u v ->
      match u, v with
      | Some l, Some l' when Int32.(l = l') -> Some l
      | _ -> None)
    x

type is_int =
  | Y
  | N
  | Unknown

let is_int ~target info x =
  match x with
  | Pv x ->
      get_approx
        info
        (fun x ->
          match info.info_defs.(Var.idx x) with
          | Expr (Constant (Int _)) -> Y
          | Expr (Constant (Int32 _ | NativeInt _)) -> (
              match target with
              | `JavaScript -> Y
              | `Wasm -> N)
          | Expr (Block (_, _, _, _)) | Expr (Constant _) -> N
          | _ -> Unknown)
        Unknown
        (fun u v ->
          match u, v with
          | Y, Y -> Y
          | N, N -> N
          | _ -> Unknown)
        x
  | Pc (Int _) -> Y
  | Pc (Int32 _ | NativeInt _) -> (
      match target with
      | `JavaScript -> Y
      | `Wasm -> N)
  | Pc _ -> N

let the_tag_of info x get =
  match x with
  | Pv x ->
      get_approx
        info
        (fun x ->
          match info.info_defs.(Var.idx x) with
          | Expr (Block (j, _, _, _)) ->
              if Var.ISet.mem info.info_possibly_mutable x then None else get j
          | Expr (Constant (Tuple (j, _, _))) -> get j
          | _ -> None)
        None
        (fun u v ->
          match u, v with
          | Some i, Some j when Poly.(i = j) -> u
          | _ -> None)
        x
  | Pc (Tuple (j, _, _)) -> get j
  | _ -> None

let the_cont_of info x (a : cont array) =
  (* The value of [x] might be meaningless when we're inside a dead code.
     The proper fix would be to remove the deadcode entirely.
     Meanwhile, add guards to prevent Invalid_argument("index out of bounds")
     see https://github.com/ocsigen/js_of_ocaml/issues/485 *)
  let get i = if i >= 0 && i < Array.length a then Some a.(i) else None in
  get_approx
    info
    (fun x ->
      match info.info_defs.(Var.idx x) with
      | Expr (Prim (Extern "%direct_obj_tag", [ b ])) -> the_tag_of info b get
      | Expr (Constant (Int j)) -> get (Int32.to_int j)
      | _ -> None)
    None
    (fun u v ->
      match u, v with
      | Some i, Some j when Poly.(i = j) -> u
      | _ -> None)
    x

(* If [constant_js_equal a b = Some v], then [caml_js_equals a b = v]). *)
let constant_js_equal a b =
  match a, b with
  | Int i, Int j -> Some (Int32.equal i j)
  | Float a, Float b -> Some (Float.ieee_equal a b)
  | NativeString a, NativeString b -> Some (Native_string.equal a b)
  | String a, String b when Config.Flag.use_js_string () -> Some (String.equal a b)
  | Int _, Float _ | Float _, Int _ -> None
  (* All other values may be distinct objects and thus different by [caml_js_equals]. *)
  | String _, _
  | _, String _
  | NativeString _, _
  | _, NativeString _
  | Float_array _, _
  | _, Float_array _
  | Int64 _, _
  | _, Int64 _
  | Tuple _, _
  | _, Tuple _ -> None

let eval_instr ~target info ((x, loc) as i) =
  match x with
  | Let (x, Prim (Extern (("caml_equal" | "caml_notequal") as prim), [ y; z ])) -> (
      match the_const_of info y, the_const_of info z with
      | Some e1, Some e2 -> (
          match Code.Constant.ocaml_equal e1 e2 with
          | None -> [ i ]
          | Some c ->
              let c =
                match prim with
                | "caml_equal" -> c
                | "caml_notequal" -> not c
                | _ -> assert false
              in
              let c = Constant (bool' c) in
              Flow.update_def info x c;
              [ Let (x, c), loc ])
      | _ -> [ i ])
  | Let (x, Prim (Extern ("caml_js_equals" | "caml_js_strict_equals"), [ y; z ])) -> (
      match the_const_of info y, the_const_of info z with
      | Some e1, Some e2 -> (
          match constant_js_equal e1 e2 with
          | None -> [ i ]
          | Some c ->
              let c = Constant (bool' c) in
              Flow.update_def info x c;
              [ Let (x, c), loc ])
      | _ -> [ i ])
  | Let (x, Prim (Extern "caml_ml_string_length", [ s ])) -> (
      let c =
        match s with
        | Pc (String s) -> Some (Int32.of_int (String.length s))
        | Pv v -> the_length_of info v
        | _ -> None
      in
      match c with
      | None -> [ i ]
      | Some c ->
          let c = Constant (Int c) in
          Flow.update_def info x c;
          [ Let (x, c), loc ])
  | Let
      ( _
      , Prim
          ( ( Extern
                ( "caml_array_unsafe_get"
                | "caml_array_unsafe_set"
                | "caml_floatarray_unsafe_get"
                | "caml_floatarray_unsafe_set"
                | "caml_array_unsafe_set_addr" )
            | Array_get )
          , _ ) ) ->
      (* Fresh parameters can be introduced for these primitives
           in Specialize_js, which would make the call to [the_const_of]
           below fail. *)
      [ i ]
  | Let (x, Prim (IsInt, [ y ])) -> (
      match is_int ~target info y with
      | Unknown -> [ i ]
      | (Y | N) as b ->
          let c = Constant (bool' Poly.(b = Y)) in
          Flow.update_def info x c;
          [ Let (x, c), loc ])
  | Let (x, Prim (Extern "%direct_obj_tag", [ y ])) -> (
      match the_tag_of info y (fun x -> Some x) with
      | Some tag ->
          let c = Constant (Int (Int32.of_int tag)) in
          Flow.update_def info x c;
          [ Let (x, c), loc ]
      | None -> [ i ])
  | Let (x, Prim (Extern "caml_sys_const_backend_type", [ _ ])) ->
      let jsoo = Code.Var.fresh () in
      [ ( Let
            ( jsoo
            , Constant
                (String
                   (match target with
                   | `JavaScript -> "js_of_ocaml"
                   | `Wasm -> "wasm_of_ocaml")) )
        , noloc )
      ; Let (x, Block (0, [| jsoo |], NotArray, Immutable)), loc
      ]
  | Let (_, Prim (Extern ("%resume" | "%perform" | "%reperform"), _)) ->
      [ i ] (* We need that the arguments to this primitives remain variables *)
  | Let (x, Prim (prim, prim_args)) -> (
      let prim_args' = List.map prim_args ~f:(fun x -> the_const_of info x) in
      let res =
        if List.for_all prim_args' ~f:(function
               | Some _ -> true
               | _ -> false)
        then
          eval_prim
            ~target
            ( prim
            , List.map prim_args' ~f:(function
                  | Some c -> c
                  | None -> assert false) )
        else None
      in
      match res with
      | Some c ->
          let c = Constant c in
          Flow.update_def info x c;
          [ Let (x, c), loc ]
      | _ ->
          [ ( Let
                ( x
                , Prim
                    ( prim
                    , List.map2 prim_args prim_args' ~f:(fun arg c ->
                          match (c : constant option), target with
                          | Some ((Int _ | NativeString _) as c), _ -> Pc c
                          | Some (Float _ as c), `JavaScript -> Pc c
                          | Some (String _ as c), `JavaScript
                            when Config.Flag.use_js_string () -> Pc c
                          | Some _, _
                          (* do not be duplicated other constant as
                              they're not represented with constant in javascript. *)
                          | None, _ -> arg) ) )
            , loc )
          ])
  | _ -> [ i ]

type cond_of =
  | Zero
  | Non_zero
  | Unknown

let the_cond_of info x =
  get_approx
    info
    (fun x ->
      match info.info_defs.(Var.idx x) with
      | Expr (Constant (Int 0l)) -> Zero
      | Expr
          (Constant
            ( Int _
            | Int32 _
            | NativeInt _
            | Float _
            | Tuple _
            | String _
            | NativeString _
            | Float_array _
            | Int64 _ )) -> Non_zero
      | Expr (Block (_, _, _, _)) -> Non_zero
      | Expr (Field _ | Closure _ | Prim _ | Apply _ | Special _) -> Unknown
      | Param | Phi _ -> Unknown)
    Unknown
    (fun u v ->
      match u, v with
      | Zero, Zero -> Zero
      | Non_zero, Non_zero -> Non_zero
      | _ -> Unknown)
    x

let eval_branch info (l, loc) =
  let l =
    match l with
    | Cond (x, ftrue, ffalse) as b -> (
        if Poly.(ftrue = ffalse)
        then Branch ftrue
        else
          match the_cond_of info x with
          | Zero -> Branch ffalse
          | Non_zero -> Branch ftrue
          | Unknown -> b)
    | Switch (x, a) as b -> (
        match the_cont_of info x a with
        | Some cont -> Branch cont
        | None -> b)
    | _ as b -> b
  in
  l, loc

exception May_raise

let rec do_not_raise pc visited blocks =
  if Addr.Set.mem pc visited
  then visited
  else
    let visited = Addr.Set.add pc visited in
    let b = Addr.Map.find pc blocks in
    List.iter b.body ~f:(fun (i, _loc) ->
        match i with
        | Array_set (_, _, _) | Offset_ref (_, _) | Set_field (_, _, _, _) | Assign _ ->
            ()
        | Let (_, e) -> (
            match e with
            | Block (_, _, _, _) | Field (_, _, _) | Constant _ | Closure _ -> ()
            | Apply _ -> raise May_raise
            | Special _ -> ()
            | Prim (Extern name, _) when Primitive.is_pure name -> ()
            | Prim (Extern _, _) -> raise May_raise
            | Prim (_, _) -> ()));
    match fst b.branch with
    | Raise _ -> raise May_raise
    | Stop | Return _ | Poptrap _ -> visited
    | Branch (pc, _) -> do_not_raise pc visited blocks
    | Cond (_, (pc1, _), (pc2, _)) ->
        let visited = do_not_raise pc1 visited blocks in
        let visited = do_not_raise pc2 visited blocks in
        visited
    | Switch (_, a1) ->
        let visited =
          Array.fold_left a1 ~init:visited ~f:(fun visited (pc, _) ->
              do_not_raise pc visited blocks)
        in
        visited
    | Pushtrap _ -> raise May_raise

let drop_exception_handler blocks =
  Addr.Map.fold
    (fun pc _ blocks ->
      match Addr.Map.find pc blocks with
      | { branch = Pushtrap (((addr, _) as cont1), _x, _cont2), loc; _ } as b -> (
          try
            let visited = do_not_raise addr Addr.Set.empty blocks in
            let b = { b with branch = Branch cont1, loc } in
            let blocks = Addr.Map.add pc b blocks in
            let blocks =
              Addr.Set.fold
                (fun pc2 blocks ->
                  let b = Addr.Map.find pc2 blocks in
                  let branch =
                    match b.branch with
                    | Poptrap cont, loc -> Branch cont, loc
                    | x -> x
                  in
                  let b = { b with branch } in
                  Addr.Map.add pc2 b blocks)
                visited
                blocks
            in
            blocks
          with May_raise -> blocks)
      | _ -> blocks)
    blocks
    blocks

let eval ~target info blocks =
  Addr.Map.map
    (fun block ->
      let body = List.concat_map block.body ~f:(eval_instr ~target info) in
      let branch = eval_branch info block.branch in
      { block with Code.body; Code.branch })
    blocks

let f ~target info p =
  let blocks = eval ~target info p.blocks in
  let blocks = drop_exception_handler blocks in
  { p with blocks }
