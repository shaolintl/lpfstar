(* elpi: embedded lambda prolog interpreter                                  *)
(* license: GNU Lesser General Public License Version 2.1                    *)
(* ------------------------------------------------------------------------- *)

open Runtime;;
open Runtime.Utils;;
open Runtime.Pp;;
open Runtime.Constants;;
module F = Parser.ASTFuncS;;

let register_eval, lookup_eval =
 let (evals : ('a, term list -> term) Hashtbl.t)
   =
     Hashtbl.create 17 in
 (fun s -> Hashtbl.add evals (fst (funct_of_ast (F.from_string s)))),
 Hashtbl.find evals
;;

(* To avoid adding another primitive constant to the type term, we
   introduce bijective maps between {in,out}_streams and integers *)

(* The map stores pairs in_stream * char option, which is the lookahead *)
let add_in_stream,get_in_stream,set_lookahead =
 let fresh = ref (-1) in
 let streams = ref Ptmap.empty in
 (fun s -> incr fresh ; streams := Ptmap.add !fresh (s,None) !streams; !fresh),
 (fun i -> Ptmap.find i !streams),
 (fun i c ->
   try streams := Ptmap.add i (fst (Ptmap.find i !streams),c) !streams
   with Not_found -> anomaly "setting the lookahead for an unknown channel")

let add_out_stream,get_out_stream =
 let fresh = ref (-1) in
 let streams = ref Ptmap.empty in
 (fun s -> incr fresh ; streams := Ptmap.add !fresh s !streams ; !fresh),
 (fun i -> Ptmap.find i !streams)

let cstdin = add_in_stream stdin;;
let cstdout= add_out_stream stdout;;
let cstderr = add_out_stream stderr;;

(* Traverses the expression evaluating all custom evaluable functions *)
let rec eval depth =
 function
    Lam _
  | Custom _ -> error "Evaluation of a lambda abstraction or custom predicate"
  | Arg _
  | AppArg _ -> anomaly "Not a heap term"
  | App (hd,arg,args) ->
     let f =
      try lookup_eval hd
      with Not_found -> anomaly (string_of_constant hd ^ " not evaluable") in
     let args = List.map (eval depth) (arg::args) in
     f args
  | UVar ({ contents = g }, from, args) when g != dummy ->
     eval depth (deref ~from ~to_:depth args g)
  | AppUVar ({contents = t}, from, args) when t != dummy ->
     eval depth (app_deref ~from ~to_:depth args t)
  | UVar _
  | AppUVar _ -> error "Evaluation of a non closed term (maybe delay)"
  | Const hd ->
     let f =
      try lookup_eval hd
      with Not_found -> anomaly (string_of_constant hd ^ " not evaluable") in
     f []
  | String _
  | Int _
  | Float _ as x -> x
;;

let _ =
  register_eval "std_in" (fun args ->
   match args with
     [] -> Int cstdin
   | _ -> type_error "Wrong arguments to stin") ;
  register_eval "std_out" (fun args ->
   match args with
     [] -> Int cstdout
   | _ -> type_error "Wrong arguments to stout") ;
  register_eval "std_err" (fun args ->
   match args with
     [] -> Int cstderr
   | _ -> type_error "Wrong arguments to sterr") ;
  register_eval "-" (fun args ->
   match args with
     [ Int x ; Int y ] -> Int (x - y)
   | [ Float x ; Float y ] -> Float (x -. y)
   | _ -> type_error "Wrong arguments to -") ;
  register_eval "+" (fun args ->
   match args with
     [ Int x ; Int y ] -> Int (x + y)
   | [ Float x ; Float y ] -> Float (x +. y)
   | _ -> type_error "Wrong arguments to +") ;
  register_eval "*" (fun args ->
   match args with
     [ Int x ; Int y ] -> Int (x * y)
   | [ Float x ; Float y ] -> Float (x *. y)
   | _ -> type_error "Wrong arguments to *") ;
  register_eval "/" (fun args ->
   match args with
     [ Float x ; Float y ] -> Float (x /. y)
   | _ -> type_error "Wrong arguments to /") ;
  register_eval "mod" (fun args ->
   match args with
     [ Int x ; Int y ] -> Int (x mod y)
   | _ -> type_error "Wrong arguments to mod") ;
  register_eval "div" (fun args ->
   match args with
     [ Int x ; Int y ] -> Int (x / y)
   | _ -> type_error "Wrong arguments to div") ;
  register_eval "^" (fun args ->
   match args with
     [ String x ; String y ] -> String (F.from_string (F.pp x ^ F.pp y))
   | _ -> type_error "Wrong arguments to ^") ;
  register_eval "~" (fun args ->
   match args with
     [ Int x ] -> Int (-x)
   | [ Float x ] -> Float (-. x)
   | _ -> type_error "Wrong arguments to ~") ;
  register_eval "abs" (fun args ->
   match args with
     [ Int x ] -> Int (abs x)
   | [ Float x ] -> Float (abs_float x)
   | _ -> type_error "Wrong arguments to abs") ;
  register_eval "int_to_real" (fun args ->
   match args with
     [ Int x ] -> Float (float_of_int x)
   | _ -> type_error "Wrong arguments to int_to_real") ;
  register_eval "sqrt" (fun args ->
   match args with
     [ Float x ] -> Float (sqrt x)
   | _ -> type_error "Wrong arguments to sqrt") ;
  register_eval "sin" (fun args ->
   match args with
     [ Float x ] -> Float (sin x)
   | _ -> type_error "Wrong arguments to sin") ;
  register_eval "cos" (fun args ->
   match args with
     [ Float x ] -> Float (cos x)
   | _ -> type_error "Wrong arguments to cosin") ;
  register_eval "arctan" (fun args ->
   match args with
     [ Float x ] -> Float (atan x)
   | _ -> type_error "Wrong arguments to arctan") ;
  register_eval "ln" (fun args ->
   match args with
     [ Float x ] -> Float (log x)
   | _ -> type_error "Wrong arguments to ln") ;
  register_eval "floor" (fun args ->
   match args with
     [ Float x ] -> Int (int_of_float (floor x))
   | _ -> type_error "Wrong arguments to floor") ;
  register_eval "ceil" (fun args ->
   match args with
     [ Float x ] -> Int (int_of_float (ceil x))
   | _ -> type_error "Wrong arguments to ceil") ;
  register_eval "truncate" (fun args ->
   match args with
     [ Float x ] -> Int (truncate x)
   | _ -> type_error "Wrong arguments to truncate") ;
  register_eval "size" (fun args ->
   match args with
     [ String x ] -> Int (String.length (F.pp x))
   | _ -> type_error "Wrong arguments to size") ;
  register_eval "chr" (fun args ->
   match args with
     [ Int x ] -> String (F.from_string (String.make 1 (char_of_int x)))
   | _ -> type_error "Wrong arguments to chr") ;
  register_eval "string_to_int" (fun args ->
   match args with
     [ String x ] when String.length (F.pp x) = 1 ->
       Int (int_of_char (F.pp x).[0])
   | _ -> type_error "Wrong arguments to string_to_int") ;
  register_eval "substring" (fun args ->
   match args with
     [ String x ; Int i ; Int j ] when
       i >= 0 && j >= 0 && String.length (F.pp x) >= i+j ->
       String (F.from_string (String.sub (F.pp x) i j))
   | _ -> type_error "Wrong arguments to substring") ;
  register_eval "int_to_string" (fun args ->
   match args with
     [ Int x ] -> String (F.from_string (string_of_int x))
   | _ -> type_error "Wrong arguments to int_to_string") ;
  register_eval "real_to_string" (fun args ->
   match args with
     [ Float x ] -> String (F.from_string (string_of_float x))
   | _ -> type_error "Wrong arguments to real_to_string")
;;

let really_input ic s ofs len =
  let rec unsafe_really_input read ic s ofs len =
    if len <= 0 then read else begin
      let r = input ic s ofs len in
      if r = 0
      then read
      else unsafe_really_input (read+r) ic s (ofs + r) (len - r)
    end
  in
  if ofs < 0 || len < 0 || ofs > String.length s - len
  then invalid_arg "really_input"
  else unsafe_really_input 0 ic s ofs len

let _ =
  register_custom "$print" (fun ~depth ~env args ->
    Format.printf "@[<hov 1>" ;
    List.iter (Format.printf "%a@ " (uppterm depth [] 0 env)) args ;
    Format.printf "@]\n%!" ;
    []) ;
  register_custom "$lt" (fun ~depth ~env:_ args ->
    let rec get_constant = function
      | Const c -> c
      | UVar ({contents=t},vardepth,args) when t != dummy ->
         get_constant (deref ~from:vardepth ~to_:depth args t)
      | AppUVar ({contents=t},vardepth,args) when t != dummy ->
         get_constant (app_deref ~from:vardepth ~to_:depth args t)
      | _ -> error "$lt takes constants as arguments" in
    match args with
    | [t1; t2] ->
        let t1 = get_constant t1 in
        let t2 = get_constant t2 in
        let is_lt = if t1 < 0 && t2 < 0 then t2 < t1 else t1 < t2 in
        if not is_lt then raise No_clause else []
    | _ -> type_error "$lt takes 2 arguments") ;
  List.iter (fun p,psym,pname ->
  register_custom pname (fun ~depth ~env:_ args ->
    match args with
    | [t1; t2] ->
        let t1 = eval depth t1 in
        let t2 = eval depth t2 in
        (match t1,t2 with
           Int _,    Int _
         | Float _,  Float _
         | String _, String _ ->
            if not (p t1 t2) then raise No_clause else []
         | _ ->
           type_error ("Wrong arguments to " ^ psym ^ " (or to " ^ pname^ ")"))
    | _ -> type_error (psym ^ " (or " ^ pname ^ ") takes 2 arguments"))
  ) [(<),"<","$lt_" ; (>),">","$gt_" ; (<=),"=<","$le_" ; (>=),">=","$ge_"] ;
  register_custom "$getenv" (fun ~depth ~env:_ args ->
    match args with
    | [t1; t2] ->
       (match eval depth t1 with
           String s ->
            (try
              let v = Sys.getenv (F.pp s) in
               [ App(eqc, t2, [String (F.from_string v)]) ]
             with Not_found -> raise No_clause)
         | _ -> type_error "bad argument to getenv (or $getenv)")
    | _ -> type_error "getenv (or $getenv) takes 2 arguments") ;
  register_custom "$system" (fun ~depth ~env:_ args ->
    match args with
    | [t1; t2] ->
       (match eval depth t1 with
           String s -> [ App (eqc, t2, [Int (Sys.command (F.pp s))]) ]
         | _ -> type_error "bad argument to system (or $system)")
    | _ -> type_error "system (or $system) takes 2 arguments") ;
  register_custom "$is" (fun ~depth ~env:_ args ->
    match args with
    | [t1; t2] -> [ App (eqc, t1, [eval depth t2]) ]
    | _ -> type_error "is (or $is) takes 2 arguments") ;
  register_custom "$open_in" (fun ~depth ~env:_ args ->
    match args with
    | [t1; t2] ->
       (match eval depth t1 with
           String s ->
            (try
              let v = open_in (F.pp s) in
              let vv = add_in_stream v in
               [ App(eqc, t2, [Int vv]) ]
             with Sys_error msg -> error msg)
         | _ -> type_error "bad argument to open_in (or $open_in)")
    | _ -> type_error "open_in (or $open_in) takes 2 arguments") ;
  register_custom "$open_out" (fun ~depth ~env:_ args ->
    match args with
    | [t1; t2] ->
       (match eval depth t1 with
           String s ->
            (try
              let v = open_out (F.pp s) in
              let vv = add_out_stream v in
               [ App(eqc, t2, [Int vv]) ]
             with Sys_error msg -> error msg)
         | _ -> type_error "bad argument to open_out (or $open_out)")
    | _ -> type_error "open_out (or $open_out) takes 2 arguments") ;
  register_custom "$open_append" (fun ~depth ~env:_ args ->
    match args with
    | [t1; t2] ->
       (match eval depth t1 with
           String s ->
            (try
              let v =
               open_out_gen
                [Open_wronly; Open_append; Open_creat; Open_text] 0x664
                (F.pp s) in
              let vv = add_out_stream v in
               [ App(eqc, t2, [Int vv]) ]
             with Sys_error msg -> error msg)
         | _ -> type_error "bad argument to open_append (or $open_append)")
    | _ -> type_error "open_append (or $open_append) takes 2 arguments") ;
  register_custom "$open_string" (fun ~depth ~env:_ args ->
    match args with
    | [t1; t2] ->
       (match eval depth t1 with
           String s ->
            (try
             let filename,outch = Filename.open_temp_file "elpi" "tmp" in
             output_string outch (F.pp s) ;
             close_out outch ;
             let v = open_in filename in
             Sys.remove filename ;
             let vv = add_in_stream v in
              [ App(eqc, t2, [Int vv]) ]
             with Sys_error msg -> error msg)
         | _ -> type_error "bad argument to open_in (or $open_in)")
    | _ -> type_error "open_in (or $open_in) takes 2 arguments") ;
  register_custom "$close_in" (fun ~depth ~env:_ args ->
    match args with
    | [t1] ->
       (match eval depth t1 with
           Int s ->
            (try close_in (fst (get_in_stream s)); []
             with Sys_error msg -> error msg)
         | _ -> type_error "bad argument to close_in (or $close_in)")
    | _ -> type_error "close_in (or $close_in) takes 1 argument") ;
  register_custom "$close_out" (fun ~depth ~env:_ args ->
    match args with
    | [t1] ->
       (match eval depth t1 with
           Int s ->
            (try close_out(get_out_stream s); [] with Sys_error msg->error msg)
         | _ -> type_error "bad argument to close_out (or $close_out)")
    | _ -> type_error "close_out (or $close_out) takes 1 argument") ;
  register_custom "$output" (fun ~depth ~env:_ args ->
    match args with
    | [t1; t2] ->
       (match eval depth t1, eval depth t2 with
           Int n, String s ->
            (try output_string (get_out_stream n) (F.pp s) ; []
             with Sys_error msg -> error msg)
         | _ -> type_error "bad argument to output (or $output)")
    | _ -> type_error "output (or $output) takes 2 arguments") ;
  register_custom "$term_to_string" (fun ~depth ~env args ->
    match args with
    | [t1; t2] ->
       Format.fprintf Format.str_formatter "%a" (uppterm depth [] 0 env) t1 ;
       let s = Format.flush_str_formatter () in
       [App(eqc,t2,[String (F.from_string s)])]
    | _ -> type_error "term_to_string (or $term_to_string) takes 2 arguments");
  register_custom "$string_to_term" (fun ~depth ~env args ->
    match args with
    | [t1; t2] ->
       (match eval depth t1 with
           String s ->
            let s = Parser.parse_goal (F.pp s) in
            let t = term_of_ast ~depth s in
            [App (eqc, t2, [t])]
         | _ -> type_error "bad argument to string_to_term (or $string_to_term)")
    | _ -> type_error "string_to_term (or $string_to_term) takes 2 arguments");
  register_custom "$flush" (fun ~depth ~env:_ args ->
    match args with
    | [t1] ->
       (match eval depth t1 with
           Int n ->
            (try flush (get_out_stream n) ; []
             with Sys_error msg -> error msg)
         | _ -> type_error "bad argument to flush (or $flush)")
    | _ -> type_error "flush (or $flush) takes 2 arguments") ;
  register_custom "$halt" (fun ~depth ~env:_ args ->
    match args with
    | [] -> exit 0
    | _ -> type_error "halt (or $halt) takes 0 arguments") ;
  register_custom "$input" (fun ~depth ~env:_ args ->
    match args with
    | [t1 ; t2 ; t3] ->
       (match eval depth t1, eval depth t2 with
           Int s, Int n ->
            (try
              let ch,lookahead = get_in_stream s in
              let buf = String.make n ' ' in
              let start,n =
               match lookahead with
                  None -> 0,n
                | Some c -> buf.[0] <- c ; 1,n-1 in
              let read = really_input ch buf start n in
              let str = String.sub buf 0 (read + start) in
              set_lookahead s None ;
              [App (eqc, t3, [String (F.from_string str)])]
             with 
              Sys_error msg -> error msg)
         | _ -> type_error "bad argument to input (or $input)")
    | _ -> type_error "input (or $input) takes 3 arguments") ;
  register_custom "$input_line" (fun ~depth ~env:_ args ->
    match args with
    | [t1 ; t2] ->
       (match eval depth t1 with
           Int s ->
            (try
              let ch,lookahead = get_in_stream s in
              let str = try input_line ch with End_of_file -> "" in
              set_lookahead s None ;
              let str =
               match lookahead with
                  None -> str
                | Some c -> String.make 1 c ^ str in
              [App (eqc, t2, [String (F.from_string str)])]
             with 
              Sys_error msg -> error msg)
         | _ -> type_error "bad argument to input_line (or $input_line)")
    | _ -> type_error "input_line (or $input_line) takes 2 arguments") ;
  register_custom "$lookahead" (fun ~depth ~env:_ args ->
    match args with
    | [t1 ; t2] ->
       (match eval depth t1 with
           Int s ->
            (try
              let ch,lookahead = get_in_stream s in
              let c =
               match lookahead with
                  Some c -> String.make 1 c
                | None ->
                   (try
                     let c = input_char ch in
                     set_lookahead s (Some c) ;
                     String.make 1 c
                    with End_of_file -> "")
              in
              [App (eqc, t2, [String (F.from_string c)])]
             with 
              Sys_error msg -> error msg)
         | _ -> type_error "bad argument to lookahead (or $lookahead)")
    | _ -> type_error "lookahead (or $lookahead) takes 2 arguments") ;
  register_custom "$eof" (fun ~depth ~env:_ args ->
    match args with
    | [t1] ->
       (match eval depth t1 with
           Int s ->
            (try
              let ch,lookahead = get_in_stream s in
              match lookahead with
                 Some c -> raise No_clause
               | None ->
                  (try
                    let c = input_char ch in
                    set_lookahead s (Some c) ;
                    raise No_clause
                   with End_of_file -> [])
             with 
              Sys_error msg -> error msg)
         | _ -> type_error "bad argument to eof (or $eof)")
    | _ -> type_error "eof (or $eof) takes 1 argument") ;
;;
