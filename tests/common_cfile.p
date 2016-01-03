#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/common.p

@main[][locals]
  Тест для common.p@pfCFile:

  $lURL[https://www.yandex.ru]
  $f[^pfCFile::load[text;$lURL]]
  $lURL is loaded. Status — ${f.status}. Body is starting from:
  ^f.text.left(100)

  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }


