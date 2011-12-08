(*********************************************************************)
(*                        Memevents                                  *)
(*                                                                   *)
(* Jade Alglave, Luc Maranget, INRIA Paris-Rocquencourt, France.     *)
(* Susmit Sarkar, Peter Sewell, University of Cambridge, UK.         *)
(*                                                                   *)
(*  Copyright 2010 Institut National de Recherche en Informatique et *)
(*  en Automatique and the authors. All rights reserved.             *)
(*  This file is distributed  under the terms of the Lesser GNU      *)
(*  General Public License.                                          *)
(*********************************************************************)

open ConstrGen

module Make(A:Arch.S) : sig
  val allocate_regs : A.pseudo MiscParser.t ->
    ((A.location * A.V.v) list,
     (int * A.pseudo list) list,
     (A.location, A.V.v) prop constr,
     A.location)
      MiscParser.result
end
