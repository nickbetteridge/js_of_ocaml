(* Js_of_ocaml compiler
 * http://www.ocsigen.org/js_of_ocaml/
 * Copyright (C) 2010 Jérôme Vouillon
 * Laboratoire PPS - CNRS Université Paris Diderot
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

module Addr = struct
  type t = int

  module Set = Set.Make (Int)
  module Map = Map.Make (Int)

  let to_string = string_of_int

  let zero = 0

  let pred = pred

  let succ = succ
end

module DebugAddr : sig
  type t = private Addr.t

  val of_addr : Addr.t -> t

  val to_addr : t -> Addr.t

  val no : t
end = struct
  type t = int

  let of_addr (x : Addr.t) : t = x

  let no = 0

  let to_addr (x : t) : Addr.t = x
end

module Var : sig
  type t [@@ocaml.immediate]

  val print : Format.formatter -> t -> unit

  val equal : t -> t -> bool

  val idx : t -> int

  val of_idx : int -> t

  val to_string : ?origin:t -> t -> string

  val fresh : unit -> t

  val fresh_n : string -> t

  val fork : t -> t

  val count : unit -> int

  val compare : t -> t -> int

  val name : t -> string -> unit

  val get_name : t -> string option

  val propagate_name : t -> t -> unit

  val reset : unit -> unit

  val set_pretty : bool -> unit

  val set_stable : bool -> unit

  module Set : Set.S with type elt = t

  module Map : Map.S with type key = t

  module Hashtbl : Hashtbl.S with type key = t

  module Tbl : sig
    type key = t

    type 'a t

    type size = unit

    val get : 'a t -> key -> 'a

    val set : 'a t -> key -> 'a -> unit

    val length : 'a t -> int

    val make : size -> 'a -> 'a t

    val iter : (key -> 'a -> unit) -> 'a t -> unit
  end

  module ISet : sig
    type elt = t

    type t

    val empty : unit -> t

    val iter : (elt -> unit) -> t -> unit

    val mem : t -> elt -> bool

    val add : t -> elt -> unit

    val remove : t -> elt -> unit

    val copy : t -> t
  end
end = struct
  module T = struct
    type t = int

    let compare : t -> t -> int = compare

    let equal (a : t) (b : t) = a = b

    let hash x = x
  end

  include T

  let printer = Var_printer.create Var_printer.Alphabet.javascript

  let last_var = ref 0

  let reset () =
    last_var := 0;
    Var_printer.reset printer

  let to_string ?origin i = Var_printer.to_string printer ?origin i

  let print f x = Format.fprintf f "v%d" x

  (* Format.fprintf f "%s" (to_string x) *)

  let name i nm = Var_printer.name printer i nm

  let fresh () =
    incr last_var;
    !last_var

  let fresh_n nm =
    incr last_var;
    name !last_var nm;
    !last_var

  let count () = !last_var + 1

  let idx v = v

  let of_idx v = v

  let get_name i = Var_printer.get_name printer i

  let propagate_name i j = Var_printer.propagate_name printer i j

  let set_pretty b = Var_printer.set_pretty printer b

  let set_stable b = Var_printer.set_stable printer b

  let fork o =
    let n = fresh () in
    propagate_name o n;
    n

  module Set = Set.Make (T)
  module Map = Map.Make (T)

  module Tbl = struct
    type 'a t = 'a array

    type key = T.t

    type size = unit

    let get t x = t.(x)

    let set t x v = t.(x) <- v

    let length t = Array.length t

    let make () v = Array.make (count ()) v

    let iter f t =
      for i = 0 to Array.length t - 1 do
        f i (Array.unsafe_get t i)
      done
  end

  module Hashtbl = Hashtbl.Make (T)

  module ISet = struct
    type t = BitSet.t

    type elt = T.t

    let iter f t = BitSet.iter ~f t

    let mem t x = BitSet.mem t x

    let add t (x : int) = BitSet.set t x

    let remove t x = BitSet.unset t x

    let copy = BitSet.copy

    let empty _v = BitSet.create' (count ())
  end
end

type cont = Addr.t * Var.t list

type prim =
  | Vectlength
  | Array_get
  | Extern of string
  | Not
  | IsInt
  | Eq
  | Neq
  | Lt
  | Le
  | Ult

type array_or_not =
  | Array
  | NotArray
  | Unknown

module Native_string = struct
  type t =
    | Byte of string
    | Utf of Utf8_string.t

  let of_string x = Utf (Utf8_string.of_string_exn x)

  let of_bytestring x = if String.is_ascii x then of_string x else Byte x

  let equal a b =
    match a, b with
    | Byte x, Byte y -> String.equal x y
    | Utf (Utf8 x), Utf (Utf8 y) -> String.equal x y
    | Utf _, Byte _ | Byte _, Utf _ -> false
end

type constant =
  | String of string
  | NativeString of Native_string.t
  | Float of float
  | Float_array of float array
  | Int of Targetint.t
  | Int32 of Int32.t
  | Int64 of Int64.t
  | NativeInt of Int32.t (* Native int are 32bit on all known backend *)
  | Tuple of int * constant array * array_or_not

module Constant = struct
  type t = constant

  let rec ocaml_equal a b =
    match a, b with
    | String a, String b -> Some (String.equal a b)
    | NativeString a, NativeString b -> Some (Native_string.equal a b)
    | Tuple (ta, a, _), Tuple (tb, b, _) ->
        if ta <> tb || Array.length a <> Array.length b
        then Some false
        else
          let same = ref (Some true) in
          for i = 0 to Array.length a - 1 do
            match !same, ocaml_equal a.(i) b.(i) with
            | None, _ -> ()
            | _, None -> same := None
            | Some s, Some c -> same := Some (s && c)
          done;
          !same
    | Int a, Int b -> Some (Targetint.equal a b)
    | Int32 a, Int32 b -> Some (Int32.equal a b)
    | Int64 a, Int64 b -> Some (Int64.equal a b)
    | NativeInt a, NativeInt b -> Some (Int32.equal a b)
    | Float_array a, Float_array b -> Some (Array.equal Float.ieee_equal a b)
    | Float a, Float b -> Some (Float.ieee_equal a b)
    | String _, NativeString _ | NativeString _, String _ -> None
    | Int _, Float _ | Float _, Int _ -> None
    | Tuple ((0 | 254), _, _), Float_array _ -> None
    | Float_array _, Tuple ((0 | 254), _, _) -> None
    | ( Tuple _
      , ( String _
        | NativeString _
        | Int64 _
        | Int _
        | Int32 _
        | NativeInt _
        | Float _
        | Float_array _ ) ) -> Some false
    | ( Float_array _
      , ( String _
        | NativeString _
        | Int64 _
        | Int _
        | Int32 _
        | NativeInt _
        | Float _
        | Tuple _ ) ) -> Some false
    | ( String _
      , (Int64 _ | Int _ | Int32 _ | NativeInt _ | Float _ | Tuple _ | Float_array _) ) ->
        Some false
    | ( NativeString _
      , (Int64 _ | Int _ | Int32 _ | NativeInt _ | Float _ | Tuple _ | Float_array _) ) ->
        Some false
    | ( Int64 _
      , ( String _
        | NativeString _
        | Int _
        | Int32 _
        | NativeInt _
        | Float _
        | Tuple _
        | Float_array _ ) ) -> Some false
    | Float _, (String _ | NativeString _ | Float_array _ | Int64 _ | Tuple (_, _, _)) ->
        Some false
    | ( (Int _ | Int32 _ | NativeInt _)
      , (String _ | NativeString _ | Float_array _ | Int64 _ | Tuple (_, _, _)) ) ->
        Some false
    (* Note: the following cases should not occur when compiling to Javascript *)
    | Int _, (Int32 _ | NativeInt _)
    | Int32 _, (Int _ | NativeInt _)
    | NativeInt _, (Int _ | Int32 _)
    | (Int32 _ | NativeInt _), Float _
    | Float _, (Int32 _ | NativeInt _) -> None
end

type loc =
  | No
  | Before of Addr.t
  | After of Addr.t

type prim_arg =
  | Pv of Var.t
  | Pc of constant

type special = Alias_prim of string

type mutability =
  | Immutable
  | Maybe_mutable

type field_type =
  | Non_float
  | Float

type expr =
  | Apply of
      { f : Var.t
      ; args : Var.t list
      ; exact : bool
      }
  | Block of int * Var.t array * array_or_not * mutability
  | Field of Var.t * int * field_type
  | Closure of Var.t list * cont
  | Constant of constant
  | Prim of prim * prim_arg list
  | Special of special

type instr =
  | Let of Var.t * expr
  | Assign of Var.t * Var.t
  | Set_field of Var.t * int * field_type * Var.t
  | Offset_ref of Var.t * int
  | Array_set of Var.t * Var.t * Var.t
  | Event of Parse_info.t

type last =
  | Return of Var.t
  | Raise of Var.t * [ `Normal | `Notrace | `Reraise ]
  | Stop
  | Branch of cont
  | Cond of Var.t * cont * cont
  | Switch of Var.t * cont array
  | Pushtrap of cont * Var.t * cont
  | Poptrap of cont

type block =
  { params : Var.t list
  ; body : instr list
  ; branch : last
  }

type program =
  { start : Addr.t
  ; blocks : block Addr.Map.t
  ; free_pc : Addr.t
  }

let noloc = No

let location_of_pc pc = Before pc
(****)

module Print = struct
  let rec list pr f l =
    match l with
    | [] -> ()
    | [ x ] -> pr f x
    | x :: r -> Format.fprintf f "%a, %a" pr x (list pr) r

  let var_list = list Var.print

  let cont f (pc, args) = Format.fprintf f "%d (%a)" pc var_list args

  let rec constant f x =
    match x with
    | String s -> Format.fprintf f "%S" s
    | NativeString (Byte s) -> Format.fprintf f "%Sj" s
    | NativeString (Utf (Utf8 s)) -> Format.fprintf f "%Sj" s
    | Float fl -> Format.fprintf f "%.12g" fl
    | Float_array a ->
        Format.fprintf f "[|";
        for i = 0 to Array.length a - 1 do
          if i > 0 then Format.fprintf f ", ";
          Format.fprintf f "%.12g" a.(i)
        done;
        Format.fprintf f "|]"
    | Int i -> Format.fprintf f "%s" (Targetint.to_string i)
    | Int32 i -> Format.fprintf f "%ldl" i
    | Int64 i -> Format.fprintf f "%LdL" i
    | NativeInt i -> Format.fprintf f "%ldn" i
    | Tuple (tag, a, _) -> (
        Format.fprintf f "<%d>" tag;
        match Array.length a with
        | 0 -> ()
        | 1 ->
            Format.fprintf f "(";
            constant f a.(0);
            Format.fprintf f ")"
        | n ->
            Format.fprintf f "(";
            constant f a.(0);
            for i = 1 to n - 1 do
              Format.fprintf f ", ";
              constant f a.(i)
            done;
            Format.fprintf f ")")

  let arg f a =
    match a with
    | Pv x -> Var.print f x
    | Pc c -> constant f c

  let binop s =
    match s with
    | "%int_add" -> "+"
    | "%int_sub" -> "-"
    | "%int_mul" -> "*"
    | "%int_div" -> "/"
    | "%int_mod" -> "%"
    | "%int_and" -> "&"
    | "%int_or" -> "|"
    | "%int_xor" -> "^"
    | "%int_lsl" -> "<<"
    | "%int_lsr" -> ">>>"
    | "%int_asr" -> ">>"
    | _ -> raise Not_found

  let unop s =
    match s with
    | "%int_neg" -> "-"
    | _ -> raise Not_found

  let prim f p l =
    match p, l with
    | Vectlength, [ x ] -> Format.fprintf f "%a.length" arg x
    | Array_get, [ x; y ] -> Format.fprintf f "%a[%a]" arg x arg y
    | Extern s, [ x; y ] -> (
        try Format.fprintf f "%a %s %a" arg x (binop s) arg y
        with Not_found -> Format.fprintf f "\"%s\"(%a)" s (list arg) l)
    | Extern s, [ x ] -> (
        try Format.fprintf f "%s %a" (unop s) arg x
        with Not_found -> Format.fprintf f "\"%s\"(%a)" s (list arg) l)
    | Extern s, _ -> Format.fprintf f "\"%s\"(%a)" s (list arg) l
    | Not, [ x ] -> Format.fprintf f "!%a" arg x
    | IsInt, [ x ] -> Format.fprintf f "is_int(%a)" arg x
    | Eq, [ x; y ] -> Format.fprintf f "%a === %a" arg x arg y
    | Neq, [ x; y ] -> Format.fprintf f "!(%a === %a)" arg x arg y
    | Lt, [ x; y ] -> Format.fprintf f "%a < %a" arg x arg y
    | Le, [ x; y ] -> Format.fprintf f "%a <= %a" arg x arg y
    | Ult, [ x; y ] -> Format.fprintf f "%a <= %a" arg x arg y
    | _ -> assert false

  let special f s =
    match s with
    | Alias_prim s -> Format.fprintf f "alias %s" s

  let expr f e =
    match e with
    | Apply { f = g; args; exact } ->
        if exact
        then Format.fprintf f "%a!(%a)" Var.print g var_list args
        else Format.fprintf f "%a(%a)" Var.print g var_list args
    | Block (t, a, _, mut) ->
        Format.fprintf
          f
          "%s{tag=%d"
          (match mut with
          | Immutable -> "imm"
          | Maybe_mutable -> "")
          t;
        for i = 0 to Array.length a - 1 do
          Format.fprintf f "; %d = %a" i Var.print a.(i)
        done;
        Format.fprintf f "}"
    | Field (x, i, Non_float) -> Format.fprintf f "%a[%d]" Var.print x i
    | Field (x, i, Float) -> Format.fprintf f "FLOAT{%a[%d]}" Var.print x i
    | Closure (l, c) -> Format.fprintf f "fun(%a){%a}" var_list l cont c
    | Constant c -> Format.fprintf f "CONST{%a}" constant c
    | Prim (p, l) -> prim f p l
    | Special s -> special f s

  let instr f i =
    match i with
    | Let (x, e) -> Format.fprintf f "%a = %a" Var.print x expr e
    | Assign (x, y) -> Format.fprintf f "(assign) %a = %a" Var.print x Var.print y
    | Set_field (x, i, Non_float, y) ->
        Format.fprintf f "%a[%d] = %a" Var.print x i Var.print y
    | Set_field (x, i, Float, y) ->
        Format.fprintf f "FLOAT{%a[%d]} = %a" Var.print x i Var.print y
    | Offset_ref (x, i) -> Format.fprintf f "%a[0] += %d" Var.print x i
    | Array_set (x, y, z) ->
        Format.fprintf f "%a[%a] = %a" Var.print x Var.print y Var.print z
    | Event loc -> Format.fprintf f "event %s" (Parse_info.to_string loc)

  let last f l =
    match l with
    | Return x -> Format.fprintf f "return %a" Var.print x
    | Raise (x, `Normal) -> Format.fprintf f "raise %a" Var.print x
    | Raise (x, `Reraise) -> Format.fprintf f "reraise %a" Var.print x
    | Raise (x, `Notrace) -> Format.fprintf f "raise_notrace %a" Var.print x
    | Stop -> Format.fprintf f "stop"
    | Branch c -> Format.fprintf f "branch %a" cont c
    | Cond (x, cont1, cont2) ->
        Format.fprintf f "if %a then %a else %a" Var.print x cont cont1 cont cont2
    | Switch (x, a1) ->
        Format.fprintf f "switch %a {" Var.print x;
        Array.iteri a1 ~f:(fun i c -> Format.fprintf f "int %d -> %a; " i cont c);
        Format.fprintf f "}"
    | Pushtrap (cont1, x, cont2) ->
        Format.fprintf f "pushtrap %a handler %a => %a" cont cont1 Var.print x cont cont2
    | Poptrap c -> Format.fprintf f "poptrap %a" cont c

  type xinstr =
    | Instr of instr
    | Last of last

  let block annot pc block =
    Format.eprintf "==== %d (%a) ====@." pc var_list block.params;
    List.iter block.body ~f:(fun i ->
        Format.eprintf " %s %a@." (annot pc (Instr i)) instr i);
    Format.eprintf " %s %a@." (annot pc (Last block.branch)) last block.branch;
    Format.eprintf "@."

  let program annot { start; blocks; _ } =
    Format.eprintf "Entry point: %d@.@." start;
    Addr.Map.iter (block annot) blocks
end

(****)

let fold_closures p f accu =
  Addr.Map.fold
    (fun _ block accu ->
      List.fold_left block.body ~init:accu ~f:(fun accu i ->
          match i with
          | Let (x, Closure (params, cont)) -> f (Some x) params cont accu
          | _ -> accu))
    p.blocks
    (f None [] (p.start, []) accu)

(****)

let prepend ({ start; blocks; free_pc } as p) body =
  match body with
  | [] -> p
  | _ -> (
      match Addr.Map.find start blocks with
      | block ->
          { p with
            blocks = Addr.Map.add start { block with body = body @ block.body } blocks
          }
      | exception Not_found ->
          let new_start = free_pc in
          let blocks =
            Addr.Map.add new_start { params = []; body; branch = Stop } blocks
          in
          let free_pc = free_pc + 1 in
          { start = new_start; blocks; free_pc })

let empty_block = { params = []; body = []; branch = Stop }

let empty =
  let start = 0 in
  let blocks = Addr.Map.singleton start empty_block in
  { start; blocks; free_pc = start + 1 }

let is_empty p =
  match Addr.Map.cardinal p.blocks with
  | 0 -> true
  | 1 -> (
      let _, v = Addr.Map.choose p.blocks in
      match v with
      | { body; branch = Stop; params = _ } -> (
          match body with
          | ([] | [ Let (_, Prim (Extern "caml_get_global_data", _)) ]) when true -> true
          | _ -> false)
      | _ -> false)
  | _ -> false

let poptraps blocks pc =
  let rec loop blocks pc visited depth acc =
    if Addr.Set.mem pc visited
    then acc, visited
    else
      let visited = Addr.Set.add pc visited in
      let block = Addr.Map.find pc blocks in
      match block.branch with
      | Return _ | Raise _ | Stop -> acc, visited
      | Branch (pc', _) -> loop blocks pc' visited depth acc
      | Poptrap (pc', _) ->
          if depth = 0
          then Addr.Set.add pc' acc, visited
          else loop blocks pc' visited (depth - 1) acc
      | Pushtrap ((pc', _), _, (pc_h, _)) ->
          let acc, visited = loop blocks pc' visited (depth + 1) acc in
          let acc, visited = loop blocks pc_h visited depth acc in
          acc, visited
      | Cond (_, (pc1, _), (pc2, _)) ->
          let acc, visited = loop blocks pc1 visited depth acc in
          let acc, visited = loop blocks pc2 visited depth acc in
          acc, visited
      | Switch (_, a) ->
          let acc, visited =
            Array.fold_right
              ~init:(acc, visited)
              ~f:(fun (pc, _) (acc, visited) -> loop blocks pc visited depth acc)
              a
          in
          acc, visited
  in
  loop blocks pc Addr.Set.empty 0 Addr.Set.empty |> fst

let fold_children blocks pc f accu =
  let block = Addr.Map.find pc blocks in
  match block.branch with
  | Return _ | Raise _ | Stop -> accu
  | Branch (pc', _) | Poptrap (pc', _) -> f pc' accu
  | Pushtrap ((pc', _), _, (pc_h, _)) ->
      let accu = f pc' accu in
      let accu = f pc_h accu in
      accu
  | Cond (_, (pc1, _), (pc2, _)) ->
      let accu = f pc1 accu in
      let accu = f pc2 accu in
      accu
  | Switch (_, a1) ->
      let accu = Array.fold_right ~init:accu ~f:(fun (pc, _) accu -> f pc accu) a1 in
      accu

let fold_children_skip_try_body blocks pc f accu =
  let block = Addr.Map.find pc blocks in
  match block.branch with
  | Return _ | Raise _ | Stop -> accu
  | Branch (pc', _) | Poptrap (pc', _) -> f pc' accu
  | Pushtrap ((pc', _), _, (pc_h, _)) ->
      let accu = Addr.Set.fold f (poptraps blocks pc') accu in
      let accu = f pc_h accu in
      accu
  | Cond (_, (pc1, _), (pc2, _)) ->
      let accu = f pc1 accu in
      let accu = f pc2 accu in
      accu
  | Switch (_, a1) ->
      let accu = Array.fold_right ~init:accu ~f:(fun (pc, _) accu -> f pc accu) a1 in
      accu

type 'c fold_blocs = block Addr.Map.t -> Addr.t -> (Addr.t -> 'c -> 'c) -> 'c -> 'c

type fold_blocs_poly = { fold : 'a. 'a fold_blocs } [@@unboxed]

let rec traverse' { fold } f pc visited blocks acc =
  if not (Addr.Set.mem pc visited)
  then
    let visited = Addr.Set.add pc visited in
    let visited, acc =
      fold
        blocks
        pc
        (fun pc (visited, acc) ->
          let visited, acc = traverse' { fold } f pc visited blocks acc in
          visited, acc)
        (visited, acc)
    in
    let acc = f pc acc in
    visited, acc
  else visited, acc

let traverse fold f pc blocks acc = snd (traverse' fold f pc Addr.Set.empty blocks acc)

let rec preorder_traverse' { fold } f pc visited blocks acc =
  if not (Addr.Set.mem pc visited)
  then
    let visited = Addr.Set.add pc visited in
    let acc = f pc acc in
    fold
      blocks
      pc
      (fun pc (visited, acc) ->
        let visited, acc = preorder_traverse' { fold } f pc visited blocks acc in
        visited, acc)
      (visited, acc)
  else visited, acc

let preorder_traverse fold f pc blocks acc =
  snd (preorder_traverse' fold f pc Addr.Set.empty blocks acc)

let fold_closures_innermost_first { start; blocks; _ } f accu =
  let rec visit blocks pc f accu =
    traverse
      { fold = fold_children }
      (fun pc accu ->
        let block = Addr.Map.find pc blocks in
        List.fold_left block.body ~init:accu ~f:(fun accu i ->
            match i with
            | Let (x, Closure (params, cont)) ->
                let accu = visit blocks (fst cont) f accu in
                f (Some x) params cont accu
            | _ -> accu))
      pc
      blocks
      accu
  in
  let accu = visit blocks start f accu in
  f None [] (start, []) accu

let fold_closures_outermost_first { start; blocks; _ } f accu =
  let rec visit blocks pc f accu =
    traverse
      { fold = fold_children }
      (fun pc accu ->
        let block = Addr.Map.find pc blocks in
        List.fold_left block.body ~init:accu ~f:(fun accu i ->
            match i with
            | Let (x, Closure (params, cont)) ->
                let accu = f (Some x) params cont accu in
                visit blocks (fst cont) f accu
            | _ -> accu))
      pc
      blocks
      accu
  in
  let accu = f None [] (start, []) accu in
  visit blocks start f accu

let eq p1 p2 =
  p1.start = p2.start
  && Addr.Map.cardinal p1.blocks = Addr.Map.cardinal p2.blocks
  && Addr.Map.fold
       (fun pc block1 b ->
         b
         &&
         try
           let block2 = Addr.Map.find pc p2.blocks in
           Poly.(block1.params = block2.params)
           && Poly.(block1.branch = block2.branch)
           && Poly.(block1.body = block2.body)
         with Not_found -> false)
       p1.blocks
       true

let with_invariant = Debug.find "invariant"

let check_defs = false

let invariant { blocks; start; _ } =
  let target = Config.target () in
  if with_invariant ()
  then (
    assert (Addr.Map.mem start blocks);
    let defs = Var.ISet.empty () in
    let check_cont (cont, args) =
      let b = Addr.Map.find cont blocks in
      assert (List.length args = List.length b.params)
    in
    let define x =
      if check_defs
      then (
        assert (not (Var.ISet.mem defs x));
        Var.ISet.add defs x)
    in
    let check_constant = function
      | NativeInt _ | Int32 _ ->
          assert (
            match target with
            | `Wasm -> true
            | _ -> false)
      | String _ | NativeString _ | Float _ | Float_array _ | Int _ | Int64 _
      | Tuple (_, _, _) -> ()
    in
    let check_prim_arg = function
      | Pc c -> check_constant c
      | Pv _ -> ()
    in
    let check_expr = function
      | Apply _ -> ()
      | Block (_, _, _, _) -> ()
      | Field (_, _, _) -> ()
      | Closure (l, cont) ->
          List.iter l ~f:define;
          check_cont cont
      | Constant c -> check_constant c
      | Prim (_, args) -> List.iter ~f:check_prim_arg args
      | Special _ -> ()
    in
    let check_instr i =
      match i with
      | Let (x, e) ->
          define x;
          check_expr e
      | Assign _ -> ()
      | Set_field (_, _i, _, _) -> ()
      | Offset_ref (_x, _i) -> ()
      | Array_set (_x, _y, _z) -> ()
      | Event _ -> ()
    in
    let rec check_events l =
      match l with
      | Event _ :: Event _ :: _ -> assert false
      | _ :: r -> check_events r
      | [] -> ()
    in
    let check_last l =
      match l with
      | Return _ -> ()
      | Raise _ -> ()
      | Stop -> ()
      | Branch cont -> check_cont cont
      | Cond (_x, cont1, cont2) ->
          check_cont cont1;
          check_cont cont2
      | Switch (_x, a1) -> Array.iteri a1 ~f:(fun _ cont -> check_cont cont)
      | Pushtrap (cont1, _x, cont2) ->
          check_cont cont1;
          check_cont cont2
      | Poptrap cont -> check_cont cont
    in
    Addr.Map.iter
      (fun _pc block ->
        List.iter block.params ~f:define;
        List.iter block.body ~f:check_instr;
        check_events block.body;
        check_last block.branch)
      blocks)
