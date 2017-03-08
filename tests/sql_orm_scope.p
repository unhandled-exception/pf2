#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/sql/models/sql_table.p

@main[][locals]
SQL Table  test!

  $dbFile[assets/sql/sql_table.sqlite]
  ^try{
    $db[^pfSQLConnection::create[sqlite://${dbFile};
      $.enableQueriesLog(true)
      $.enableMemoryCache(true)
    ]]
    Type: $db.serverType
    ^create_tables[$db]

    $users[^usersModel::create[users;$.sql[$db]]]
    ^insert_data[$users]

    $t[^users.all[$.[id >][3]]]
    $t[^users.visible.all[]]
    $t[^users.orderByName.all[]]
    $t[^users.vasya10.all[]]
    $t[^users.vasya10.visible.orderByName.all[]]
    $t[^users.vasya10.visible.orderByName.all[$.isActive[any] $.limit(5) $.orderBy[uuid]]]

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
  ^aDB.void{create table users(id integer primary key autoincrement, name varchar, uuid varchar, is_active int, created_at datetime, updated_at datetime)}

@drop_tables[aDB]
  $result[]
  ^aDB.void{drop table users}

@insert_data[aModel][locals]
 $result[]
  ^for[i](1;5){
    ^aModel.new[$.name[User $i] $.uuid[^math:uuid[]]]
  }


@CLASS
usersModel

@OPTIONS
locals

@BASE
pfSQLTable

@create[aTableName;aOptions]
  ^BASE:create[$aTableName;$aOptions]

  ^self.addFields[
    $.id[$.processor[uint] $.primary(true)]
    $.name[]
    $.uuid[]
    $.isActive[$.dbField[is_active] $.processor[bool] $.default(true)]
    $.createdAt[$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true)]
    $.createdAt[$.dbField[created_at] $.processor[auto_now]]
  ]

  $self._defaultScope[
    $.orderBy[$.id[asc]]
  ]

  ^self.addScope[orderByName;$.orderBy[$.name[asc]]]
  ^self.addScope[visible;$.isActive(true)]
  ^self.addScope[vasya10;$.[name like][%vasya%] $.limit(10)]

@_allWhere[aOptions]
  $aOptions[^hash::create[$aOptions]]
  ^if($aOptions.isActive is string && $aOptions.isActive eq "any"){
    ^aOptions.delete[isActive]
  }
  $result[^BASE:_allWhere[$aOptions]]
