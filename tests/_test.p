#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/common.p

@main[][locals]
  Test!

  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }


