// Generated by js_of_ocaml
//# buildInfo:effects=cps, kind=cmo, use-js-string=true, version=5.9.1+09e9842

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
     "Caml1999I034\x84\x95\xa6\xbd\n`q\x1a`Z(\xb5/\xfd\0X\xbd\x02\0\xa4\x04\xa0,Test_dynlink\xa0\xb0\xa0!f\x01\x01\x11\xd0\xc0\xc1@\xc0\xb3\x90\xa3$unitF@\x90@\x02\x05\xf5\xe1\0@\0\xfc\xfd\xfe@\xb0\xc0/t.mlCdh\xc0\x04\x17Cdi@@\xa1\x04\x01@@@\x03\0R0\x15\x14q\x8f\xf4,\x03\x84\x95\xa6\xbe\0\0\0j\0\0\0\x0f\0\0\0:\0\0\0.\xa0\xa0,Test_dynlink\x900\xd0Q\x11F\xf6\xde\xc5\xfbW\xd4\xd1\xd2;t\x10\x1d\xa0\xa0&Stdlib\x900\xe8\xd9\xafE\x85G\xc4P\x80\xa7\x1b\x9an\xae\xd6X\xa0\xa08CamlinternalFormatBasics\x900.\xf2\xd9\x1c\xed\x81\xf6\xc7/\x85+\xab\x8a\xb4\x06\xe0@\x84\x95\xa6\xbe\0\0\0\x04\0\0\0\x02\0\0\0\x05\0\0\0\x05\xa0\x90@@");
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