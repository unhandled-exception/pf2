#!../../../cgi-bin/parser3.cgi

@conf[]
  $CLASS_PATH[/../../]

@USE
pf2/lib/api/archives/zip.p

@main[][locals]
  Test zip unarchiver.

  $zip[^pfZipArchiver::create[]]
  ^json:string[^zip.list[assets/api/zip/pf1_zip.zip]]

  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }


