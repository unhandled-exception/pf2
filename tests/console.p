#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/console/console.p

@main[][locals]
  Test!
  ^pfConsole:writeln[Output via console. Line 1]
  ^pfConsole:writeln[Output via console. Line 2]
$pfConsole:stdout
  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }


