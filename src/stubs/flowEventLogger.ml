(**
 * Copyright (c) 2014, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "flow" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

type logging_context = {
  argv: string;
  command: string option;
  from: string option;
  root: string option;
  start_time: float;
}

let get_context _ = {
  argv = "";
  command = None;
  from = None;
  root = None;
  start_time = 0.0;
}
let set_command _ = ()
let set_from _ = ()
let set_root _ = ()

module Timing = struct
  type t = unit

  let create _ = ()
  let start_timer ~timer:_ _ = ()
  let stop_timer ~timer:_ _ = ()
  let get_finished_timer ~timer:_ _ = None
end

let status_response _ = ()
let init_server _ = ()
let init_done ~timing:_ = ()
let init_flow_command ~version:_ = ()
let killed _ = ()
let lock_lost _ = ()
let lock_stolen _ = ()
let out_of_date _ = ()
let autocomplete_member_result
    ~client_context:_
    ~result_str:_
    ~json_data:_
    ~timing:_ = ()
let exit _ _ = ()
let recheck
    ~modified_count:_
    ~deleted_count:_
    ~dependent_file_count:_
    ~timing:_ = ()
