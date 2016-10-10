#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/web/templates.p

@main[][locals]
  Templates tests...

  $template[^pfTemplate::create[
    $.searchPath[^table::create{path
./assets/templates/nop
./assets/templates/nop2
./assets/templates
}]
  ]]
  $lTemp[^template.getTemplate[index.pt]]

  -- $lTemp.__FILE__ -- $lTemp.CLASS_NAME
  import: ^lTemp.print_title[Test title]
  footer: ^lTemp.footer[Footer text]

  main: ^lTemp.__main__[]
  compact: ^lTemp.compact[] ok.

  render: ^template.render[index.pt]
  render call: ^template.render[index.pt@json]

  templates cache:
  ^template.templates.foreach[k;v]{
    "$k" -> $v.object.CLASS_NAME, $v.hits, $v.object.__FILE__
  }

  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }


