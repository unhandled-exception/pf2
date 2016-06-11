#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/web/templates2.p

@main[][locals]
  Templates tests...

  $template[^pfTemplate::create[
#     $.searchPath[./assets/templates/]
  ]]
  ^template.storage.appendSearchPath[./assets/templates/]
  $lTemp[^template.getTemplate[index.pt;
    $.base[./assets/templates]
  ]]
  $lTemp[^template.getTemplate[index.pt;$.force(true)]]

  -- $lTemp.text

  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }


