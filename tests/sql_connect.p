#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/sql/connection.p

@main[][locals]
SQL connection test!

  $dbFile[assets/sql/test.sqlite]
  ^try{
    $db[^pfSQLConnection::create[sqlite://${dbFile};
      $.enableQueriesLog(true)
      $.enableMemoryCache(true)
    ]]
    Type: $db.serverType

    ^create_tables[$db]
    ^insert_data[$db]

    ^try{
      ^db.transaction{
        ^insert_data[$db]
        ^throw[stop]
      }
    }{
       $exception.handled($exception.type eq "stop")
    }

    $t[^db.table{select * from users}]
    $t[^db.table{select * from users}[][$.cacheKey[sel from u]]]
    $t[^db.table{select * from users}[][$.force(true)]]
    $t[^db.table{select * from users}]
#    ^json:string[$t]

    $h[^db.hash{select * from users order by id desc}]
#    ^json:string[$h]

    $i[^db.int{select count(*) from users}]
#    ^json:string[$i]

    ^drop_tables[$db]

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
  ^aDB.void{create table users(id integer primary key autoincrement, name varchar, uuid varchar)}

@drop_tables[aDB]
  $result[]
  ^aDB.void{drop table users}

@insert_data[aDB][locals]
  $result[]
  ^for[i](1;20){
    ^aDB.void{insert into users (name, uuid) values ("User $i", "^math:uuid[]")}
  }