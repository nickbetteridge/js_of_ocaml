(* TEST
 modules = "intextaux.c";
*)

(* Test for output_value / input_value *)

let max_data_depth = 500000

type t = A | B of int | C of float | D of string | E of char
       | F of t | G of t * t | H of int * t | I of t * float | J

let longstring =
"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
let verylongstring =
"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\
 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\
 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\
 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\
 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\
 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\
 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz\
 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

let bigint = Int64.to_int 0x123456789ABCDEF0L

let rec fib n =
  if n < 2 then 1 else fib(n-1) + fib(n-2)

let test_out ?(flags = []) filename =
  let oc = open_out_bin filename in
  Marshal.to_channel oc 1 flags;
  Marshal.to_channel oc (-1) flags;
  Marshal.to_channel oc 258 flags;
  Marshal.to_channel oc 20000 flags;
  Marshal.to_channel oc 0x12345678 flags;
  Marshal.to_channel oc bigint flags;
  Marshal.to_channel oc "foobargeebuz" flags;
  Marshal.to_channel oc longstring flags;
  Marshal.to_channel oc verylongstring flags;
  Marshal.to_channel oc 3.141592654 flags;
  Marshal.to_channel oc () flags;
  Marshal.to_channel oc A flags;
  Marshal.to_channel oc (B 1) flags;
  Marshal.to_channel oc (C 2.718) flags;
  Marshal.to_channel oc (D "hello, world!") flags;
  Marshal.to_channel oc (E 'l') flags;
  Marshal.to_channel oc (F(B 1)) flags;
  Marshal.to_channel oc (G(A, G(B 2, G(C 3.14, G(D "glop", E 'e'))))) flags;
  Marshal.to_channel oc (H(1, A)) flags;
  Marshal.to_channel oc (I(B 2, 1e-6)) flags;
  let x = D "sharing" in
  let y = G(x, x) in
  let z = G(y, G(x, y)) in
  Marshal.to_channel oc z flags;
  Marshal.to_channel oc [|1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16|] flags;
  let rec big n = if n <= 0 then A else H(n, big(n-1)) in
  Marshal.to_channel oc (big 1000) flags;
  Marshal.to_channel oc y (Marshal.No_sharing :: flags);
  if false then Marshal.to_channel oc fib (Marshal.Closures :: flags);
  Marshal.to_channel oc (Int32.of_string "0") flags;
  Marshal.to_channel oc (Int32.of_string "123456") flags;
  Marshal.to_channel oc (Int32.of_string "-123456") flags;
  Marshal.to_channel oc (Int64.of_string "0") flags;
  Marshal.to_channel oc (Int64.of_string "123456789123456") flags;
  Marshal.to_channel oc (Int64.of_string "-123456789123456") flags;
  Marshal.to_channel oc (Nativeint.of_string "0") flags;
  Marshal.to_channel oc (Nativeint.of_string "123456") flags;
  Marshal.to_channel oc (Nativeint.of_string "-123456") flags;
  Marshal.to_channel oc
    (Nativeint.shift_left (Nativeint.of_string "123456789") 32) flags;
  Marshal.to_channel oc
    (Nativeint.shift_left (Nativeint.of_string "-123456789") 32) flags;
  let i = Int64.of_string "123456789123456" in
    Marshal.to_channel oc (i,i) flags;
  close_out oc


let test n b =
  print_string "Test "; print_int n;
  if b then print_string " passed.\n" else print_string " FAILED.\n";
  flush stderr

