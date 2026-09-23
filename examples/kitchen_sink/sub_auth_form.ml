open Nopal_element
open Nopal_style

type model = {
  email : string;
  password : string;
  code : string;
  code_confirms : int;
  submits : int;
  novalidate : bool;
}

type msg =
  | Email_changed of string
  | Password_changed of string
  | Code_changed of string
  | Code_confirmed
  | Submitted
  | Novalidate_toggled of bool

let init () =
  ( {
      email = "";
      password = "";
      code = "";
      code_confirms = 0;
      submits = 0;
      novalidate = false;
    },
    Nopal_mvu.Cmd.none )

let update model msg =
  match msg with
  | Email_changed email -> ({ model with email }, Nopal_mvu.Cmd.none)
  | Password_changed password -> ({ model with password }, Nopal_mvu.Cmd.none)
  | Code_changed code -> ({ model with code }, Nopal_mvu.Cmd.none)
  | Code_confirmed ->
      ( { model with code_confirms = model.code_confirms + 1 },
        Nopal_mvu.Cmd.none )
  | Submitted -> ({ model with submits = model.submits + 1 }, Nopal_mvu.Cmd.none)
  | Novalidate_toggled novalidate ->
      ({ model with novalidate }, Nopal_mvu.Cmd.none)

(* The one-time code field answers Enter itself and declines every other key.
   Answering Enter is what consumes it, so it never goes on to submit the form;
   declining the rest is what leaves typing into the field alone. *)
let code_keydown key =
  match key with
  | "Enter" -> Some Code_confirmed
  | _ -> None

(* Layout fields are all options, so starting from the default layout inherits
   no opinion about anything but the gap named here. *)
let column_style gap =
  Style.default |> Style.with_layout (fun l -> { l with gap = Some gap })

let row_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = Some 8.0; cross_align = Some Center })

let counter ~testid ~label count =
  Element.box
    ~attrs:[ ("data-testid", testid) ]
    [ Element.text (Printf.sprintf "%s %d times" label count) ]

let view _vp model =
  Element.column ~style:(column_style 12.0)
    [
      Element.text
        "A demo with no authentication: nothing is sent or checked, and the \
         password lives in the model like any other input's value. It shows \
         the shape of a sign-in form, not a way to handle credentials.";
      Element.row ~style:row_style
        [
          Element.checkbox
            ~attrs:
              [
                ("data-testid", "auth-novalidate");
                ("aria-label", "Skip the form's validation");
              ]
            ~on_toggle:(fun skip -> Novalidate_toggled skip)
            model.novalidate;
          Element.text
            "Skip the form's validation, so empty required fields no longer \
             block a submission";
        ];
      (* The accessible name travels as an attribute pair: a form is exposed
         as a landmark only once it has one, and no typed field carries it. *)
      Element.form ~style:(column_style 8.0)
        ~attrs:[ ("data-testid", "auth-form"); ("aria-label", "Demo sign-in") ]
        ~on_submit:Submitted ~novalidate:model.novalidate
        [
          Element.text "Email";
          Element.input
            ~attrs:[ ("data-testid", "auth-email"); ("aria-label", "Email") ]
            ~on_change:(fun s -> Email_changed s)
            ~required:true ~autocomplete:"email" ~input_type:Element.Email
            model.email;
          Element.text "Password";
          Element.input
            ~attrs:
              [ ("data-testid", "auth-password"); ("aria-label", "Password") ]
            ~on_change:(fun s -> Password_changed s)
            ~required:true ~autocomplete:"current-password"
            ~input_type:Element.Password model.password;
          Element.text
            "One-time code (Enter here confirms the code and does not submit \
             the form)";
          Element.input
            ~attrs:
              [ ("data-testid", "auth-code"); ("aria-label", "One-time code") ]
            ~on_change:(fun s -> Code_changed s)
            ~on_keydown:code_keydown ~autocomplete:"one-time-code"
            ~input_type:Element.Plain model.code;
          (* No message of its own: the press submits the form, and the form
             carries the message, so a handler here would dispatch twice. *)
          Element.button
            ~attrs:[ ("data-testid", "auth-submit"); ("type", "submit") ]
            (Element.text "Sign in");
        ];
      counter ~testid:"auth-submit-count" ~label:"Submitted" model.submits;
      counter ~testid:"auth-code-count" ~label:"Code confirmed"
        model.code_confirms;
    ]

let serialize_model model =
  Printf.sprintf
    "auth_email=%S; auth_password_length=%d; auth_code_confirms=%d; \
     auth_submits=%d; auth_novalidate=%b;"
    model.email
    (String.length model.password)
    model.code_confirms model.submits model.novalidate

let serialize_msg msg =
  match msg with
  | Email_changed _ -> "AuthForm:Email_changed;"
  | Password_changed _ -> "AuthForm:Password_changed;"
  | Code_changed _ -> "AuthForm:Code_changed;"
  | Code_confirmed -> "AuthForm:Code_confirmed;"
  | Submitted -> "AuthForm:Submitted;"
  | Novalidate_toggled _ -> "AuthForm:Novalidate_toggled;"
