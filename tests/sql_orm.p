#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/sql/models/sql_table.p

@main[][locals]
SQL connection test!

  $dbFile[assets/sql/sql_table.sqlite]
  ^try{
    $db[^pfSQLConnection::create[sqlite://${dbFile};
      $.enableQueriesLog(true)
      $.enableMemoryCache(true)
    ]]
    Type: $db.serverType
    ^create_tables[$db]

    $users[^usersModel::create[$.sql[$db]]]
    ^insert_data[$users]

    ^try{
      ^db.transaction{
        ^insert_data[$users]
        ^throw[stop]
      }
    }{
       $exception.handled($exception.type eq "stop")
    }

    ^users.modify[2;$.name[User 2 (modified)] $.uuid[]]

    $t[^users.all[]]
    ^json:string[$t]

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
  ^aDB.void{create table users(id integer primary key autoincrement, name varchar, uuid varchar, created_at datetime, updated_at datetime)}

@drop_tables[aDB]
  $result[]
  ^aDB.void{drop table users}

@insert_data[aModel][locals]
#  $result[]
  ^for[i](1;5){
    ^aModel.new[$.name[User $i] $.uuid[^math:uuid[]]]
  }


@CLASS
usersModel

@BASE
pfSQLTable

@create[aOptions]
  ^BASE:create[users;$aOptions]

  ^addFields[
    $.id[$.processor[uint] $.primary(true)]
    $.name[]
    $.uuid[]
    $.createdAt[$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true)]
    $.createdAt[$.dbField[created_at] $.processor[auto_now]]
  ]

  $_defaultOrderBy[$.name[]]