let test_in filename =
  let ic = open_in_bin filename in
  test 1 (input_value ic = 1);
  test 2 (input_value ic = (-1));
  test 3 (input_value ic = 258);
  test 4 (input_value ic = 20000);
  test 5 (input_value ic = 0x12345678);
  test 6 (input_value ic = bigint);
  test 7 (input_value ic = "foobargeebuz");
  test 8 (input_value ic = longstring);
  test 9 (input_value ic = verylongstring);
  test 10 (input_value ic = 3.141592654);
  test 11 (input_value ic = ());
  test 12 (match input_value ic with
    A -> true
  | _ -> false);
  test 13 (match input_value ic with
    (B 1) -> true
  | _ -> false);
  test 14 (match input_value ic with
    (C f) -> f = 2.718
  | _ -> false);
  test 15 (match input_value ic with
    (D "hello, world!") -> true
  | _ -> false);
  test 16 (match input_value ic with
    (E 'l') -> true
  | _ -> false);
  test 17 (match input_value ic with
    (F(B 1)) -> true
  | _ -> false);
  test 18 (match input_value ic with
    (G(A, G(B 2, G(C 3.14, G(D "glop", E 'e'))))) -> true
  | _ -> false);
  test 19 (match input_value ic with
    (H(1, A)) -> true
  | _ -> false);
  test 20 (match input_value ic with
    (I(B 2, 1e-6)) -> true
  | _ -> false);
  test 21 (match input_value ic with
    G((G((D "sharing" as t1), t2) as t3), G(t4, t5)) ->
      t1 == t2 && t3 == t5 && t4 == t1
  | _ -> false);
  test 22 (input_value ic = [|1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16|]);
  let rec check_big n t =
    if n <= 0 then
      test 23 (match t with A -> true | _ -> false)
    else
      match t with H(m, s) -> if m = n then check_big (n-1) s
                                       else test 23 false
                 | _ -> test 23 false
  in
    check_big 1000 (input_value ic);
  test 24 (match input_value ic with
    G((D "sharing" as t1), (D "sharing" as t2)) -> t1 != t2
  | _ -> false);
  if false then test 25 (let fib = (input_value ic : int -> int) in fib 5 = 8 && fib 10 = 89);
  test 26 (input_value ic = Int32.of_string "0");
  test 27 (input_value ic = Int32.of_string "123456");
  test 28 (input_value ic = Int32.of_string "-123456");
  test 29 (input_value ic = Int64.of_string "0");
  test 30 (input_value ic = Int64.of_string "123456789123456");
  test 31 (input_value ic = Int64.of_string "-123456789123456");
  test 32 (input_value ic = Nativeint.of_string "0");
  test 33 (input_value ic = Nativeint.of_string "123456");
  test 34 (input_value ic = Nativeint.of_string "-123456");
  test 35 (input_value ic =
             Nativeint.shift_left (Nativeint.of_string "123456789") 32);
  test 36 (input_value ic =
             Nativeint.shift_left (Nativeint.of_string "-123456789") 32);
  let ((i, j) : int64 * int64) = input_value ic in
  test 37 (i = Int64.of_string "123456789123456");
  test 38 (j = Int64.of_string "123456789123456");
  test 39 (i == j);
  close_in ic

let test_string () =
  let s = Marshal.to_string 1 [] in
  test 101 (Marshal.from_string s 0 = 1);
  let s = Marshal.to_string (-1) [] in
  test 102 (Marshal.from_string s 0 = (-1));
  let s = Marshal.to_string 258 [] in
  test 103 (Marshal.from_string s 0 = 258);
  let s = Marshal.to_string 20000 [] in
  test 104 (Marshal.from_string s 0 = 20000);
  let s = Marshal.to_string 0x12345678 [] in
  test 105 (Marshal.from_string s 0 = 0x12345678);
  let s = Marshal.to_string bigint [] in
  test 106 (Marshal.from_string s 0 = bigint);
  let s = Marshal.to_string "foobargeebuz" [] in
  test 107 (Marshal.from_string s 0 = "foobargeebuz");
  let s = Marshal.to_string longstring [] in
  test 108 (Marshal.from_string s 0 = longstring);
  let s = Marshal.to_string verylongstring [] in
  test 109 (Marshal.from_string s 0 = verylongstring);
  let s = Marshal.to_string 3.141592654 [] in
  test 110 (Marshal.from_string s 0 = 3.141592654);
  let s = Marshal.to_string () [] in
  test 111 (Marshal.from_string s 0 = ());
  let s = Marshal.to_string A [] in
  test 112 (match Marshal.from_string s 0 with
    A -> true
  | _ -> false);
  let s = Marshal.to_string (B 1) [] in
  test 113 (match Marshal.from_string s 0 with
    (B 1) -> true
  | _ -> false);
  let s = Marshal.to_string (C 2.718) [] in
  test 114 (match Marshal.from_string s 0 with
    (C f) -> f = 2.718
  | _ -> false);
  let s = Marshal.to_string (D "hello, world!") [] in
  test 115 (match Marshal.from_string s 0 with
    (D "hello, world!") -> true
  | _ -> false);
  let s = Marshal.to_string (E 'l') [] in
  test 116 (match Marshal.from_string s 0 with
    (E 'l') -> true
  | _ -> false);
  let s = Marshal.to_string (F(B 1)) [] in
  test 117 (match Marshal.from_string s 0 with
    (F(B 1)) -> true
  | _ -> false);
  let s = Marshal.to_string (G(A, G(B 2, G(C 3.14, G(D "glop", E 'e'))))) [] in
  test 118 (match Marshal.from_string s 0 with
    (G(A, G(B 2, G(C 3.14, G(D "glop", E 'e'))))) -> true
  | _ -> false);
  let s = Marshal.to_string (H(1, A)) [] in
  test 119 (match Marshal.from_string s 0 with
    (H(1, A)) -> true
  | _ -> false);
  let s = Marshal.to_string (I(B 2, 1e-6)) [] in
  test 120 (match Marshal.from_string s 0 with
    (I(B 2, 1e-6)) -> true
  | _ -> false);
  let x = D "sharing" in
  let y = G(x, x) in
  let z = G(y, G(x, y)) in
  let s = Marshal.to_string z [] in
  test 121 (match Marshal.from_string s 0 with
    G((G((D "sharing" as t1), t2) as t3), G(t4, t5)) ->
      t1 == t2 && t3 == t5 && t4 == t1
  | _ -> false);
  let s = Marshal.to_string [|1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16|] [] in
  test 122
       (Marshal.from_string s 0 = [|1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16|]);
  let rec big n = if n <= 0 then A else H(n, big(n-1)) in
  let s = Marshal.to_string (big 1000) [] in
  let rec check_big n t =
    if n <= 0 then
      test 123 (match t with A -> true | _ -> false)
    else
      match t with H(m, s) -> if m = n then check_big (n-1) s
                                       else test 123 false
                 | _ -> test 123 false
  in
    check_big 1000 (Marshal.from_string s 0)

let marshal_to_buffer s start len v flags =
  ignore (Marshal.to_buffer s start len v flags)

let test_buffer () =
  let s = Bytes.create 512 in
  marshal_to_buffer s 0 512 1 [];
  test 201 (Marshal.from_bytes s 0 = 1);
  marshal_to_buffer s 0 512 (-1) [];
  test 202 (Marshal.from_bytes s 0 = (-1));
  marshal_to_buffer s 0 512 258 [];
  test 203 (Marshal.from_bytes s 0 = 258);
  marshal_to_buffer s 0 512 20000 [];
  test 204 (Marshal.from_bytes s 0 = 20000);
  marshal_to_buffer s 0 512 0x12345678 [];
  test 205 (Marshal.from_bytes s 0 = 0x12345678);
  marshal_to_buffer s 0 512 bigint [];
  test 206 (Marshal.from_bytes s 0 = bigint);
  marshal_to_buffer s 0 512 "foobargeebuz" [];
  test 207 (Marshal.from_bytes s 0 = "foobargeebuz");
  marshal_to_buffer s 0 512 longstring [];
  test 208 (Marshal.from_bytes s 0 = longstring);
  test 209
    (try marshal_to_buffer s 0 512 verylongstring []; false
     with Failure s when s = "Marshal.to_buffer: buffer overflow" -> true);
  marshal_to_buffer s 0 512 3.141592654 [];
  test 210 (Marshal.from_bytes s 0 = 3.141592654);
  marshal_to_buffer s 0 512 () [];
  test 211 (Marshal.from_bytes s 0 = ());
  marshal_to_buffer s 0 512 A [];
  test 212 (match Marshal.from_bytes s 0 with
    A -> true
  | _ -> false);
  marshal_to_buffer s 0 512 (B 1) [];
  test 213 (match Marshal.from_bytes s 0 with
    (B 1) -> true
  | _ -> false);
  marshal_to_buffer s 0 512 (C 2.718) [];
  test 214 (match Marshal.from_bytes s 0 with
    (C f) -> f = 2.718
  | _ -> false);
  marshal_to_buffer s 0 512 (D "hello, world!") [];
  test 215 (match Marshal.from_bytes s 0 with
    (D "hello, world!") -> true
  | _ -> false);
  marshal_to_buffer s 0 512 (E 'l') [];
  test 216 (match Marshal.from_bytes s 0 with
    (E 'l') -> true
  | _ -> false);
  marshal_to_buffer s 0 512 (F(B 1)) [];
  test 217 (match Marshal.from_bytes s 0 with
    (F(B 1)) -> true
  | _ -> false);
  marshal_to_buffer s 0 512 (G(A, G(B 2, G(C 3.14, G(D "glop", E 'e'))))) [];
  test 218 (match Marshal.from_bytes s 0 with
    (G(A, G(B 2, G(C 3.14, G(D "glop", E 'e'))))) -> true
  | _ -> false);
  marshal_to_buffer s 0 512 (H(1, A)) [];
  test 219 (match Marshal.from_bytes s 0 with
    (H(1, A)) -> true
  | _ -> false);
  marshal_to_buffer s 0 512 (I(B 2, 1e-6)) [];
  test 220 (match Marshal.from_bytes s 0 with
    (I(B 2, 1e-6)) -> true
  | _ -> false);
  let x = D "sharing" in
  let y = G(x, x) in
  let z = G(y, G(x, y)) in
  marshal_to_buffer s 0 512 z [];
  test 221 (match Marshal.from_bytes s 0 with
    G((G((D "sharing" as t1), t2) as t3), G(t4, t5)) ->
      t1 == t2 && t3 == t5 && t4 == t1
  | _ -> false);
  marshal_to_buffer s 0 512 [|1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16|] [];
  test 222
       (Marshal.from_bytes s 0 = [|1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16|]);
  let rec big n = if n <= 0 then A else H(n, big(n-1)) in
  test 223
    (try marshal_to_buffer s 0 512 (big 1000) []; false
     with Failure s when s = "Marshal.to_buffer: buffer overflow" -> true)

(* Test bounds checking and the [Marshal.data_size] primitive *)

let test_size() =
  let test_one n flags =
    let s =
      Marshal.to_bytes (G(A, G(B 2, G(C 3.14, G(D "glop", E 'e'))))) flags in
    test n (Marshal.header_size + Marshal.data_size s 0 = Bytes.length s) in
  test_one 300 []

let test_bounds_checking () =
  let test_one n v flags =
    let s = Marshal.to_string v flags in
    assert (String.length s > 20);
    test n
      (try ignore (Marshal.from_string (String.sub s 0 10) 0); false
       with Invalid_argument _ -> true);
    test (n+1)
      (try ignore (Marshal.from_string (String.sub s 0 20) 0); false
       with Invalid_argument _ -> true);
    test (n+2)
      (Marshal.from_string (s ^ "silly padding") 0 = v) in
  test_one 310 longstring []

(*
external marshal_to_block : int -> 'a -> Marshal.extern_flags list -> unit
                          = "marshal_to_block"
external marshal_from_block : int -> 'a = "marshal_from_block"

let test_block () =
  marshal_to_block 512 1 [];
  test 401 (marshal_from_block 512 = 1);
  marshal_to_block 512 (-1) [];
  test 402 (marshal_from_block 512 = (-1));
  marshal_to_block 512 258 [];
  test 403 (marshal_from_block 512 = 258);
  marshal_to_block 512 20000 [];
  test 404 (marshal_from_block 512 = 20000);
  marshal_to_block 512 0x12345678 [];
  test 405 (marshal_from_block 512 = 0x12345678);
  marshal_to_block 512 bigint [];
  test 406 (marshal_from_block 512 = bigint);
  marshal_to_block 512 "foobargeebuz" [];
  test 407 (marshal_from_block 512 = "foobargeebuz");
  marshal_to_block 512 longstring [];
  test 408 (marshal_from_block 512 = longstring);
  test 409
    (try marshal_to_block 512 verylongstring []; false
     with Failure s when s = "Marshal.to_buffer: buffer overflow" -> true);
  marshal_to_block 512 3.141592654 [];
  test 410 (marshal_from_block 512 = 3.141592654);
  marshal_to_block 512 () [];
  test 411 (marshal_from_block 512 = ());
  marshal_to_block 512 A [];
  test 412 (match marshal_from_block 512 with
    A -> true
  | _ -> false);
  marshal_to_block 512 (B 1) [];
  test 413 (match marshal_from_block 512 with
    (B 1) -> true
  | _ -> false);
  marshal_to_block 512 (C 2.718) [];
  test 414 (match marshal_from_block 512 with
    (C f) -> f = 2.718
  | _ -> false);
  marshal_to_block 512 (D "hello, world!") [];
  test 415 (match marshal_from_block 512 with
    (D "hello, world!") -> true
  | _ -> false);
  marshal_to_block 512 (E 'l') [];
  test 416 (match marshal_from_block 512 with
    (E 'l') -> true
  | _ -> false);
  marshal_to_block 512 (F(B 1)) [];
  test 417 (match marshal_from_block 512 with
    (F(B 1)) -> true
  | _ -> false);
  marshal_to_block 512 (G(A, G(B 2, G(C 3.14, G(D "glop", E 'e'))))) [];
  test 418 (match marshal_from_block 512 with
    (G(A, G(B 2, G(C 3.14, G(D "glop", E 'e'))))) -> true
  | _ -> false);
  marshal_to_block 512 (H(1, A)) [];
  test 419 (match marshal_from_block 512 with
    (H(1, A)) -> true
  | _ -> false);
  marshal_to_block 512 (I(B 2, 1e-6)) [];
  test 420 (match marshal_from_block 512 with
    (I(B 2, 1e-6)) -> true
  | _ -> false);
  let x = D "sharing" in
  let y = G(x, x) in
  let z = G(y, G(x, y)) in
  marshal_to_block 512 z [];
  test 421 (match marshal_from_block 512 with
    G((G((D "sharing" as t1), t2) as t3), G(t4, t5)) ->
      t1 == t2 && t3 == t5 && t4 == t1
  | _ -> false);
  marshal_to_block 512 [|1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16|] [];
  test 422 (marshal_from_block 512 =
            [|1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16|]);
  let rec big n = if n <= 0 then A else H(n, big(n-1)) in
  test 423
    (try marshal_to_block 512 (big 1000) []; false
     with Failure _ -> true);
  test 424
    (try marshal_to_block 512 "Hello, world!" [];
         ignore (marshal_from_block 8);
         false
     with Failure _ -> true)
 *)
