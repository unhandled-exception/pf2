#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/web/templates.p

@main[][locals]
  Templates tests...

  $template[^pfTemplate::create[
    $.searchPath[./assets/templates/]
  ]]
  $lTemp[^template.getTemplate[main.pt]]

  -- $lTemp.__FILE__ -- $lTemp.CLASS_NAME

  main: ^lTemp.__render__[]

