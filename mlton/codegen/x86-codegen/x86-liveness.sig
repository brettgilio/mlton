type int = Int.t
type word = Word.t

signature X86_LIVENESS_STRUCTS =
  sig
    structure x86: X86
    val livenessClasses : x86.ClassSet.t
  end

signature X86_LIVENESS =
  sig
    include X86_LIVENESS_STRUCTS

    structure LiveSet: SET
    sharing type LiveSet.Element.t = x86.MemLoc.t

    val track : x86.MemLoc.t -> bool

    structure LiveInfo:
      sig
	type t
	val newLiveInfo : unit -> t

	val setLiveOperands : t * x86.Label.t * x86.Operand.t list -> unit
	val setLive : t * x86.Label.t * LiveSet.t -> unit
	val getLive : t * x86.Label.t -> LiveSet.t
	val completeLiveInfo : {chunk: x86.Chunk.t,
				liveInfo: t,
				pass: string} -> unit
	val completeLiveInfo_msg : unit -> unit
	val verifyLiveInfo : {chunk: x86.Chunk.t,
			      liveInfo: t} -> bool
	val verifyLiveInfo_msg : unit -> unit
      end

    structure Liveness:
      sig
	type t = {liveIn: LiveSet.t,
		  liveOut: LiveSet.t,
		  dead: LiveSet.t}
      end

    structure LivenessBlock:
      sig
	datatype t = T of {entry: (x86.Entry.t * Liveness.t),
			   profileInfo: x86.ProfileInfo.t,
			   statements: (x86.Assembly.t * Liveness.t) list,
			   transfer: (x86.Transfer.t * Liveness.t)}

	val toString : t -> string
	val printBlock : t -> unit
	val toLivenessEntry : {entry: x86.Entry.t,
			       live: LiveSet.t} ->
	                      {entry: (x86.Entry.t * Liveness.t),
			       live: LiveSet.t}
	val reLivenessEntry : {entry: (x86.Entry.t * Liveness.t),
			       live: LiveSet.t} ->
	                      {entry: (x86.Entry.t * Liveness.t),
			       live: LiveSet.t}
	val toLivenessStatements : {statements: x86.Assembly.t list,
				    live: LiveSet.t} ->
                                   {statements: (x86.Assembly.t * Liveness.t) list,
				    live: LiveSet.t}
	val reLivenessStatements : {statements: (x86.Assembly.t * Liveness.t) list,
				    live: LiveSet.t} ->
                                   {statements: (x86.Assembly.t * Liveness.t) list,
				    live: LiveSet.t}
	val toLivenessTransfer : {transfer: x86.Transfer.t,
				  liveInfo: LiveInfo.t} ->
	                         {transfer: (x86.Transfer.t * Liveness.t),
				  live: LiveSet.t}
	val reLivenessTransfer : {transfer: (x86.Transfer.t * Liveness.t)} ->
	                         {transfer: (x86.Transfer.t * Liveness.t),
				  live: LiveSet.t}
	val toLivenessBlock : {block: x86.Block.t, liveInfo: LiveInfo.t} -> t
	val toLivenessBlock_msg : unit -> unit
	val verifyLivenessBlock : {block: t,
				   liveInfo: LiveInfo.t} -> bool
	val verifyLivenessBlock_msg : unit -> unit
	val toBlock : {block: t} -> x86.Block.t	  
	val toBlock_msg : unit -> unit
      end
  end

