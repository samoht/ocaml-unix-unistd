(*
 * Copyright (c) 2014 David Sheets <sheets@alum.mit.edu>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

module Access = struct
  include Unix_unistd_common.Access

  let view ~host = Ctypes.(view ~read:(of_code ~host) ~write:(to_code ~host) int)
end

module Sysconf = struct
  include Unix_unistd_common.Sysconf
end

open Ctypes
open Foreign
open Unsigned

let local ?check_errno addr typ =
  coerce (ptr void) (funptr ?check_errno typ) (ptr_of_raw_address addr)

let to_off_t = coerce int64_t PosixTypes.off_t
let to_uid_t = let c = coerce uint32_t PosixTypes.uid_t in
               fun i -> c (UInt32.of_int i)
let to_gid_t = let c = coerce uint32_t PosixTypes.gid_t in
               fun i -> c (UInt32.of_int i)

(* Filesystem functions *)

let write =
  let c = foreign ~check_errno:true "write"
    PosixTypes.(int @-> ptr void @-> size_t @-> returning size_t) in
  fun fd buf count ->
    try
      Size_t.to_int (c (Fd_send_recv.int_of_fd fd) buf (Size_t.of_int count))
    with Unix.Unix_error(e,_,_) -> raise (Unix.Unix_error (e,"write",""))

external unix_unistd_read_ptr : unit -> int64 = "unix_unistd_read_ptr"

let read =
  let c = local ~check_errno:true (unix_unistd_read_ptr ())
    PosixTypes.(int @-> ptr void @-> size_t @-> returning size_t)
  in
  fun fd buf count ->
    try
      Size_t.to_int (c (Fd_send_recv.int_of_fd fd) buf (Size_t.of_int count))
    with Unix.Unix_error(e,_,_) -> raise (Unix.Unix_error (e,"read",""))

external unix_unistd_close_ptr : unit -> int64 = "unix_unistd_close_ptr"

let close =
  let c = local ~check_errno:true (unix_unistd_close_ptr ())
    PosixTypes.(int @-> returning int)
  in
  fun fd ->
    try ignore (c (Fd_send_recv.int_of_fd fd))
    with Unix.Unix_error(e,_,_) -> raise (Unix.Unix_error (e,"close",""))

external unix_unistd_access_ptr : unit -> int64 = "unix_unistd_access_ptr"

let access =
  let c = local ~check_errno:true (unix_unistd_access_ptr ())
    PosixTypes.(string @-> Access.(view ~host) @-> returning int)
  in
  fun pathname mode ->
    try ignore (c pathname mode)
    with Unix.Unix_error(e,_,_) -> raise (Unix.Unix_error (e,"access",pathname))

external unix_unistd_readlink_ptr : unit -> int64 = "unix_unistd_readlink_ptr"

let readlink =
  let c = local ~check_errno:true (unix_unistd_readlink_ptr ())
    PosixTypes.(string @-> ptr void @-> size_t @-> returning size_t)
  in
  fun path ->
    try
      let sz = ref (Sysconf.(pagesize ~host)) in
      let buf = ref (allocate_n uint8_t ~count:!sz) in
      let len = ref Size_t.(to_int (c path (to_voidp !buf) (of_int !sz))) in
      while !len = !sz do
        sz  := !sz * 2;
        buf := allocate_n uint8_t ~count:!sz;
        len := Size_t.(to_int (c path (to_voidp !buf) (of_int !sz)))
      done;
      CArray.(set (from_ptr !buf (!len+1)) !len (UInt8.of_int 0));
      coerce (ptr uint8_t) string !buf
    with Unix.Unix_error(e,_,_) -> raise (Unix.Unix_error (e,"readlink",path))

external unix_unistd_symlink_ptr : unit -> int64 = "unix_unistd_symlink_ptr"

let symlink =
  let c = local ~check_errno:true (unix_unistd_symlink_ptr ())
    PosixTypes.(string @-> string @-> returning int)
  in
  fun source dest ->
    try ignore (c source dest)
    with Unix.Unix_error(e,_,_) -> raise (Unix.Unix_error (e,"symlink",dest))

external unix_unistd_truncate_ptr : unit -> int64 = "unix_unistd_truncate_ptr"

let truncate =
  let c = local ~check_errno:true (unix_unistd_truncate_ptr ())
    PosixTypes.(string @-> off_t @-> returning int)
  in
  fun path length ->
    try ignore (c path (to_off_t length))
    with Unix.Unix_error(e,_,_) -> raise (Unix.Unix_error (e,"truncate",path))

external unix_unistd_ftruncate_ptr : unit -> int64 = "unix_unistd_ftruncate_ptr"

let ftruncate =
  let c = local ~check_errno:true (unix_unistd_ftruncate_ptr ())
    PosixTypes.(int @-> off_t @-> returning int)
  in
  fun fd length ->
    try ignore (c (Fd_send_recv.int_of_fd fd) (to_off_t length))
    with Unix.Unix_error(e,_,_) -> raise (Unix.Unix_error (e,"ftruncate",""))

external unix_unistd_chown_ptr : unit -> int64 = "unix_unistd_chown_ptr"

let chown =
  let c = local ~check_errno:true (unix_unistd_chown_ptr ())
    PosixTypes.(string @-> uid_t @-> gid_t @-> returning int)
  in
  fun path owner group ->
    try ignore (c path (to_uid_t owner) (to_gid_t group))
    with Unix.Unix_error(e,_,_) -> raise (Unix.Unix_error (e,"chown",path))

external unix_unistd_fchown_ptr : unit -> int64 = "unix_unistd_fchown_ptr"

let fchown =
  let c = local ~check_errno:true (unix_unistd_fchown_ptr ())
    PosixTypes.(int @-> uid_t @-> gid_t @-> returning int)
  in
  fun fd owner group ->
    try ignore (c (Fd_send_recv.int_of_fd fd) (to_uid_t owner) (to_gid_t group))
    with Unix.Unix_error(e,_,_) -> raise (Unix.Unix_error (e,"fchown",""))

(* Process functions *)

external unix_unistd_seteuid_ptr : unit -> int64 = "unix_unistd_seteuid_ptr"

let seteuid =
  let c = local ~check_errno:true (unix_unistd_seteuid_ptr ())
    PosixTypes.(uid_t @-> returning int)
  in
  fun uid ->
    try ignore (c (to_uid_t uid))
    with Unix.Unix_error(e,_,_) -> raise (Unix.Unix_error (e,"seteuid",""))
