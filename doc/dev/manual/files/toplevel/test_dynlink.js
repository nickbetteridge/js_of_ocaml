// Generated by js_of_ocaml
//# buildInfo:effects=cps, kind=cmo, use-js-string=true, version=6.0.1+18cc926

//# unitInfo: Provides: Test_dynlink
//# unitInfo: Requires: Stdlib
(function
  (globalThis){
   "use strict";
   var runtime = globalThis.jsoo_runtime;
   function caml_trampoline_cps_call2(f, a0, a1){
    return runtime.caml_stack_check_depth()
            ? (f.l
                >= 0
                ? f.l
                : f.l = f.length)
              === 2
              ? f(a0, a1)
              : runtime.caml_call_gen(f, [a0, a1])
            : runtime.caml_trampoline_return(f, [a0, a1], 0);
   }
   runtime.jsoo_create_file
    ("/static/cmis/test_dynlink.cmi",
     "Caml1999I035\x84\x95\xa6\xbd\nar\x1aa[(\xb5/\xfd\0X\xc5\x02\0\xb4\x04\xa0,Test_dynlink\xa0\xb0\xa0!f\x01\x01\x11\xd0\xc0\xc1@\xc0\xb3\x90\xa3$unitF@\x90@\x02\x05\xf5\xe1\0@\0\xfc\xfd\xfe@\xb0\xc0/t.mlCdh\xc0\x04\x17Cdi@@\xb1\x04\x01@A@@\x03\0R0\x15\x14q\x8f\xf4,\x03\x84\x95\xa6\xbe\0\0\0j\0\0\0\x0f\0\0\0:\0\0\0.\xa0\xa0,Test_dynlink\x900\x06\xf4=9PU\xea\x81\xa1\xb8\xf5y&B1\xf5\xa0\xa0&Stdlib\x900j\x82\xe85T\xady{7\xcc\xbd\xfbh!\xc2\xb7\xa0\xa08CamlinternalFormatBasics\x900\xaaU\v\xda\xb5!\xd6\x0ev\x9a\x9a\xd4:g~e@\x84\x95\xa6\xbe\0\0\0\x04\0\0\0\x02\0\0\0\x05\0\0\0\x05\xa0\x90@@");
   var
    global_data = runtime.caml_get_global_data(),
    Stdlib = global_data.Stdlib;
   runtime.caml_callback(Stdlib[46], ["Dynlink OK"]);
   var
    cst_Test_dynlink_f_Ok = "Test_dynlink.f Ok",
    Test_dynlink =
      [0,
       function(_b_, cont){
        return caml_trampoline_cps_call2
                (Stdlib[46], cst_Test_dynlink_f_Ok, cont);
       }];
   runtime.caml_register_global(3, Test_dynlink, "Test_dynlink");
   return;
  }
  (globalThis));
