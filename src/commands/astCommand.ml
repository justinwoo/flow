(**
 * Copyright (c) 2015, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "flow" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

(***********************************************************************)
(* flow ast command *)
(***********************************************************************)

let spec = {
  CommandSpec.
  name = "ast";
  doc = "Print the AST";
  usage = Printf.sprintf
    "Usage: %s ast [OPTION]... [FILE]\n\n\
      e.g. %s ast foo.js\n\
      or   %s ast < foo.js\n"
      CommandUtils.exe_name
      CommandUtils.exe_name
      CommandUtils.exe_name;
  args = CommandSpec.ArgSpec.(
    empty
    |> flag "--tokens" no_arg
        ~doc:"Include a list of syntax tokens in the output"
    |> flag "--pretty" no_arg
        ~doc:"Pretty-print JSON output"
    |> CommandUtils.from_flag
    |> anon "file" (optional string) ~doc:"[FILE]"
  )
}

module Hh_jsonTranslator : (
  Estree_translator.Translator with type t = Hh_json.json
) = struct
  type t = Hh_json.json

  open Hh_json

  let string x = JSON_String x
  let bool x = JSON_Bool x
  let obj props = JSON_Object (Array.to_list props)
  let array arr = JSON_Array (Array.to_list arr)
  let number x = JSON_Number (Utils.string_of_float_trunc x)
  let null = JSON_Null
  let regexp _loc _pattern _flags = JSON_Null
end

let get_file = function
  | Some filename -> ServerProt.FileName (CommandUtils.expand_path filename)
  | None -> ServerProt.FileContent (None, Sys_utils.read_stdin_to_string ())

module Translate = Estree_translator.Translate (Hh_jsonTranslator)

let token_to_json token_result = Loc.(Hh_json.(Parser_env.(
  let {
    token_loc=loc;
    token;
    token_context;
    token_value;
  } = token_result in

  JSON_Object [
    ("type", JSON_String (Lexer_flow.token_to_string token));
    ("context", JSON_String (
      match token_context with
      | NORMAL_LEX -> "normal"
      | TYPE_LEX -> "type"
      | JSX_TAG -> "jsxTag"
      | JSX_CHILD -> "jsxChild"
    ));
    ("loc", JSON_Object [
      ("start", JSON_Object [
        ("line", int_ loc.start.line);
        ("column", int_ loc.start.column);
      ]);
      ("end", JSON_Object [
        ("line", int_ loc._end.line);
        ("column", int_ loc._end.column);
      ]);
    ]);
    ("range", JSON_Array [
      int_ loc.start.offset;
      int_ loc._end.offset;
    ]);
    ("value", JSON_String token_value);
  ]
)))

let main include_tokens pretty from filename () =
  FlowEventLogger.set_from from;
  let file = get_file filename in
  let content = ServerProt.file_input_get_content file in

  (**
   * Record token stream into a list when the --tokens flag is passed.
   * Note that tokens stream in in order, so the list is constructed in reverse
   * order.
   *)
  let tokens = ref [] in
  let token_sink =
    if not include_tokens then None else (Some(fun token_data ->
    tokens := (token_to_json token_data)::!tokens
  )) in

  let results =
    try
      (* Turn on all the options for now. TODO: make these CLI flags? *)
      let parse_options = Some Parser_env.({
        esproposal_class_instance_fields = true;
        esproposal_class_static_fields = true;
        esproposal_decorators = true;
        types = true;
      }) in

      let (ocaml_ast, errors) =
        Parser_flow.program ~fail:false ~parse_options ~token_sink content
      in
      match Translate.program ocaml_ast with
      | Hh_json.JSON_Object params ->
          let errors_prop = ("errors", Translate.errors errors) in
          let tokens_prop = ("tokens", Hh_json.JSON_Array (List.rev !tokens)) in
          Hh_json.JSON_Object (errors_prop::tokens_prop::params)
      | _ -> assert false
    with Parse_error.Error l ->
      Hh_json.JSON_Object ["errors", Translate.errors l]
  in

  let json = if pretty
    then Hh_json.json_to_multiline results
    else Hh_json.json_to_string results
  in
  output_string stdout (json^"\n");
  flush stdout

let command = CommandSpec.command spec main
