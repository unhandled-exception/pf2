#!../../../cgi-bin/parser3.cgi

@USE
../lib/net/curl_file.p

@main[][locals]
  Test!

  $lURL[https://google.com]
  $f[^pfCurlFile::load[text;$lURL]]
  $lURL is loaded. Status — ${f.status}. Body is starting from:
  ^f.body.left(100)


  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }


