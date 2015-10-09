#!../../../cgi-bin/parser3.cgi

@USE
../lib/common.p

@main[][locals]
  Test!

  ^curl:session{
    ^curl:options[
      $.verbose(true)
    ]

    $lURL[http://google.com]
    $lURL is ^if(^pfValidate:isValidURL[$lURL]){a valid}{an invalid} url.
    $lURL is ^if(^pfValidate:isExistingURL[$lURL]){an exist}{a not exist} url.

    $lURL[https://google.com]
    $lURL is ^if(^pfValidate:isValidURL[$lURL]){a valid}{an invalid} url.
    $lURL is ^if(^pfValidate:isExistingURL[$lURL]){an exists}{a non exist} url.

    $lURL is ^if(^pfValidate:isValidURL[$lURL;$.onlyHTTP(true)]){a valid}{an invalid} http url.
  }
  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }


