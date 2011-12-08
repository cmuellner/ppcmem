(* generated by Lem from MachineDefInstructionSemantics.lem *)
open Nat_num

type 'a set = 'a Pset.set

(*========================================================================*)
(*                                                                        *)
(*                ppcmem executable model                                 *)
(*                                                                        *)
(*          Susmit Sarkar, University of Cambridge                        *)
(*          Peter Sewell, University of Cambridge                         *)
(*          Jade Alglave, Oxford University                               *)
(*          Luc Maranget, INRIA Rocquencourt                              *)
(*                                                                        *)
(*  This file is copyright 2010,2011 Institut National de Recherche en    *)
(*  Informatique et en Automatique (INRIA), and Susmit Sarkar, Peter      *)
(*  Sewell, and Jade Alglave.                                             *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*                                                                        *)
(*                                                                        *)
(*                                                                        *)
(*                                                                        *)
(*                                                                        *)
(*========================================================================*)

(* Help emacs fontification -*-caml-*- *)

(* PS2: what's the Scott-language prover-output story for these missing pattern match cases? *)


open MachineDefUtils
open MachineDefFreshIds
open MachineDefValue
open MachineDefTypes

let make_write_event tid ioid a v =
  let new_eiid = { weiid_thread = tid; weiid_ioid = ioid; weiid_addr = a; weiid_value = v } in
  {w_thread = tid; w_ioid = ioid; w_eiid = new_eiid;w_addr = a;w_value = v; w_isrelease = false }

let make_write_release_event tid ioid a v =
  let new_eiid = { weiid_thread = tid; weiid_ioid = ioid; weiid_addr = a; weiid_value = v } in
  {w_thread = tid; w_ioid = ioid; w_eiid = new_eiid;w_addr = a;w_value = v; w_isrelease = true }

let make_barrier_event tid ioid b =
  let new_eiid = { beiid_thread = tid; beiid_ioid = ioid } in
  {b_thread = tid; b_ioid = ioid; b_eiid = new_eiid;b_barrier_type = b}


let make_read_request_event tid ioid a =
  let new_eiid = { reiid_thread = tid; reiid_ioid = ioid; reiid_addr = a } in
  {r_thread = tid; r_ioid = ioid; r_eiid = new_eiid;r_addr = a}

(*
let make_read_reserve_request_event tid ioid a =
  let new_eiid = <| reiid_thread = tid; reiid_ioid = ioid; reiid_addr = a |> in
  <|r_thread = tid; r_eiid = new_eiid;r_addr = a; r_isreadreserve = true|>
*)

let internal_transition_cand s =
  (match s.remaining with
  | (Binop( _, _, _, _)) :: _ -> true
  | (Unop( _, _, _)) :: _ -> true
  | _ -> false
  )
        
let internal_transition_action s =
  (match s.remaining with
  | Binop( v1, bop, v2, v3) :: rem' ->
      let v2' = subst_var s.val_soln v2 in
      let v3' = subst_var s.val_soln v3 in
      let v1' = op bop v2' v3' in
      (match v1 with
        | Flexible( uv1) ->
	    { remaining = rem';
	    val_soln = Pmap.add uv1 v1' s.val_soln }
(*	| Rigid _ -> user_error "Binop assigning to rigid variable" *)
      )
  | Unop(  v1, uop, v2) :: rem' ->
      let v2' = subst_var s.val_soln v2 in
      let v1' = op1 uop v2' in
      (match v1 with
	| Flexible( uv1) ->
	    { remaining = rem';
	    val_soln = Pmap.add uv1 v1' s.val_soln}
(* 	| Rigid _ -> user_error "Unop assigning to rigid variable" *)
      ) 
(*   | _ -> user_error "Internal transition attempted for non-candidate" *)
  )
        
    let reg_read_cand s =
      (match s.remaining with
      | Read_reg( _,  _) :: _ -> true
      | _ -> false
      )

    let reg_to_read s =
      (match s.remaining with
      | Read_reg( r, v)  :: _ -> r
(*       | _ -> Warn.user_error "Not a register to read" *)
      )

    let reg_read_action s vr =
      (match s.remaining with
      | Read_reg( r, v) :: rem' ->
          (match v with
	    | Flexible( uv) ->
		{ remaining = rem';
		 val_soln = Pmap.add uv vr s.val_soln }
(* 	    | Rigid _ -> Warn.user_error "Register read to rigid variable" *)
	  )
(*       | _ -> Warn.user_error "Register-read transition attempted for non-candidate" *)
      )

    let mem_read_cand s =
      (match s.remaining with
      | Read_mem( _, _) :: _ -> true
      | _ -> false
      )

    let mem_loc_to_read s =
      (match s.remaining with
      | Read_mem( a, v) :: _ -> subst_var s.val_soln a
      | Read_mem_reserve( a, v) :: _ -> subst_var s.val_soln a
(*       | _ -> Warn.user_error "Not a memory location to read" *)
      )

    let mem_read_action s vr =
      (match s.remaining with
      | Read_mem( a, v) :: rem' ->
	  (match v with
	    | Flexible( uv) ->
		{ remaining = rem';
		 val_soln = Pmap.add uv vr s.val_soln }
(* 	    | Rigid _ -> Warn.user_error "Memory read to rigid variable" *)
	  )
      | Read_mem_reserve( a, v) :: rem' ->
	  (match v with
	    | Flexible( uv) ->
		{ remaining = rem';
		 val_soln = Pmap.add uv vr s.val_soln }
(* 	    | Rigid _ -> Warn.user_error "Memory read to rigid variable" *)
	  )
(*       | _ -> Warn.user_error "Memory-read transition attempted for non-candidate" *)
      )

    let mem_read_reserve_cand s =
      (match s.remaining with
      | Read_mem_reserve( _, _) :: _ -> true
      | _ -> false
      )

    let determined_branch s =
      List.for_all
	(fun a ->
	  (match a with
	  | Cond_branch( v, _) -> is_determined (subst_var s.val_soln v)
	  | _ -> true
          ))
	s.remaining

    let possible_target s addr r =
      List.exists
	(fun a ->
	  (match a with
	  | Jump( cst) -> equalityPossible addr (Rigid( cst))
	  | Cond_branch( v, cst1) ->
	      let vn = subst_var s.val_soln v in
	      (match r with
		(* Should check vn and the variable under ifzero/nonzero is the same *)
	      | IfZero( _) -> equalityPossible vn zero
	      | IfNonZero( _) -> not (equalityPossible vn zero)
	      | Always -> false
              )
	  | _ -> false
          ))
	s.remaining

(*PS2: the following has a misleading name - should alpha...    *)
    let can_transition s =
      (match s.remaining with
      | [] -> false
      | Read_reg( _, _) :: _ -> true
      | Read_mem( _, _) :: _ -> true
      | Read_mem_reserve( _, _) :: _ -> true
      | Read_mem_acq( _, _) :: _ -> true
      | Binop( _, _, _, _) :: _-> true
      | Unop( _, _, _) :: _ -> true
      | _ -> false
      )

    let will_barrier s =
      List.exists
    	(fun a ->
    	  (match a with
    	  | Barrier( _) -> true
    	  | _ -> false
          ))
    	s.remaining

    let will_sync s =
      List.exists
	(fun a ->
	  (match a with
	  | Barrier( Sync) -> true
	  | _ -> false
          ))
	s.remaining

    let will_lwsync s =
      List.exists
	(fun a ->
	  (match a with
	  | Barrier( LwSync) -> true
	  | _ -> false
          ))
	s.remaining
	
    let will_eieio s =
      List.exists
	(fun a ->
	  (match a with
	  | Barrier( Eieio) -> true
	  | _ -> false
          ))
	s.remaining
	
    let will_isync s =
      List.exists
	(fun a ->
	  (match a with
	  | Isync -> true
	  | _ -> false
          ))
	s.remaining
	
    let will_mem_read s =
      List.exists
    	(fun a ->
    	  (match a with
    	  | Read_mem( _, _) -> true
(* 	  | Read_mem_reserve _ _ -> true *)
(* 	  | Read_mem_acq _ _ -> true *)
    	  | _ -> false
          ))
    	s.remaining
	
    let will_mem_write s =
      List.exists
    	(fun a ->
    	  (match a with
    	  | Write_mem( _, _) -> true
(* 	  | Write_mem_conditional _ _ _ -> true *)
(* 	  | Write_mem_rel _ _ -> true *)
    	  | _ -> false
          ))
    	s.remaining

    let will_mem_read_reserve s = 
      List.exists
    	(fun a ->
    	  (match a with
    	  | Read_mem_reserve( _, _) -> true
    	  | _ -> false
          ))
    	s.remaining      

    let will_mem_write_conditional s =
      List.exists
    	(fun a ->
    	  (match a with
    	  | Write_mem_conditional( _, _, _) -> true
    	  | _ -> false
          ))
    	s.remaining

    let will_mem_read_acquire s =
      List.exists
    	(fun a ->
    	  (match a with
	  | Read_mem_acq( _, _) -> true
    	  | _ -> false
          ))
    	s.remaining

    let will_mem_write_release s =
      List.exists
    	(fun a ->
    	  (match a with
	  | Write_mem_rel( _, _) -> true
    	  | _ -> false
          ))
    	s.remaining

    let will_mem s = 
       will_mem_read s         || (will_mem_write s 
    || (will_mem_read_acquire s || (will_mem_write_release s 
    || (will_mem_read_reserve s || will_mem_write_conditional s)))) 

    let will_branch s =
      List.exists
    	(fun a ->
    	  (match a with
    	  | Cond_branch( _, _) -> true
	  | Jump( _) -> true
    	  | _ -> false
          ))
    	s.remaining

    let regs_in_of_sem s =
      List.fold_left
    	(fun k a ->
    	  (match a with
    	  | Read_reg( r, _) -> Pset.add r k
    	  | _ -> k
          ))
    	(Pset.from_list Pervasives.compare []) s.remaining

    let regs_out_of_sem s =
      List.fold_left
    	(fun k a ->
    	  (match a with
    	  | Write_reg( r, _) -> Pset.add r k
    	  | _ -> k
          ))
    	(Pset.from_list Pervasives.compare []) s.remaining

     let regs_feeding_addresses s =
       let address_values =
         List.fold_left
          (fun k act ->
            (match act with
            | Read_mem( a, v) -> Pset.add a k
            | Write_mem( a, v) -> Pset.add a k
            | Read_mem_reserve( a, v) -> Pset.add a k
            | Write_mem_conditional( a, v1, v2) -> Pset.add a k
            | Read_mem_acq( a, v) -> Pset.add a k
            | Write_mem_rel( a, v) -> Pset.add a k
            | _ -> k
            ))
           (Pset.from_list Pervasives.compare []) s.remaining in
       let target_values =
         List.fold_left
          (fun k act ->
            (match act with
            | Binop( v1, op, v2, v3) -> if Pset.mem  v1  k then Pset.union  (Pset.from_list Pervasives.compare [v2;v3])  k else k
            | Unop( v1, op, v2) -> if Pset.mem  v1  k then Pset.add v2 k else k
            | _ -> k
            ))
          address_values s.remaining in
         List.fold_left
          (fun k act ->
            (match act with
            | Read_reg( r, a) -> if Pset.mem  a  target_values then Pset.add r k else k
            | _ -> k
            ))
           (Pset.from_list Pervasives.compare []) s.remaining

      let rec find_r s r =
	(match s with
(*	| [] -> Warn.user_error "Does not write to this register" *)
	| Write_reg(  r1, v1)  :: s ->
	    if r1 = r then v1 else find_r s r
	| _ :: s -> find_r s r
        )

    let val_written_to_register s r =
      subst_var s.val_soln (find_r s.remaining r)

    let mem_all_read_addresses s =
      List.fold_left
	(fun k a ->
	  (match a with
	  | Read_mem(  a, v)  -> Pset.add (subst_var s.val_soln a) k
	  | Read_mem_reserve(  a, v)  -> Pset.add (subst_var s.val_soln a) k
	  | Read_mem_acq(  a, v)  -> Pset.add (subst_var s.val_soln a) k
	  | _ -> k
          ))
	(Pset.from_list Pervasives.compare []) s.remaining

    let mem_all_write_addresses s =
      List.fold_left
	(fun k a ->
	  (match a with
	  | Write_mem(  a, v)  -> Pset.add (subst_var s.val_soln a) k
	  | Write_mem_conditional(  a, v1, v2) -> Pset.add (subst_var s.val_soln a) k
	  | Write_mem_rel(  a, v)  -> Pset.add (subst_var s.val_soln a) k
	  | _ -> k
          ))
	(Pset.from_list Pervasives.compare []) s.remaining

    let possibly_reads_from_address s a =
      let addrs = mem_all_read_addresses s in
      Pset.exists
	(fun addr ->   equalityPossible addr a)
	addrs

    let possibly_writes_to_address s a =
      let addrs = mem_all_write_addresses s in
      Pset.exists
	(fun addr ->   equalityPossible addr a)
	addrs

    (* true if w (a write-read-from by some read) is by thread tid and has the same address and value as some write in the behaviour s *)
    let write_possibly_done_by tid s w =
      List.exists
	(fun a ->
	  (match a with
	  | Write_mem(  a, v) -> 
	      tid = w.w_thread &&
	        (subst_var s.val_soln a = w.w_addr &&
	        (subst_var s.val_soln v = w.w_value))
	  | Write_mem_rel( a, v) ->
	      tid = w.w_thread &&
	        (subst_var s.val_soln a = w.w_addr &&
	        (subst_var s.val_soln v = w.w_value))
	  | Write_mem_conditional( a, v1, v2) ->
	      tid = w.w_thread &&
	        (subst_var s.val_soln a = w.w_addr &&
	        (subst_var s.val_soln v1 = w.w_value))
	  | _ -> false
          ))
	s.remaining

    let mem_writes_of tid ioid s =
      List.fold_right
	(fun a wk ->
	  (match a with
	  | Write_mem(  a, v)  ->
	      let wn =
		make_write_event tid ioid
		  (subst_var s.val_soln a)
		  (subst_var s.val_soln v) 
		  in
	      Pset.add wn wk
(* 	  | Write_mem_rel  a v  -> *)
(* 	      let wn = *)
(* 		make_write_release_event tid ioid *)
(* 		  (subst_var s.val_soln a) *)
(* 		  (subst_var s.val_soln v)  *)
(* 		  in *)
(* 	      Set.add wn wk *)
(* 	  | Write_mem_conditional a v1 v2 -> *)
(* 	      let wn = *)
(* 		make_write_release_event tid ioid *)
(* 		  (subst_var s.val_soln a) *)
(* 		  (subst_var s.val_soln v1) *)
(* 		  in *)
(* 	      Set.add wn wk *)
	  | _ -> wk
          ))
	s.remaining (Pset.empty Pervasives.compare)

    let mem_write_conditionals_of tid ioid s =
      List.fold_right
	(fun a wk ->
	  (match a with
	  | Write_mem_conditional(  a, v, succ) ->
	      let wn =
		make_write_event tid ioid
		  (subst_var s.val_soln a)
		  (subst_var s.val_soln v) 
		  in
	      Pset.add wn wk
	  | _ -> wk
          ))
	s.remaining (Pset.empty Pervasives.compare)

    let barriers_of tid ioid s =
      List.fold_right
	(fun a bk ->
	  (match a with
	  | Barrier( b) ->
	      let bn = make_barrier_event tid ioid b in
	      Pset.add bn bk
	  | _ -> bk
          ))
	s.remaining (Pset.empty Pervasives.compare)

    let mem_accept_wcond_action s succ =
      let vint = if succ then one else zero in
      (match s.remaining with
      | Write_mem_conditional( a, v, vsucc) :: rem' ->
	  (match vsucc with
	    | Flexible( uv) ->
		{ s with 
		 val_soln = Pmap.add uv vint s.val_soln }
(* 	    | Rigid _ -> Warn.user_error "Memory read to rigid variable" *)
	  )
      )

    let read_request_of tid ioid s =
      (match s.remaining with
      | (Read_mem( a, v)) :: _ -> make_read_request_event tid ioid (subst_var s.val_soln a)
      | (Read_mem_reserve( a, v)) :: _ -> make_read_request_event tid ioid (subst_var s.val_soln a)
      )

    let read_reserve_request_of tid ioid s =
      (match s.remaining with
      | (Read_mem_reserve( a, v)) :: _ -> make_read_request_event tid ioid (subst_var s.val_soln a)
      )

let known_memory_addresses s =
  List.for_all
    (fun a ->
      (match a with
      | Read_mem( a, v) -> is_determined (subst_var s.val_soln a)
      | Read_mem_reserve( a, v) -> is_determined (subst_var s.val_soln a)
      | Read_mem_acq( a, v) -> is_determined (subst_var s.val_soln a)
      | Write_mem( a, v) -> is_determined (subst_var s.val_soln a)
      | Write_mem_conditional( a, v, succ) -> is_determined (subst_var s.val_soln a)
      | Write_mem_rel( a, v) -> is_determined (subst_var s.val_soln a)
      | _ -> true
      ))
    s.remaining

let next_fetch_addr s =
  List.fold_left
    (fun k a ->
      (match a with
      | Jump( cst) -> Jump_to( cst)
      | Cond_branch( v, cst) -> Cond_branch_to( v, cst)
      | _ -> k
      ))
    (Next) s.remaining
    
let bit_lt = 0
let bit_gt = 1
let bit_eq = 2
    
let ppc_bitreg cr bit = PPC_reg( (CRBit( (32+4  *cr+bit))))

let empty_sem = {remaining = [];val_soln = (Pmap.empty Pervasives.compare)} 

let op3regs op set rD rA rB ist = 
  let (vA,ist') = fresh_var () ist in
  let (vB,ist'') = fresh_var () ist' in
  let (v,ist''') = fresh_var () ist'' in
  (match set with
  | DontSetCR0 ->
      ({empty_sem with
       remaining = [Read_reg( rA, vA) ;
		    Read_reg( rB, vB) ;
		    Binop(  v, op, vA, vB) ;
		    Write_reg( rD, v) ]},
	ist''')
  | SetCR0 ->
      let (vLt,ist'''') = fresh_var () ist''' in
      let (vGt,ist''''') = fresh_var () ist'''' in
      let (vEq,ist'''''') = fresh_var () ist''''' in
      ({empty_sem with
       remaining = [Read_reg( rA, vA) ;
		    Read_reg( rB, vB) ;
		    Binop(  v, op, vA, vB) ;
		    Binop(  vLt,     LtOp,  v,    zero) ;
 		    Binop(  vGt,     GtOp,  v,    zero) ; 
 		    Binop(  vEq,     EqOp,  v,    zero) ; 
		    Write_reg(  (ppc_bitreg 0 bit_lt),  vLt) ; 
		    Write_reg(  (ppc_bitreg 0 bit_gt),  vGt) ; 
		    Write_reg(  (ppc_bitreg 0 bit_eq),  vEq) ;
		    Write_reg( rD, v) ]},
	ist'''''')
  )

let op2regi op set rD rA vimm ist = 
  let (vA,ist') = fresh_var () ist in
  let (v,ist'') = fresh_var () ist' in
  (match set with
  | DontSetCR0 ->
      ({empty_sem with
       remaining = [Read_reg( rA, vA) ;
		    Binop(  v, op, vA, vimm) ;
		    Write_reg( rD, v) ]},
	ist'')
  | SetCR0 ->
      let (vLt,ist''') = fresh_var () ist'' in
      let (vGt,ist'''') = fresh_var () ist''' in
      let (vEq,ist''''') = fresh_var () ist'''' in
      ({empty_sem with
       remaining = [Read_reg( rA, vA) ;
		    Binop(  v, op, vA, vimm) ;
		    Binop(  vLt,     LtOp,  v,    zero) ;
		    Binop(  vGt,     GtOp,  v,    zero) ;
		    Binop(  vEq,     EqOp,  v,    zero) ;
		    Write_reg(  (ppc_bitreg 0 bit_lt),  vLt) ; 
		    Write_reg(  (ppc_bitreg 0 bit_gt),  vGt) ; 
		    Write_reg(  (ppc_bitreg 0 bit_eq),  vEq) ;
		    Write_reg( rD, v) ]},
	ist''''')
  )

	

let ppc_sem_of_instruction i ist =
  (match i with
  | Padd(  set, rD, rA, rB)  ->
      op3regs    (Add) set rD rA rB ist
  | Psub(  set, rD, rA, rB)  ->
      op3regs    (Sub) set rD rB rA ist (* subtract from -> swap args *)
  | Por(  set, rD, rA, rB)  ->
      op3regs    (Or) set rD rA rB ist
  | Pand(  set, rD, rA, rB)  ->
      op3regs    (And) set rD rA rB ist
  | Pxor(  set, rD, rA, rB)  ->
      op3regs    (Xor) set rD rA rB ist
  | Pmull(  set, rD, rA, rB)  ->
      op3regs    (Mul) set rD rA rB ist
  | Pdiv(  set, rD, rA, rB)  ->
      op3regs    (Div) set rD rA rB ist

  | Pmr(  rD, rS)  ->
      let (v,ist') = fresh_var () ist in
      ({empty_sem with 
       remaining = [Read_reg( rS, v) ;
		    Write_reg( rD, v) ]},
	ist')

  | Pli(  rD, v)  ->
      ({empty_sem with
       remaining = [Write_reg( rD, (  intToV v)) ]},
	ist)

  | Paddi(  rD, (PPC_reg((Ireg( GPR0)))), v)  ->
      ({empty_sem with
       remaining = [Write_reg( rD, (  intToV v)) ]},
	ist)

  | Paddi(  rD, rA, simm)  ->
      op2regi    (Add) (DontSetCR0) rD rA (  intToV simm) ist
  | Pori(  rD, rA, simm)  ->
      op2regi    (Or) (DontSetCR0) rD rA (  intToV simm) ist
  | Pxori(  rD, rA, simm)  ->
      op2regi    (Xor) (DontSetCR0) rD rA (  intToV simm) ist
  | Pandi(  rD, rA, simm)  ->
      (* ISA p. 75: CR0 is set *)
      op2regi    (And) (SetCR0) rD rA (  intToV simm) ist
  | Pmulli(  rD, rA, simm)  ->
      op2regi    (Mul) (DontSetCR0) rD rA (  intToV simm) ist
	
  | Pb( lbl) -> ({empty_sem with remaining = [Jump( (Symbolic( lbl)))]},ist)

  | Pbcc(  Lt, lbl)  ->
      let (v,ist') = fresh_var () ist in
      ({empty_sem with
       remaining = [Read_reg( (ppc_bitreg 0 bit_lt), v) ;
		    Cond_branch(  v, (Symbolic( lbl)))]},
	ist')
  | Pbcc(  Ge, lbl)  ->
      let (v,ist') = fresh_var () ist in
      let (vn,ist'') = fresh_var () ist' in
      ({empty_sem with
       remaining = [Read_reg( (ppc_bitreg 0 bit_lt), v) ;
		    Unop(  vn,    Not, v) ;
		    Cond_branch(  vn, (Symbolic( lbl)))]},
	ist'')
  | Pbcc(  Gt, lbl)  ->
      let (v,ist') = fresh_var () ist in
      ({empty_sem with
       remaining = [Read_reg( (ppc_bitreg 0 bit_gt), v) ;
		    Cond_branch(  v, (Symbolic( lbl)))]},
	ist')
  | Pbcc(  Le, lbl)  ->
      let (v,ist') = fresh_var () ist in
      let (vn,ist'') = fresh_var () ist' in
      ({empty_sem with
       remaining = [Read_reg( (ppc_bitreg 0 bit_gt), v) ;
		    Unop(  vn,    Not, v) ;
		    Cond_branch(  vn, (Symbolic( lbl)))]},
	ist'')
  | Pbcc(  Eq, lbl)  ->
      let (v,ist') = fresh_var () ist in
      ({empty_sem with
       remaining = [Read_reg( (ppc_bitreg 0 bit_eq), v) ;
		    Cond_branch(  v, (Symbolic( lbl)))]},
	ist')
  | Pbcc(  Ne, lbl)  ->
      let (v,ist') = fresh_var () ist in
      let (vn,ist'') = fresh_var () ist' in
      ({empty_sem with
       remaining = [Read_reg( (ppc_bitreg 0 bit_eq), v) ;
		    Unop(  vn,    Not, v) ;
		    Cond_branch(  vn, (Symbolic( lbl)))]},
	ist'')

  | Pcmpwi(  cr, rA, v)  ->
      let (vA,ist') = fresh_var () ist in
      let (vLt,ist'') = fresh_var () ist' in
      let (vGt,ist''') = fresh_var () ist'' in
      let (vEq,ist'''') = fresh_var () ist''' in
      ({empty_sem with
       remaining = [Read_reg(  rA,  vA) ;
		    Binop(  vLt,     LtOp,  vA,  (  intToV v)) ;
		    Binop(  vGt,     GtOp,  vA,  (  intToV v)) ;
		    Binop(  vEq,     EqOp,  vA,  (  intToV v)) ;
		    Write_reg(  (ppc_bitreg cr bit_lt),  vLt) ;  (*TODO*)
		    Write_reg(  (ppc_bitreg cr bit_gt),  vGt) ;
		    Write_reg(  (ppc_bitreg cr bit_eq),  vEq) ]},
	ist'''')
  | Pcmpw(  cr, rA, rB)  ->
      let (vA,ist') = fresh_var () ist in
      let (vB,ist'') = fresh_var () ist' in
      let (vLt,ist''') = fresh_var () ist'' in
      let (vGt,ist'''') = fresh_var () ist''' in
      let (vEq,ist''''') = fresh_var () ist'''' in
      ({empty_sem with
       remaining = [Read_reg(  rA,  vA) ;
		    Read_reg(  rB,  vB) ;
		    Binop(  vLt,     LtOp,  vA,  vB) ;
		    Binop(  vGt,     GtOp,  vA,  vB) ;
		    Binop(  vEq,     EqOp,  vA,  vB) ;
		    Write_reg(  (ppc_bitreg cr bit_lt),  vLt) ;
		    Write_reg(  (ppc_bitreg cr bit_gt),  vGt) ;
		    Write_reg(  (ppc_bitreg cr bit_eq),  vEq) ]},
	ist''''')

  | Plwz( rD, d, rA)  ->
      let (aA,ist') = fresh_var () ist in
      let (a,ist'') = fresh_var () ist' in
      let (v,ist''') = fresh_var () ist'' in
      ({empty_sem with
       remaining = [Read_reg( rA, aA) ;
		    Binop(  a,    Add, aA, (  intToV d)) ;
		    Read_mem( a, v) ;
		    Write_reg(  rD, v) ]},
	ist''')
  | Pld( rD, d, rA)  ->
      let (aA,ist') = fresh_var () ist in
      let (a,ist'') = fresh_var () ist' in
      let (v,ist''') = fresh_var () ist'' in
      ({empty_sem with
       remaining = [Read_reg( rA, aA) ;
		    Binop(  a,    Add, aA, (  intToV d)) ;
		    Read_mem( a, v) ;
		    Write_reg(  rD, v) ]},
	ist''')
  | Plwzx( rD, (PPC_reg((Ireg( GPR0)))), rB)  ->
      let (aB,ist') = fresh_var () ist in
      let (a,ist'') = fresh_var () ist' in
      let (v,ist''') = fresh_var () ist'' in
      ({empty_sem with
       remaining = [Read_reg( rB, aB) ;
		    Binop(  a,    Add, aB, (  intToV 0)) ; (* Can be optimized *)
		    Read_mem( a, v) ;
		    Write_reg(  rD, v) ]},
	ist''')

  | Pldx( rD, (PPC_reg((Ireg( GPR0)))), rB)  ->
      let (aB,ist') = fresh_var () ist in
      let (a,ist'') = fresh_var () ist' in
      let (v,ist''') = fresh_var () ist'' in
      ({empty_sem with
       remaining = [Read_reg( rB, aB) ;
		    Binop(  a,    Add, aB, (  intToV 0)) ; (* Can be optimized *)
		    Read_mem( a, v) ;
		    Write_reg(  rD, v) ]},
	ist''')
  | Plwzx( rD, rA, rB)  ->
      let (aA,ist') = fresh_var () ist in
      let (aB,ist'') = fresh_var () ist' in
      let (a,ist''') = fresh_var () ist'' in
      let (v,ist'''') = fresh_var () ist''' in
      ({empty_sem with
       remaining = [Read_reg( rA, aA) ;
		    Read_reg( rB, aB) ;
		    Binop(  a,    Add, aA, aB) ;
		    Read_mem( a, v) ;
		    Write_reg(  rD, v) ]},
	ist'''')
  | Pldx( rD, rA, rB)  ->
      let (aA,ist') = fresh_var () ist in
      let (aB,ist'') = fresh_var () ist' in
      let (a,ist''') = fresh_var () ist'' in
      let (v,ist'''') = fresh_var () ist''' in
      ({empty_sem with
       remaining = [Read_reg( rA, aA) ;
		    Read_reg( rB, aB) ;
		    Binop(  a,    Add, aA, aB) ;
		    Read_mem( a, v) ;
		    Write_reg(  rD, v) ]},
	ist'''')

  | Pstw( rS, d, rA)  ->
      let (vS,ist') = fresh_var () ist in
      let (aA,ist'') = fresh_var () ist' in
      let (a,ist''') = fresh_var () ist'' in
      ({empty_sem with
       remaining = [Read_reg( rA, aA) ;
		    Binop(  a,    Add, aA, (  intToV d)) ;
		    Read_reg( rS, vS) ;
		    Write_mem( a, vS) ]},
	ist''')
  | Pstd( rS, d, rA)  ->
      let (vS,ist') = fresh_var () ist in
      let (aA,ist'') = fresh_var () ist' in
      let (a,ist''') = fresh_var () ist'' in
      ({empty_sem with
       remaining = [Read_reg( rA, aA) ;
		    Binop(  a,    Add, aA, (  intToV d)) ;
		    Read_reg( rS, vS) ;
		    Write_mem( a, vS) ]},
	ist''')


  | Pstwx( rS, (PPC_reg((Ireg( GPR0)))), rB)  ->
      let (vS,ist') = fresh_var () ist in
      let (aB,ist'') = fresh_var () ist' in
      let (a,ist''') = fresh_var () ist'' in
      ({empty_sem with
       remaining = [Read_reg( rB, aB) ;
		    Binop(  a,    Add, aB, (  intToV 0)) ; (* Can be optimized *)
		    Read_reg( rS, vS) ;
		    Write_mem( a, vS) ]},
	ist''')
  | Pstdx( rS, (PPC_reg((Ireg( GPR0)))), rB)  ->
      let (vS,ist') = fresh_var () ist in
      let (aB,ist'') = fresh_var () ist' in
      let (a,ist''') = fresh_var () ist'' in
      ({empty_sem with
       remaining = [Read_reg( rB, aB) ;
		    Binop(  a,    Add, aB, (  intToV 0)) ; (* Can be optimized *)
		    Read_reg( rS, vS) ;
		    Write_mem( a, vS) ]},
	ist''')
  | Pstwx( rS, rA, rB)  ->
      let (vS,ist') = fresh_var () ist in
      let (aA,ist'') = fresh_var () ist' in
      let (aB,ist''') = fresh_var () ist'' in
      let (a,ist'''') = fresh_var () ist''' in
      ({empty_sem with
       remaining = [Read_reg( rA, aA) ;
		    Read_reg( rB, aB) ;
		    Binop(  a,    Add, aA, aB) ;
		    Read_reg( rS, vS) ;
		    Write_mem( a, vS) ]},
	ist'''')
  | Pstdx( rS, rA, rB)  ->
      let (vS,ist') = fresh_var () ist in
      let (aA,ist'') = fresh_var () ist' in
      let (aB,ist''') = fresh_var () ist'' in
      let (a,ist'''') = fresh_var () ist''' in
      ({empty_sem with
       remaining = [Read_reg( rA, aA) ;
		    Read_reg( rB, aB) ;
		    Binop(  a,    Add, aA, aB) ;
		    Read_reg( rS, vS) ;
		    Write_mem( a, vS) ]},
	ist'''')
	
  | Plwarx( rD, (PPC_reg((Ireg( GPR0)))), rB) -> 
      let (aB,ist') = fresh_var () ist in
      let (a,ist'') = fresh_var () ist' in
      let (v,ist''') = fresh_var () ist'' in
      ({empty_sem with
       remaining = [Read_reg( rB, aB) ;
		    Binop(  a,    Add, aB, (  intToV 0)) ; (* Can be optimized *)
		    Read_mem_reserve( a, v) ;
		    Write_reg(  rD, v) ]},
	ist''')
  | Plwarx( rD, rA, rB)  ->
      let (aA,ist') = fresh_var () ist in
      let (aB,ist'') = fresh_var () ist' in
      let (a,ist''') = fresh_var () ist'' in
      let (v,ist'''') = fresh_var () ist''' in
      ({empty_sem with
       remaining = [Read_reg( rA, aA) ;
		    Read_reg( rB, aB) ;
		    Binop(  a,    Add, aA, aB) ;
		    Read_mem_reserve( a, v) ;
		    Write_reg(  rD, v) ]},
	ist'''')
  | Pstwcx( rS, (PPC_reg((Ireg( GPR0)))), rB)  ->
      let (vS,ist') = fresh_var () ist in
      let (aB,ist'') = fresh_var () ist' in
      let (a,ist''') = fresh_var () ist'' in
      let (succ,ist'''') = fresh_var () ist''' in
      ({empty_sem with
       remaining = [Read_reg( rB, aB) ;
		    Binop(  a,    Add, aB, (  intToV 0)) ; (* Can be optimized *)
		    Read_reg( rS, vS) ;
		    Write_mem_conditional( a, vS, succ);
		    Write_reg(  (ppc_bitreg 0 bit_lt),  (intToV 0)) ; 
		    Write_reg(  (ppc_bitreg 0 bit_gt),  (intToV 0)) ; 
		    Write_reg(  (ppc_bitreg 0 bit_eq),  succ) ]},
	ist'''')
  | Pstwcx( rS, rA, rB) -> 
      let (vS,ist') = fresh_var () ist in
      let (aA,ist'') = fresh_var () ist' in
      let (aB,ist''') = fresh_var () ist'' in
      let (a,ist'''') = fresh_var () ist''' in
      let (succ,ist''''') = fresh_var () ist'''' in
      ({empty_sem with
       remaining = [Read_reg( rA, aA) ;
		    Read_reg( rB, aB) ;
		    Binop(  a,    Add, aA, aB) ;
		    Read_reg( rS, vS) ;
		    Write_mem_conditional( a, vS, succ);
		    Write_reg(  (ppc_bitreg 0 bit_lt),  (intToV 0)) ; 
		    Write_reg(  (ppc_bitreg 0 bit_gt),  (intToV 0)) ; 
		    Write_reg(  (ppc_bitreg 0 bit_eq),  succ) ]},
	ist''''')

  | Psync -> ({empty_sem with remaining = [Barrier( Sync)]},ist)
  | Pisync -> ({empty_sem with remaining = [Isync]},ist)
  | Plwsync -> ({empty_sem with remaining = [Barrier( LwSync)]},ist)
  | Peieio -> ({empty_sem with remaining = [Barrier( Eieio)]},ist)
  | Pdcbf( _, _) -> (empty_sem,ist)

  | Plwzx( rD, (PPC_reg((Ireg( GPR0)))), rB)  ->
      let (aB,ist') = fresh_var () ist in
      let (a,ist'') = fresh_var () ist' in
      let (v,ist''') = fresh_var () ist'' in
      ({empty_sem with
       remaining = [Read_reg( rB, aB) ;
		    Binop(  a,    Add, aB, (  intToV 0)) ; (* Can be optimized *)
		    Read_mem_acq( a, v) ;
		    Write_reg(  rD, v) ]},
	ist''')
  | Plwzx( rD, rA, rB)  ->
      let (aA,ist') = fresh_var () ist in
      let (aB,ist'') = fresh_var () ist' in
      let (a,ist''') = fresh_var () ist'' in
      let (v,ist'''') = fresh_var () ist''' in
      ({empty_sem with
       remaining = [Read_reg( rA, aA) ;
		    Read_reg( rB, aB) ;
		    Binop(  a,    Add, aA, aB) ;
		    Read_mem_acq( a, v) ;
		    Write_reg(  rD, v) ]},
	ist'''')

(* huh? why are these Write_mem_rel?  And isn't Lem supposed to complain at duplicate cases? *)

  | Pstwx( rS, (PPC_reg((Ireg( GPR0)))), rB)  ->
      let (vS,ist') = fresh_var () ist in
      let (aB,ist'') = fresh_var () ist' in
      let (a,ist''') = fresh_var () ist'' in
      ({empty_sem with
       remaining = [Read_reg( rB, aB) ;
		    Binop(  a,    Add, aB, (  intToV 0)) ; (* Can be optimized *)
		    Read_reg( rS, vS) ;
		    Write_mem_rel( a, vS) ]},
	ist''')
  | Pstwx( rS, rA, rB)  ->
      let (vS,ist') = fresh_var () ist in
      let (aA,ist'') = fresh_var () ist' in
      let (aB,ist''') = fresh_var () ist'' in
      let (a,ist'''') = fresh_var () ist''' in
      ({empty_sem with
       remaining = [Read_reg( rA, aA) ;
		    Read_reg( rB, aB) ;
		    Binop(  a,    Add, aA, aB) ;
		    Read_reg( rS, vS) ;
		    Write_mem_rel( a, vS) ]},
	ist'''')
  )


(*: arm instruction semantics *)

let arm_bitreg_eq = ARM_reg( (Z))            (* hack: use Z register for EQ bit *)

let arm_op3regs op set rD rA rB ist = 
  let (vA,ist') = fresh_var () ist in
  let (vB,ist'') = fresh_var () ist' in
  let (v,ist''') = fresh_var () ist'' in
  (match set with
  | DontSetFlags ->
      ({empty_sem with
       remaining = [Read_reg( rA, vA) ;
		    Read_reg( rB, vB) ;
		    Binop(  v, op, vA, vB) ;
		    Write_reg( rD, v) ]},
	ist''')
  | SetFlags ->
(*       let (vLt,ist'''') = fresh_var () ist''' in *)
(*       let (vGt,ist''''') = fresh_var () ist'''' in *)
      let (vEq,ist'''') = fresh_var () ist''' in
      ({empty_sem with
       remaining = [Read_reg( rA, vA) ;
		    Read_reg( rB, vB) ;
		    Binop(  v, op, vA, vB) ;
(* 		    Binop  vLt     LtOp  v    zero ; *)
(*  		    Binop  vGt     GtOp  v    zero ;  *)
 		    Binop(  vEq,     EqOp,  v,    zero) ; 
(* 		    Write_reg  (ppc_bitreg 0 bit_lt)  vLt ;  *)
(* 		    Write_reg  (ppc_bitreg 0 bit_gt)  vGt ;  *)
		    Write_reg(  (arm_bitreg_eq),  vEq) ;            
		    Write_reg( rD, v) ]},
	ist'''')
  )

let arm_op2regi op set rD rA vimm ist = 
  let (vA,ist') = fresh_var () ist in
  let (v,ist'') = fresh_var () ist' in
  (match set with
  | DontSetFlags ->
      ({empty_sem with
       remaining = [Read_reg( rA, vA) ;
		    Binop(  v, op, vA, vimm) ;
		    Write_reg( rD, v) ]},
	ist'')
  | SetFlags ->
(*       let (vLt,ist''') = fresh_var () ist'' in *)
(*       let (vGt,ist'''') = fresh_var () ist''' in *)
      let (vEq,ist''') = fresh_var () ist'' in
      ({empty_sem with
       remaining = [Read_reg( rA, vA) ;
		    Binop(  v, op, vA, vimm) ;
(* 		    Binop  vLt     LtOp  v    zero ; *)
(* 		    Binop  vGt     GtOp  v    zero ; *)
		    Binop(  vEq,     EqOp,  v,    zero) ;
(* 		    Write_reg  (ppc_bitreg 0 bit_lt)  vLt ;  *)
(* 		    Write_reg  (ppc_bitreg 0 bit_gt)  vGt ;  *)
		    Write_reg(  (arm_bitreg_eq),  vEq) ;
		    Write_reg( rD, v) ]},
	ist''')
  )


let arm_sem_of_instruction i ist =
  (match i with
  | I_ADD3(  set, rD, rA, rB)  ->
      arm_op3regs    (Add) set rD rA rB ist
  | I_SUB3(  set, rD, rA, rB)  ->
      arm_op3regs    (Sub) set rD rB rA ist (* subtract from -> swap args *)
  | I_XOR(  set, rD, rA, rB)  ->
      arm_op3regs    (Xor) set rD rA rB ist
  | I_MOV(  rD, rS, c) ->                                (* TODO: CONDITION *)
      let (v,ist') = fresh_var () ist in
      ({empty_sem with 
       remaining = [Read_reg( rS, v) ;
		    Write_reg( rD, v) ]},
	ist')
  | I_MOVI(  rD, v, c)  ->                                (* TODO: CONDITION *)
      ({empty_sem with
       remaining = [Write_reg( rD, (  intToV v)) ]},
	ist)

  | I_ADD( set, rD, rA, simm)  ->
      arm_op2regi    (Add) set rD rA (  intToV simm) ist
  | I_SUB( set, rD, rA, simm)  ->
      arm_op2regi    (Sub) set rD rA (  intToV simm) ist
  | I_AND( set, rD, rA, simm)  ->
      arm_op2regi    (And) set rD rA (  intToV simm) ist
	
  | I_B( lbl) -> ({empty_sem with remaining = [Jump( (Symbolic( lbl)))]},ist)

  | I_BEQ( lbl)  ->
      let (v,ist') = fresh_var () ist in
      ({empty_sem with
       remaining = [Read_reg( (arm_bitreg_eq), v) ;
		    Cond_branch(  v, (Symbolic( lbl)))]},
	ist')
  | I_BNE( lbl)  ->
      let (v,ist') = fresh_var () ist in
      let (vn,ist'') = fresh_var () ist' in
      ({empty_sem with
       remaining = [Read_reg( (arm_bitreg_eq), v) ;
		    Unop(  vn,    Not, v) ;
		    Cond_branch(  vn, (Symbolic( lbl)))]},
	ist'')

  | I_CMPI( rA, v)  ->
      let (vA,ist') = fresh_var () ist in
(*       let (vLt,ist'') = fresh_var () ist' in *)
(*       let (vGt,ist''') = fresh_var () ist'' in *)
      let (vEq,ist'''') = fresh_var () ist' in
      ({empty_sem with
       remaining = [Read_reg(  rA,  vA) ;
(* 		    Binop  vLt     LtOp  vA  (  intToV v) ; *)
(* 		    Binop  vGt     GtOp  vA  (  intToV v) ; *)
		    Binop(  vEq,     EqOp,  vA,  (  intToV v)) ;
(* 		    Write_reg  (ppc_bitreg cr bit_lt)  vLt ; *)
(* 		    Write_reg  (ppc_bitreg cr bit_gt)  vGt ; *)
		    Write_reg(  (arm_bitreg_eq),  vEq) ]},
	ist'''')
  | I_CMP(  rA, rB)  ->
      let (vA,ist') = fresh_var () ist in
      let (vB,ist'') = fresh_var () ist' in
(*       let (vLt,ist''') = fresh_var () ist'' in *)
(*       let (vGt,ist'''') = fresh_var () ist''' in *)
      let (vEq,ist''''') = fresh_var () ist'' in
      ({empty_sem with
       remaining = [Read_reg(  rA,  vA) ;
		    Read_reg(  rB,  vB) ;
(* 		    Binop  vLt     LtOp  vA  vB ; *)
(* 		    Binop  vGt     GtOp  vA  vB ; *)
		    Binop(  vEq,     EqOp,  vA,  vB) ;
(* 		    Write_reg  (ppc_bitreg cr bit_lt)  vLt ; *)
(* 		    Write_reg  (ppc_bitreg cr bit_gt)  vGt ; *)
		    Write_reg(  (arm_bitreg_eq),  vEq) ]},
	ist''''')

  | I_LDR3( rD, rB, rA, c) ->
      let (aA,ist') = fresh_var () ist in
      let (aB,ist'') = fresh_var () ist' in
      let (a,ist''') = fresh_var () ist'' in
      let (v,ist'''') = fresh_var () ist''' in
      ({empty_sem with
       remaining = [Read_reg( rA, aA) ;
                    Read_reg( rB, aB) ;
		    Binop(  a,    Add, aA, aB) ;
		    Read_mem( a, v) ;
		    Write_reg(  rD, v) ]},
	ist'''')
  | I_LDR( rD, rA, c) ->
      let (aA,ist') = fresh_var () ist in
(*       let (a,ist'') = fresh_var () ist' in *)
      let (v,ist''') = fresh_var () ist' in
      ({empty_sem with
       remaining = [Read_reg( rA, aA) ;
		    (*Binop  a    Add aA (  intToV d) ;*)
		    Read_mem( aA, v) ;
		    Write_reg(  rD, v) ]},
	ist''')

  | I_STR3( rS, rB, rA, c) ->                                  (* TODO CONDITION *)
      let (vS,ist') = fresh_var () ist in
      let (aA,ist'') = fresh_var () ist' in
      let (aB,ist''') = fresh_var () ist'' in
      let (a,ist'''') = fresh_var () ist''' in
      ({empty_sem with
       remaining = [Read_reg( rA, aA) ;
		    Read_reg( rB, aB) ;
		    Binop(  a,    Add, aA, aB) ;
                    Read_reg( rS, vS) ;
		    Write_mem( a, vS) ]},
	ist'''')
  | I_STR( rS, rA, c) ->                                    (* TODO CONDITION *)
      let (vS,ist') = fresh_var () ist in
      let (aA,ist'') = fresh_var () ist' in
(*       let (a,ist''') = fresh_var () ist'' in *)
      ({empty_sem with
       remaining = [Read_reg( rA, aA) ;
(* 		    Binop  a    Add aA (  intToV d) ; *)
		    Read_reg( rS, vS) ;
		    Write_mem( aA, vS) ]},
	ist'')

  | I_LDREX( rD, rB) -> 
      let (aB,ist') = fresh_var () ist in
      let (a,ist'') = fresh_var () ist' in
      let (v,ist''') = fresh_var () ist'' in
      ({empty_sem with
       remaining = [Read_reg( rB, aB) ;
		    Binop(  a,    Add, aB, (  intToV 0)) ; (* Can be optimized *)
		    Read_mem_reserve( a, v) ;
		    Write_reg(  rD, v) ]},
	ist''')

  | I_STREX( rS, rB)  ->
      let (vS,ist') = fresh_var () ist in
      let (aB,ist'') = fresh_var () ist' in
      let (a,ist''') = fresh_var () ist'' in
      let (succ,ist'''') = fresh_var () ist''' in
      ({empty_sem with
       remaining = [Read_reg( rB, aB) ;
		    Binop(  a,    Add, aB, (  intToV 0)) ; (* Can be optimized *)
		    Read_reg( rS, vS) ;
		    Write_mem_conditional( a, vS, succ);
(* 		    Write_reg  (ppc_bitreg 0 bit_lt)  (intToV 0) ;  *)
(* 		    Write_reg  (ppc_bitreg 0 bit_gt)  (intToV 0) ;  *)
		    Write_reg(  (arm_bitreg_eq),  succ) ]},
	ist'''')

  | I_DSB -> ({empty_sem with remaining = [Barrier( Sync)]},ist)
  | I_DMB -> ({empty_sem with remaining = [Barrier( Sync)]},ist)
  | I_ISB -> ({empty_sem with remaining = [Isync]},ist)

  )

let sem_of_instruction i ist = 
  (match i with
  | PPC_ins( i') -> ppc_sem_of_instruction i' ist
  | ARM_ins( i') -> arm_sem_of_instruction i' ist
  )

(* Assume each instruction is 4 bytes *)
let succeeding_instruction_address a = op (Add) a (intToV 4)
(* Pick a starting instruction address for a thread: 
   In reality it will differ by thread *)
let initial_instruction_address t = zero
