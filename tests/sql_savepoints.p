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
    ^db.transaction{
      ^db.transaction{
        ^db.savepoint{
          ^insert_data[$db]
        }
      }

      ^db.savepoint{
        ^insert_data[$db]
        ^db.savepoint[test_savepoint]
        ^insert_data[$db]
        ^db.rollback[test_savepoint]
      }

      ^try{
        ^db.savepoint[test_sp_code]{
          ^insert_data[$db]
          ^throw[stop]
        }
      }{
         $exception.handled($exception.type eq "stop")
      }

     $t[^db.table{select * from users}]
     ^json:string[$t]

    }

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
  ^for[i](1;5){
    ^aDB.void{insert into users (name, uuid) values ("User $i", "^math:uuid[]")}
  }