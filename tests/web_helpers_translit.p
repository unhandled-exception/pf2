#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/web/helpers/translit.p

@main[][locals]
  URL translit test!

  $tr[^pfURLTranslit::create[]]
  toURL: ^tr.toURL[PF2 library — веб-фреймворк для языка Парсер 3.]
  bidi: $bds[^tr.bidi[PF2 library — веб-фреймворк для языка Парсер 3.;encode]] $bds
         ^tr.bidi[$bds;decode]

  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }


