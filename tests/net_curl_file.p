#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/net/curl_file.p

@main[][locals]
  Тест для net/curl_file.p@pfCurlFile:

  $lURL[https://www.yandex.ru]
  $f[^pfCurlFile::load[text;$lURL]]
  $lURL is loaded. Status — ${f.status}. Body is starting from:
  ^f.text.left(100)


  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }


