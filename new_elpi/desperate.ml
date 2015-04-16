(* GC off
let _ =
  let control = Gc.get () in
  let tweaked_control = { control with
    Gc.space_overhead = max_int;
  } in
  Gc.set tweaked_control
;;
*)

(* Invariant: a Heap term never points to a Query term *)
type term =
  (* Pure terms *)
  | Const of string
  (* Query terms *)
  | Struct of term * term * term list
  | Arg of int
  (* Heap terms *)
  | App of term * term * term list
  | UVar of term ref

let rec dummy = App (dummy,dummy,[])

let ppterm f t =
  let rec ppapp a c1 c2 = 
    Format.fprintf f "%c@[<hov 1>" c1;
    List.iter (fun x -> aux x; Format.fprintf f "@ ") a;
    Format.fprintf f "@]%c" c2
  and aux = function
      t when t == dummy -> Format.fprintf f "dummy"
    | App (hd,x,xs)-> ppapp (hd::x::xs) '(' ')'
    | Struct (hd,x,xs) -> ppapp (hd::x::xs) '{' '}'
    | UVar { contents = t } -> aux t
    | Const s -> Format.fprintf f "%s" s
    | Arg i -> Format.fprintf f "A%d" i
  in
    aux t
;;

type key = string * string

type clause = { hd : term; hyps : term list; vars : int; key : key }

let dummyk = "dummy"

let key_of = function
  | (App (Const w,Const z, _) | Struct (Const w,Const z, _)) -> w, z
  | (App (Const w,App(Const z,_,_), _)
    |Struct (Const w,App(Const z,_,_), _)) -> w, z
  | (App (Const w,_, _) | Struct (Const w,_, _)) -> w, dummyk
  | _ -> dummyk, dummyk

let clause_match_key (j1,j2) { key = (k1,k2) } =
  j1 == dummyk || k1 == dummyk ||
  (j1 == k1 && (j2 == dummyk || k2 == dummyk || j2 == k2))

(* The environment of a clause and stack frame *)

let to_heap e t =
  let rec aux = function
    | (Const _ | UVar _ | App _) as x -> x (* heap term *)
    | Struct(hd,b,bs) -> App (aux hd, aux b, List.map aux bs)
    | Arg i ->
        let a = e.(i) in
        if a == dummy then
            let v = UVar(ref dummy) in
            e.(i) <- v;
            v
        else aux a
  in aux t
;;

(* Unification *)

(* Invariant: LSH is a heap term, the RHS is a query in env e *)
let unif trail last_call a e b =
 let rec unif a b =
(*    Format.eprintf "unif %b: %a = %a\n%!" last_call ppterm a ppterm b; *)
   a == b || match a,b with
   | _, Arg i when e.(i) != dummy -> unif a e.(i)
   | UVar { contents = t }, _ when t != dummy -> unif t b
   | _, UVar { contents = t } when t != dummy -> unif a t
   | UVar _, Arg j -> e.(j) <- a; true
   | t, Arg i -> e.(i) <- t; true
   | UVar r, t ->
       if not last_call then trail := r :: !trail;
       r := to_heap e t;
       true
   | t, UVar r ->
       if not last_call then trail := r :: !trail;
       r := t;
       true
   | App (x1,x2,xs), (Struct (y1,y2,ys) | App (y1,y2,ys)) ->
       (x1 == y1 || unif x1 y1) && (x2 == y2 || unif x2 y2) &&
       List.for_all2 unif xs ys
   | _ -> false in
 unif a b
;;

(* Backtracking *)

let undo_trail old_trail trail =
  while !trail != old_trail do
    match !trail with
    | r :: rest -> r := dummy; trail := rest
    | _ -> assert false
  done
;;

(* Loop *)

type frame = { goals : term list; next : frame; }
type alternative = { lvl : int;
  stack : frame;
  trail : term ref list;
  clauses : clause list
}

let set_goals s gs = { s with goals = gs }

(* The block of recursive functions spares the allocation of a Some/None
 * at each iteration in order to know if one needs to backtrack or continue *)
let make_runtime (p : clause list) : (frame -> 'k) * ('k -> 'k) =
  let trail = ref [] in

  let rec run cp (stack : frame) alts lvl =
    match stack.goals with
    | [] -> if lvl == 0 then alts else run p stack.next alts (lvl - 1)
    | g :: gs ->
(*    Format.eprintf "goal: %a\n%!" ppterm g; *)
        let cp = List.filter (clause_match_key (key_of g)) cp in
        backchain g gs cp stack alts lvl

  and backchain g gs cp old_stack alts lvl =
    let last_call = alts = [] in
    let rec select = function
    | [] -> next_alt alts
    | c :: cs ->
        let old_trail = !trail in
        let last_call = last_call && cs = [] in
        let env = Array.create c.vars dummy in
        match unif trail last_call g env c.hd with
        | false -> undo_trail old_trail trail; select cs
        | true ->
            let next, next_lvl =
              if gs = [] then old_stack.next, lvl
              else { old_stack with goals = gs }, lvl + 1 in
            let stack = { goals = List.map (to_heap env) c.hyps; next } in
            let alts = if cs = [] then alts else
              { stack=old_stack; trail=old_trail; clauses=cs; lvl } :: alts in
            run p stack alts next_lvl
    in
      select cp

  and next_alt = function
    | [] -> raise (Failure "no clause")
    | { stack; trail = old_trail; clauses; lvl } :: alts ->
        undo_trail old_trail trail;
        run clauses stack alts lvl
  in
   (fun s -> run p s [] 0), next_alt
;;
  

(*
(* Test *)

(* Hashconsed constants *)
let appk = "app"
let nilk = "nil"
let revk = "rev"
let eqk = "eq"
let consk = "cons"
let ak = "a"
let bk = "b"

let cak = Const ak
let cbk = Const bk
let cconsk = Const consk
let cnilk = Const nilk
let cappk = Const appk
let crevk = Const revk
let ceqk = Const eqk

(* Program *)
let app1 = { hd = Struct (cappk, cnilk, [Arg 0; Arg 0 ]); hyps = []; vars = 1; key = (appk,nilk) };;
let app2 = { hd = Struct (cappk, Struct(cconsk, Arg 0, [Arg 1]), [Arg 2; Struct (cconsk, Arg 0, [Arg 3 ]) ]); hyps = [ Struct (cappk, Arg 1, [Arg 2; Arg 3]) ]; vars = 4; key = (appk,consk) };;

let rev1 = { hd = Struct( crevk, cnilk, [Arg 0; Arg 0 ]); hyps = []; vars = 1; key = (revk,nilk) };;
let rev2 = { hd = Struct( crevk, Struct(cconsk, Arg 0, [Arg 1]), [Arg 2; Arg 3 ]);
             hyps = [Struct(crevk, Arg 1, [Struct ( cconsk, Arg 0, [Arg 2]); Arg 3])];
             vars = 4; key = (revk,consk) };;
let refl = { hd = Struct(ceqk, Arg 0, [Arg 0]); hyps = []; vars = 1; key = (eqk,dummyk) };;

let l1 =
   App (cconsk, cak, [App (cconsk, cbk, [ 
   App (cconsk, cak, [App (cconsk, cbk, [ 
   App (cconsk, cak, [App (cconsk, cbk, [ 
   App (cconsk, cak, [App (cconsk, cbk, [ 
   App (cconsk, cak, [App (cconsk, cbk, [ 
   cnilk ])])])])])])])])])]);;
let gs =
  let v1 = UVar (ref dummy) in
  let v2 = UVar (ref dummy) in
  let v3 = UVar (ref dummy) in
  let v4 = UVar (ref dummy) in
  let v5 = UVar (ref dummy) in
  let v6 = UVar (ref dummy) in
  let v7 = UVar (ref dummy) in
  let v8 = UVar (ref dummy) in
  let v9 = UVar (ref dummy) in
  let v10 = UVar (ref dummy) in
  let v11 = UVar (ref dummy) in
  let v12 = UVar (ref dummy) in
  let v13 = UVar (ref dummy) in
  let v14 = UVar (ref dummy) in
  let r1 = UVar (ref dummy) in
  let r2 = UVar (ref dummy) in
  let a1 = App (cappk, l1, [ l1; v1] ) in
  let a2 = App (cappk, v1, [ v1; v2] ) in
  let a3 = App (cappk, v2, [ v2; v3] ) in
  let a4 = App (cappk, v3, [ v3; v4] ) in
  let a5 = App (cappk, v4, [ v4; v5] ) in
  let a6 = App (cappk, v5, [ v5; v6] ) in
  let a7 = App (cappk, v6, [ v6; v7] ) in
  let a8 = App (cappk, v7, [ v7; v8] ) in
  let a9 = App (cappk, v8, [v8; v9] ) in
  let a10 = App (cappk, v9, [v9; v10] ) in
  let a11 = App (cappk, v10, [ v10; v11] ) in
  let a12 = App (cappk, v11, [ v11; v12] ) in
  let a13 = App (cappk, v12, [ v12; v13] ) in
  let a14 = App (cappk, v13, [ v13; v14] ) in
  let aR1 = App (crevk, v14, [ cnilk; r1] ) in
  let aR2 = App (crevk, r1, [cnilk; r2] ) in
  [
          a1;
          a2;
          a3;
          a4;
          a5;
          a6;
          a7;
          a8;
          a9;
          a10;
          a11;
          a12;
          a13;
          a14;
          aR1;
          aR2;
          App (ceqk, v14, [r2]) 
  ];;

let p = [app1;app2;rev1;rev2;refl];;
let run, cont = make_runtime p;;
let rec top = { goals = gs; next = top; };;
let k = ref (run top);;
while !k <> [] do k := cont !k; done
*)

(* Hash re-consing :-( *)
let funct_of_ast =
 let h = Hashtbl.create 37 in
 function x ->
  try Hashtbl.find h x
  with Not_found ->
   let xx = Const (Lprun2.ASTFuncS.pp x) in
   Hashtbl.add h x xx ; xx

let heap_var_of_ast l n =
 try l,List.assoc n l
 with Not_found ->
  let n' = UVar (ref dummy) in
  (n,n')::l,n'

let rec heap_term_of_ast l =
 function
    Lprun2.FOAST.Var v ->
     let l,v = heap_var_of_ast l v in
     l, v
  | Lprun2.FOAST.App(f,[]) ->
     l, funct_of_ast f
  | Lprun2.FOAST.App(f,tl) ->
     let l,rev_tl =
       List.fold_left
        (fun (l,tl) t -> let l,t = heap_term_of_ast l t in (l,t::tl))
        (l,[]) tl in
     match funct_of_ast f :: List.rev rev_tl with
        hd1::hd2::tl -> l, App(hd1,hd2,tl)
      | _ -> assert false

let stack_var_of_ast (f,l) n =
 try (f,l),List.assoc n l
 with Not_found ->
  let n' = Arg f in
  (f+1,(n,n')::l),n'

let rec stack_term_of_ast l =
 function
    Lprun2.FOAST.Var v ->
     let l,v = stack_var_of_ast l v in
     l, v
  | Lprun2.FOAST.App(f,[]) ->
     l, funct_of_ast f
  | Lprun2.FOAST.App(f,tl) ->
     let l,rev_tl =
       List.fold_left
        (fun (l,tl) t -> let l,t = stack_term_of_ast l t in (l,t::tl))
        (l,[]) tl in
     match funct_of_ast f :: List.rev rev_tl with
        hd1::hd2::tl -> l, Struct(hd1,hd2,tl)
      | _ -> assert false

let query_of_ast t = snd (heap_term_of_ast [] t)

let rec chop =
 function
    Struct(Const f,hd2,tl) when
     Lprun2.ASTFuncS.eq (Lprun2.ASTFuncS.from_string f) Lprun2.ASTFuncS.andf
     -> chop hd2 @ List.flatten (List.map chop tl)
  | Const f when
     Lprun2.ASTFuncS.eq (Lprun2.ASTFuncS.from_string f) Lprun2.ASTFuncS.andf
     -> []
  | Const f when
     Lprun2.ASTFuncS.eq (Lprun2.ASTFuncS.from_string f) Lprun2.ASTFuncS.cutf
     -> assert false
  | _ as f -> [ f ]

let program_of_ast p =
 List.map (fun (a,f) ->
  let l,a = stack_term_of_ast (0,[]) a in
  let (max,_),f = stack_term_of_ast l f in
Format.eprintf "%a :- " ppterm a;
List.iter (Format.eprintf "%a, " ppterm) (chop f);
Format.eprintf ".\n%!";
  { hd = a
  ; hyps = chop f
  ; vars = max
  ; key = key_of a
  }) p

let impl =
 (module struct
  (* RUN with non indexed engine *)
  type query = term
  type program = clause list
  let query_of_ast = query_of_ast
  let program_of_ast = program_of_ast

  let msg q =
   Format.fprintf Format.str_formatter "Desperate: %a" ppterm q ;
   Format.flush_str_formatter ()

  let execute_once p q =
   let run, cont = make_runtime p in
   let rec top = { goals = [ q ]; next = top } in
   try ignore (run top) ; true
   with Failure _ -> false

  let execute_loop p q =
   let run, cont = make_runtime p in
   let rec top = { goals = [ q ]; next = top } in
   let time0 = Unix.gettimeofday() in
   let k = ref (run top) in
   let time1 = Unix.gettimeofday() in
   prerr_endline ("Execution time: "^string_of_float(time1 -. time0));
   Format.eprintf "Result: %a\n%!" ppterm q ;
   while !k <> [] do
     let time0 = Unix.gettimeofday() in
     k := cont !k;
     let time1 = Unix.gettimeofday() in
     prerr_endline ("Execution time: "^string_of_float(time1 -. time0));
     Format.eprintf "Result: %a\n%!" ppterm q ;
  done
 end : Lprun2.Implementation)
