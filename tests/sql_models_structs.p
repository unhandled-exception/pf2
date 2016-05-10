#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/sql/models/structs.p

@main[][locals]
SQL Table  test!

  $dbFile[assets/sql/sql_models_structs.sqlite]
  ^try{
    $db[^pfSQLConnection::create[sqlite://${dbFile};
      $.enableQueriesLog(true)
      $.enableMemoryCache(true)
    ]]
    Type: $db.serverType
    ^create_tables[$db]

    $core[^Core::create[$.sql[$db]]]
    ^print_fields[$core]

    Core test1: $core.test1.CLASS_NAME
    ^core.test1.print[]
    ^print_fields[$core.test1]

    Users test: $core.users.CLASS_NAME
    ^insert_data[$core.users]
    $d[^core.users.all[]]

#    ^print_fields[$core.users]

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
  $result[]
  ^for[i](1;5){
    ^aModel.new[$.name[User $i] $.uuid[^math:uuid[]]]
  }

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }


@CLASS
Core

@OPTIONS
locals

@BASE
pfModelModule

@create[aOptions]
  ^BASE:create[$aOptions]
  $coreVar[core var value]

  ^self.assignModule[test1;ModelModule;$.var1[value1]]
  ^self.assignModule[users;usersModel]


@CLASS
ModelModule

@OPTIONS
locals

@BASE
pfModelModule

@create[aOptions]
  ^BASE:create[$aOptions]
  $_var1[$aOptions]

@print[]
  $result[This is a $self.CLASS_NAME class instance. Core var: $core.coreVar]


@CLASS
usersModel

@OPTIONS
locals

@BASE
pfModelTable

@create[aOptions]
  ^BASE:create[^hash::create[$aOptions]
    $.tableName[users]
    $.tableAlias[u]
  ]

  ^self.addFields[
    $.id[$.processor[uint] $.primary(true)]
    $.name[]
    $.uuid[]
    $.createdAt[$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true)]
    $.createdAt[$.dbField[created_at] $.processor[auto_now]]
  ]

  $_defaultOrderBy[$.name[]]
