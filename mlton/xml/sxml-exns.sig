(* Copyright (C) 1999-2005 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a HPND-style license.
 * See the file MLton-LICENSE for details.
 *)

signature SXML_EXNS = XML

(*
 invariants:
 * no PolyVal decs
 * hasExns = true
 * tyvar lists in datatype, val, and fun decs are always empty
 * type lists are empty for variable args and for non-built-in-constructor args
 * no tyvars in types
 *)
