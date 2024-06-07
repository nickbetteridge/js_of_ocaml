class type intersectionObserverEntry = object
  method target : Dom.node Js.t Js.readonly_prop

  method boundingClientRect : Dom_html.clientRect Js.t Js.readonly_prop

  method rootBounds : Dom_html.clientRect Js.t Js.opt Js.readonly_prop

  method intersectionRect : Dom_html.clientRect Js.t Js.readonly_prop

  method intersectionRatio : Js.number Js.t Js.readonly_prop

  method isIntersecting : bool Js.t Js.readonly_prop

  method time : Js.number Js.t Js.readonly_prop
end

class type intersectionObserverOptions = object
  method root : Dom.node Js.t Js.writeonly_prop

  method rootMargin : Js.js_string Js.t Js.writeonly_prop

  method threshold : Js.number Js.t Js.js_array Js.t Js.writeonly_prop
end

class type intersectionObserver = object
  method root : Dom.node Js.t Js.opt Js.readonly_prop

  method rootMargin : Js.js_string Js.t Js.readonly_prop

  method thresholds : Js.number Js.t Js.js_array Js.t Js.readonly_prop

  method observe : #Dom.node Js.t -> unit Js.meth

  method unobserve : #Dom.node Js.t -> unit Js.meth

  method disconnect : unit Js.meth

  method takeRecords : intersectionObserverEntry Js.t Js.js_array Js.meth
end

let empty_intersection_observer_options () : intersectionObserverOptions Js.t =
  Js.Unsafe.obj [||]

let intersectionObserver_unsafe = Js.Unsafe.global##._IntersectionObserver

let is_supported () = Js.Optdef.test intersectionObserver_unsafe

let intersectionObserver :
    (   (   intersectionObserverEntry Js.t Js.js_array Js.t
         -> intersectionObserver Js.t
         -> unit)
        Js.callback
     -> intersectionObserverOptions Js.t
     -> intersectionObserver Js.t)
    Js.constr =
  intersectionObserver_unsafe