(* Test for really big objects *)

let counter = ref 0

let rec make_big n =
  if n <= 0 then begin
    incr counter; B !counter
  end else begin
    let l = make_big (n-1) in
    let r = make_big (n-1) in
    G(l, r)
  end

let rec check_big n x =
  if n <= 0 then begin
    match x with
      B k -> incr counter; k = !counter
    | _   -> false
  end else begin
    match x with
      G(l, r) -> check_big (n-1) l && check_big (n-1) r
    | _       -> false
  end

(* Test for really deep data structures *)
let test_deep () =
  (* Right-leaning *)
  let rec loop acc i =
    if i < max_data_depth
    then loop (i :: acc) (i+1)
    else acc in
  let x = loop [] 0 in
  let s = Marshal.to_string x [] in
  test 425 (Marshal.from_string s 0 = x);
  (* Left-leaning *)
  let rec loop acc i =
    if i < max_data_depth
    then loop (G(acc, B i)) (i+1)
    else acc in
  let x = loop A 0 in
  let s = Marshal.to_string x [] in
  test 426 (Marshal.from_string s 0 = x)

(* Test for objects *)
class foo = object (self : 'self)
  val data1 = "foo"
  val data2 = "bar"
  val data3 = 42L
  method test1 = data1 ^ data2
  method test2 = false
  method test3 = self#test1
  method test4 = data3
end

class bar = object (self : 'self)
  inherit foo as super
  val! data2 = "test5"
  val data4 = "test3"
  val data5 = "test4"
  method test1 =
    data1
  ^ data2
  ^ data4
  ^ data5
  ^ Int64.to_string self#test4
end

class foobar = object (self : 'self)
  inherit foo as super
  inherit! bar
end

(* Test for objects *)
let test_objects () = if false then
  let x = new foo in
  let s = Marshal.to_string x [Marshal.Closures] in
  let x = Marshal.from_string s 0 in
  test 500 (x#test1 = "foobar");
  test 501 (x#test2 = false);
  test 502 (x#test3 = "foobar");
  test 503 (x#test4 = 42L);
  let x = new bar in
  let s = Marshal.to_string x [Marshal.Closures] in
  let x = Marshal.from_string s 0 in
  test 504 (x#test1 = "footest5test3test442");
  test 505 (x#test2 = false);
  test 506 (x#test3 = "footest5test3test442");
  test 507 (x#test4 = 42L);
  let x0 = new foobar in
  let s = Marshal.to_string x0 [Marshal.Closures] in
  let x = Marshal.from_string s 0 in
  test 508 (x#test1 = "footest5test3test442");
  test 509 (x#test2 = false);
  test 510 (x#test3 = "footest5test3test442");
  test 511 (x#test4 = 42L);
  test 512 (Oo.id x = Oo.id x0 + 1)     (* PR#5610 *)

(* Test for infix pointers *)
let test_infix () = if false then
  let t = true and
      f = false in
  let rec odd n =
    if n = 0
    then f
    else even (n-1)
  and even n =
    if n = 0
    then t
    else odd (n-1)
  in
  let s = Marshal.to_string (odd, even) [Marshal.Closures] in
  let (odd', even': (int -> bool) * (int -> bool)) = Marshal.from_string s 0 in
  test 600 (odd' 41 = true);
  test 601 (odd' 41 = odd 41);
  test 602 (odd' 142 = false);
  test 603 (odd' 142 = odd 142);
  test 604 (even' 41 = false);
  test 605 (even' 41 = even 41);
  test 606 (even' 142 = true);
  test 607 (even' 142 = even 142)


let test_mutual_rec_regression () = if false then
  (* this regression was reported by Cedric Pasteur in PR#5772 *)
  let rec test_one q x = x > 3
  and test_list q = List.for_all (test_one q) q in
  let g () = () in
  let f q = if test_list q then g () in

  test 700 (try ignore (Marshal.to_string f [Marshal.Closures]); true
            with _ -> false)

let test_end_of_file_regression () =
  (* See PR#7142 *)
  let write oc n =
    for k = 0 to n - 1 do
      Marshal.to_channel oc k []
    done
  in
  let read ic n =
    let k = ref 0 in
    try
      while true do
        if Marshal.from_channel ic != !k then
          failwith "unexpected integer";
        incr k
      done
    with
      | End_of_file when !k != n -> failwith "missing integer"
      | End_of_file -> ()
  in
  test 800 (
    try
      let n = 100 in
      let oc = open_out_bin "intext.data" in
      write oc n;
      close_out oc;

      let ic = open_in_bin "intext.data" in
      try
        read ic n;
        close_in ic;
        true
      with _ ->
        close_in ic;
        false
    with _ -> false
  )
(*
external init_buggy_custom_ops : unit -> unit =
  "init_buggy_custom_ops"
let () = init_buggy_custom_ops ()
type buggy
external value_with_buggy_serialiser : unit -> buggy =
  "value_with_buggy_serialiser"
let test_buggy_serialisers () =
  let x = value_with_buggy_serialiser () in
  let s = Marshal.to_string x [] in
  match Marshal.from_string s 0 with
  | exception (Failure _) -> ()
  | _ ->
     failwith "Marshalling should not have succeeded with a bad serialiser!"
 *)
let main() =
  if Array.length Sys.argv <= 2 then begin
    print_string "Default flags\n";
    test_out "intext.data"; test_in "intext.data";
    print_string "Default flags (again)\n";
    test_out "intext.data"; test_in "intext.data";
    print_string "Marshal.to_string\n";
    test_string();
    print_string "Marshal.to_buffer\n";
    test_buffer();
    print_string "Marshal.{header_size,data_size}\n";
    test_size();
    test_bounds_checking();
    print_string "Marshaling to a block\n";
    (* test_block(); *)
    print_string "Miscellaneous tests\n";
    test_deep();
    test_objects();
    test_infix ();
    test_mutual_rec_regression ();
    test_end_of_file_regression ();
    (* test_buggy_serialisers (); *)
    Sys.remove "intext.data";
  end else
  if Sys.argv.(1) = "make" then begin
    let n = int_of_string Sys.argv.(2) in
    let oc = open_out_bin "intext.data" in
    counter := 0;
    output_value oc (make_big n);
    close_out oc
  end else
  if Sys.argv.(1) = "test" then begin
    let n = int_of_string Sys.argv.(2) in
    let ic = open_in_bin "intext.data" in
    let b = (input_value ic : t) in
    Gc.full_major();
    close_in ic;
    counter := 0;
    if check_big n b then
      Printf.printf "Test big %d passed" n
    else
      Printf.printf "Test big %d FAILED" n;
    print_newline()
  end

let _ = main (); exit 0
