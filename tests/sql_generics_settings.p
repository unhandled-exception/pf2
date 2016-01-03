#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/sql/models/generics/settings/sql_settings.p

@main[][locals]
SQL connection test!

  $dbFile[assets/sql/sql_generics_settings.sqlite]
  ^try{
    $db[^pfSQLConnection::create[sqlite://${dbFile};
      $.enableQueriesLog(true)
      $.enableMemoryCache(true)
    ]]
    Type: $db.serverType
    ^create_tables[$db]

    $st[^pfSQLSettings::create[$.sql[$db]]]
    ^st.set[name_1;value 1]
    ^st.set[name_2;value 2]
    ^st.set[name_3;value 3]
    ^st.set[name_1;value 1 (new)]

    ^st.foreach[k;v]{$k -> $v}[^#0A]

  }{}{
    ^if(-f $dbFile){
      ^file:delete[$dbFile]
    }
Queries:
^db.stat.queries.foreach[k;v]{${k}: $v.query [$v.type]^#0A}
  }

Memory cache: ^db.memoryCache._count[]


Finish tests.^#0A

@create_tables[aDB]
  $result[]
  ^aDB.void{
    CREATE TABLE `settings` (
      `key` varchar(255) NOT NULL,
      `value` text,
      `description` text,
      PRIMARY KEY (`key`)
    )
  }
