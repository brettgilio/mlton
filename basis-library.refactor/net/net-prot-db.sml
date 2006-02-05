(* Copyright (C) 2002-2005 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 *
 * MLton is released under a BSD-style license.
 * See the file MLton-LICENSE for details.
 *)

structure NetProtDB: NET_PROT_DB =
   struct
      structure Prim = PrimitiveFFI.NetProtDB

      datatype entry = T of {name: string,
                             aliases: string list,
                             protocol: int}

      local
        fun make s (T r) = s r
      in
        val name = make #name
        val aliases = make #aliases
        val protocol = make #protocol
      end

      local
        fun get (b: bool): entry option =
          if b
            then let
                   val name = COld.CS.toString (Prim.getEntryName ())
                   val numAliases = Prim.getEntryAliasesNum ()
                   fun fill (n, aliases) =
                     if n < numAliases
                       then let
                              val alias =
                                COld.CS.toString (Prim.getEntryAliasesN n)
                            in
                              fill (n + 1, alias::aliases)
                            end
                       else List.rev aliases
                   val aliases = fill (0, [])
                   val protocol = Prim.getEntryProto ()
                 in
                   SOME (T {name = name,
                            aliases = aliases,
                            protocol = protocol})
                 end
            else NONE
      in
        fun getByName name = 
          get (Prim.getByName (NullString.nullTerm name))
        fun getByNumber proto = 
          get (Prim.getByNumber proto)
      end
   end
