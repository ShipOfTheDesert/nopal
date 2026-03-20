type 'a t = ('a -> unit) -> unit

let return x resolve = resolve x
let from_callback f = f
let map f task resolve = task (fun x -> resolve (f x))
let bind f task resolve = task (fun x -> f x resolve)
let run task resolve = task resolve

module Syntax = struct
  let ( let* ) task f = bind f task
  let ( let+ ) task f = map f task
end
