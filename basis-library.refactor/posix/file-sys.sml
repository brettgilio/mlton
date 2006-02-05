(* Copyright (C) 1999-2005 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 * Copyright (C) 1997-2000 NEC Research Institute.
 *
 * MLton is released under a BSD-style license.
 * See the file MLton-LICENSE for details.
 *)

structure PosixFileSys: POSIX_FILE_SYS_EXTRA =
   struct
      structure Error = PosixError

      (* Patch to make Time look like it deals with Int.int
       * instead of LargeInt.int.
       *)
      structure Time =
         struct
            open Time

            val fromSeconds = fromSeconds o LargeInt.fromInt

            fun toSeconds t =
               LargeInt.toInt (Time.toSeconds t)
               handle Overflow => Error.raiseSys Error.inval
         end
      
      structure SysCall = Error.SysCall
      structure Prim = PrimitiveFFI.Posix.FileSys
      open Prim
      structure Stat = Prim.Stat
      structure Flags = BitFlags

      type file_desc = C_Fd.t
      type uid = C_UId.t
      type gid = C_GId.t

      val fdToWord = Primitive.FileDesc.toWord
      val wordToFD = Primitive.FileDesc.fromWord
      val fdToIOD = OS.IO.fromFD
      val iodToFD = SOME o OS.IO.toFD

      (*------------------------------------*)
      (*             dirstream              *)
      (*------------------------------------*)

      local
         structure Prim = Prim.Dirstream
         datatype dirstream = DS of C_DirP.t option ref

         fun get (DS r) =
            case !r of
               NONE => Error.raiseSys Error.badf
             | SOME d => d
      in
         type dirstream = dirstream
            
         fun opendir s =
            let
               val s = NullString.nullTerm s
            in
               SysCall.syscall
               (fn () =>
                let
                   val d = Prim.openDir s
                   val p = Primitive.Pointer.fromWord d
                in
                   (if Primitive.Pointer.isNull p then ~1 else 0,
                    fn () => DS (ref (SOME d)))
                end)
            end

         fun readdir d =
            let
               val d = get d
               fun loop () =
                  let
                     val res =
                        SysCall.syscallErr
                        ({clear = true, restart = false},
                         fn () =>
                         let
                            val cs = Prim.readDir d
                         in
                            {return = if Primitive.Pointer.isNull cs
                                         then ~1
                                      else 0,
                             post = fn () => SOME cs,
                             handlers = [(Error.cleared, fn () => NONE),
                                         (* MinGW sets errno to ENOENT when it
                                          * returns NULL.
                                          *)
                                         (Error.noent, fn () => NONE)]}
                         end)
                  in
                     case res of
                        NONE => NONE
                      | SOME cs => 
                           let
                              val s = COld.CS.toString cs
                           in
                              if s = "." orelse s = ".."
                                 then loop ()
                              else SOME s
                           end
                  end
            in loop ()
            end

         fun rewinddir d =
            let val d = get d
            in 
               SysCall.syscallErr
               ({clear = true, restart = false},
                fn () =>
                let val () = Prim.rewindDir d
                in
                   {return = ~1,
                    post = fn () => (),
                    handlers = [(Error.cleared, fn () => ())]}
                end)
            end

         fun closedir (DS r) =
            case !r of
               NONE => ()
             | SOME d => (SysCall.simple (fn () => Prim.closeDir d); r := NONE)
      end
         
      fun chdir s =
         SysCall.simple (fn () => Prim.chdir (NullString.nullTerm s))

      local
         val size: int ref = ref 1
         fun make () = Primitive.Array.array (!size)
         val buffer = ref (make ())
            
         fun extractToChar (a, c) =
            let
               val n = Array.length a
               (* find the null terminator *)
               fun loop i =
                  if i >= n
                     then raise Fail "String.extractFromC didn't find terminator"
                  else if c = Array.sub (a, i)
                          then i
                       else loop (i + 1)
            in
               ArraySlice.vector (ArraySlice.slice (a, 0, SOME (loop 0)))
            end
         
         fun extract a = extractToChar (a, #"\000")
      in
         fun getcwd () =
            if Primitive.Pointer.isNull (Prim.getcwd (!buffer, C_Size.fromInt (!size)))
               then (size := 2 * !size
                     ; buffer := make ()
                     ; getcwd ())
            else extract (!buffer)
      end

      val FD = Primitive.FileDesc.fromInt

      val stdin = FD 0
      val stdout = FD 1
      val stderr = FD 2

      structure S =
         struct
            open S Flags
            type mode = C_Mode.t
            val ifblk = IFBLK
            val ifchr = IFCHR
            val ifdir = IFDIR
            val ififo = IFIFO
            val iflnk = IFLNK
            val ifmt = IFMT
            val ifreg = IFREG
            val ifsock = IFSOCK
            val irgrp = IRGRP
            val iroth = IROTH
            val irusr = IRUSR
            val irwxg = IRWXG
            val irwxo = IRWXO
            val irwxu = IRWXU
            val isgid = ISGID
            val isuid = ISUID
            val isvtx = ISVTX
            val iwgrp = IWGRP
            val iwoth = IWOTH
            val iwusr = IWUSR
            val ixgrp = IXGRP
            val ixoth = IXOTH
            val ixusr = IXUSR
         end

      structure O =
         struct
            open O Flags
            val append = SysWord.fromInt APPEND
            val binary = SysWord.fromInt BINARY
            val creat = SysWord.fromInt CREAT
            val dsync = SysWord.fromInt DSYNC
            val excl = SysWord.fromInt EXCL
            val noctty = SysWord.fromInt NOCTTY
            val nonblock = SysWord.fromInt NONBLOCK
            val rdonly = SysWord.fromInt RDONLY
            val rdwr = SysWord.fromInt RDWR
            val rsync = SysWord.fromInt RSYNC
            val sync = SysWord.fromInt SYNC
            val text = SysWord.fromInt TEXT
            val trunc = SysWord.fromInt TRUNC
            val wronly = SysWord.fromInt WRONLY
         end

      datatype open_mode = O_RDONLY | O_WRONLY | O_RDWR

      fun wordToOpenMode w =
         if w = O.rdonly then O_RDONLY
         else if w = O.wronly then O_WRONLY
              else if w = O.rdwr then O_RDWR
                   else raise Fail "wordToOpenMode: unknown word"
                      
      val openModeToWord =
         fn O_RDONLY => O.rdonly
          | O_WRONLY => O.wronly
          | O_RDWR => O.rdwr

      fun createf (pathname, openMode, flags, mode) =
         let
            val pathname = NullString.nullTerm pathname
            val flags = Flags.flags [openModeToWord openMode,
                                     flags,
                                     O.creat]
            val fd =
               SysCall.simpleResult
               (fn () => Prim.open3 (pathname, SysWord.toInt flags, mode))
         in
            FD fd
         end

      fun openf (pathname, openMode, flags) =
         let 
            val pathname = NullString.nullTerm pathname
            val flags = Flags.flags [openModeToWord openMode, flags]
            val fd = 
               SysCall.simpleResult
               (fn () => Prim.open3 (pathname, SysWord.toInt flags, Flags.empty))
         in FD fd
         end
         
      fun creat (s, m) = createf (s, O_WRONLY, O.trunc, m)

      val umask = Prim.umask

 
      local
         fun wrap p arg = (SysCall.simple (fn () => p arg); ())
         fun wrapRestart p arg = (SysCall.simpleRestart (fn () => p arg); ())
         fun wrapOldNew p =
            wrap (fn {old,new} => p (NullString.nullTerm old,
                                     NullString.nullTerm new))
      in
         val link = wrapOldNew Prim.link
         val mkdir = wrap (fn (p, m) => Prim.mkdir (NullString.nullTerm p, m))
         val mkfifo = wrap (fn (p, m) => Prim.mkfifo (NullString.nullTerm p, m))
         val unlink = wrap (Prim.unlink o NullString.nullTerm)
         val rmdir = wrap (Prim.rmdir o NullString.nullTerm)
         val rename = wrapOldNew Prim.rename
         val symlink = wrapOldNew Prim.symlink
         val chmod = wrap (fn (p, m) => Prim.chmod (NullString.nullTerm p, m))
         val fchmod = wrap Prim.fchmod 
         val chown =
            wrap (fn (s, u, g) => Prim.chown (NullString.nullTerm s, u, g))
         val fchown = wrap Prim.fchown
         val ftruncate = wrapRestart Prim.ftruncate
      end           

      local
         val size: int = 1024
         val buf : char array = Array.array (size, #"\000")
      in
         fun readlink (path: string): string =
            let 
               val path = NullString.nullTerm path
            in
               SysCall.syscall
               (fn () =>
                let val len = Prim.readlink (path, buf, C_Size.fromInt size)
                in
                   (len, fn () =>
                    ArraySlice.vector (ArraySlice.slice (buf, 0, SOME len)))
                end)
            end
      end

      type dev = C_Dev.t
      val wordToDev = C_Dev.fromLargeWord o SysWord.toLargeWord
      val devToWord = SysWord.fromLargeWord o C_Dev.toLargeWord

      type ino = C_INo.t
      val wordToIno = C_INo.fromLargeWord o SysWord.toLargeWord
      val inoToWord = SysWord.fromLargeWord o C_INo.toLargeWord

      structure ST =
         struct
            datatype stat =
               T of {dev: dev,
                     ino: ino,
                     mode: S.mode,
                     nlink: int,
                     uid: uid,
                     gid: gid,
                     size: Position.int,
                     atime: Time.time,
                     mtime: Time.time,
                     ctime: Time.time}

            fun fromC (): stat =
               T {dev = Stat.getDev (),
                  ino = Stat.getINo (),
                  mode = Stat.getMode (),
                  nlink = C_NLink.toInt (Stat.getNLink ()),
                  uid = Stat.getUId (),
                  gid = Stat.getGId (),
                  size = Stat.getSize (),
                  atime = Time.fromSeconds (Stat.getATime ()),
                  mtime = Time.fromSeconds (Stat.getMTime ()),
                  ctime = Time.fromSeconds (Stat.getCTime ())}

            local
               fun make sel (T r) = sel r
            in
               val mode = make #mode
               val ino = make #ino
               val dev = make #dev
               val nlink = make #nlink
               val uid = make #uid
               val gid = make #gid
               val size = make #size
               val atime = make #atime
               val mtime = make #mtime
               val ctime = make #ctime
            end

            local
               fun make prim s = prim (mode s)
            in
               val isDir = make Prim.ST.isDir
               val isChr = make Prim.ST.isChr
               val isBlk = make Prim.ST.isBlk
               val isReg = make Prim.ST.isReg
               val isFIFO = make Prim.ST.isFIFO
               val isLink = make Prim.ST.isLink
               val isSock = make Prim.ST.isSock
            end
         end

      local
         fun make prim arg =
            SysCall.syscall (fn () => (prim arg, fn () => ST.fromC ()))
      in
         val stat = (make Prim.Stat.stat) o NullString.nullTerm
         val lstat = (make Prim.Stat.lstat) o NullString.nullTerm
         val fstat = make Prim.Stat.fstat
      end

      datatype access_mode = A_READ | A_WRITE | A_EXEC

      val conv_access_mode =
         fn A_READ => A.R_OK
          | A_WRITE => A.W_OK
          | A_EXEC => A.X_OK

      fun access (path: string, mode: access_mode list): bool =
         let 
            val mode = SysWord.toInt (Flags.flags (map SysWord.fromInt (A.F_OK :: (map conv_access_mode mode))))
            val path = NullString.nullTerm path
         in 
            SysCall.syscallErr
            ({clear = false, restart = false},
             fn () =>
             let val return = Prim.access (path, mode)
             in
                {return = return,
                 post = fn () => true,
                 handlers = [(Error.acces, fn () => false),
                             (Error.loop, fn () => false),
                             (Error.nametoolong, fn () => false),
                             (Error.noent, fn () => false),
                             (Error.notdir, fn () => false),
                             (Error.rofs, fn () => false)]}
             end)
         end

      local
         structure U = Prim.Utimbuf
      in
         fun utime (f: string, opt: {actime: Time.time,
                                     modtime: Time.time} option): unit =
            let
               val (a, m) =
                  case opt of
                     NONE => let val t = Time.now ()
                             in (t, t)
                             end
                   | SOME {actime = a, modtime = m} => (a, m)
               val a = Time.toSeconds a
               val m = Time.toSeconds m
               val f = NullString.nullTerm f
            in 
               SysCall.syscallRestart
               (fn () => 
                (U.setAcTime a
                 ; U.setModTime m
                 ; (U.utime f, fn () => 
                    ())))
            end
      end

      local
         local
            open Prim.PC
         in
            val properties =
               [
                (ALLOC_SIZE_MIN,"ALLOC_SIZE_MIN"),
                (ASYNC_IO,"ASYNC_IO"),
                (CHOWN_RESTRICTED,"CHOWN_RESTRICTED"),
                (FILESIZEBITS,"FILESIZEBITS"),
                (LINK_MAX,"LINK_MAX"),
                (MAX_CANON,"MAX_CANON"),
                (MAX_INPUT,"MAX_INPUT"),
                (NAME_MAX,"NAME_MAX"),
                (NO_TRUNC,"NO_TRUNC"),
                (PATH_MAX,"PATH_MAX"),
                (PIPE_BUF,"PIPE_BUF"),
                (PRIO_IO,"PRIO_IO"),
                (REC_INCR_XFER_SIZE,"REC_INCR_XFER_SIZE"),
                (REC_MAX_XFER_SIZE,"REC_MAX_XFER_SIZE"),
                (REC_MIN_XFER_SIZE,"REC_MIN_XFER_SIZE"),
                (REC_XFER_ALIGN,"REC_XFER_ALIGN"),
                (SYMLINK_MAX,"SYMLINK_MAX"),
                (SYNC_IO,"SYNC_IO"),
                (VDISABLE,"VDISABLE")
               ]
         end

         fun convertProperty s =
            case List.find (fn (_, s') => s = s') properties of
               NONE => Error.raiseSys Error.inval
             | SOME (n, _) => n

         fun make prim (f, s) =
            SysCall.syscallErr
            ({clear = true, restart = false},
             fn () =>
             let
                val return = prim (f, convertProperty s)
             in
                {return = return,
                 post = fn () => SOME (SysWord.fromInt return),
                 handlers = [(Error.cleared, fn () => NONE)]}
             end)
      in
         val pathconf =
            make (fn (path, s) => Prim.pathconf (NullString.nullTerm path, s))
         val fpathconf = make Prim.fpathconf
      end
   end
