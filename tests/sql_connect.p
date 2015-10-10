#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/sql/connection.p

@main[][locals]
  SQL connection test!

  $dbFile[assets/sql/test.sqlite]
  ^try{
#    $db[^pfSQLConnection::create[sqlite://${dbFile}]]

  }{}{
    ^if(-f $dbFile){
      ^file:delete[$dbFile]
    }
  }
  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }


