@USE
pf2/lib/sql/models/sql_table.p
sql/testutils.p


@CLASS
ORMPFSQLTableTests

@BASE
BaseTestSQLConnection

@setUp[]
  ^BASE:setUp[]
  $self.sut[^_TestUserModel::create[
    $.sql[$self.connection]
  ]]

  $self.testTime1[^date::create[2022-07-03 14:52:18]]
  $self.testTime2[^date::create($self.testTime1 + 1.3)]

@_createTestUsers[aCount]
  ^for[i](1;$aCount){
    ^self.sut.new[
      $.login[user_^eval($aCount-$i)]
      $.name[name]
      $.job[job $i]
      $.passwordHash[password hash $i]
      $.IsAdmin($i == 1)
      $.createdAt[$self.testTime1]
      $.updatedAt[$self.testTime2]
    ]
  }

@testAll_AsHash[]
  ^self._createTestUsers(5)
  $lRes[^self.sut.all[]]

  ^self.assertNumEq($lRes;5)
  ^self.assertHashEquals[$lRes.1;
        $.userID[1]
        $.login[user_4]
        $.name[name]
        $.job[job 1]
        $.passwordHash[password hash 1]
        $.isAdmin[0]
        $.isActive[1]
        $.createdAt[2022-07-03 14:52:18]
        $.updatedAt[2022-07-04 22:04:18]
  ]

@testAll_selectGroups[]
  ^self._createTestUsers(5)

  $lRes[^self.sut.all[$.selectFieldsGroups[base] $.asTable(true)]]
  $lColumns[^lRes.columns[]]
  ^self.assertHashEquals[
    ^lColumns.hash[column]{}
  ][
    $.userID[]
    $.login[]
    $.name[]
    $.passwordHash[]
    $.isAdmin[]
    $.isActive[]
  ]

  $lRes[^self.sut.all[$.selectFieldsGroups[short, ext] $.asTable(true)]]
  $lColumns[^lRes.columns[]]
  ^self.assertHashEquals[
    ^lColumns.hash[column]{}
  ][
    $.userID[]
    $.login[]
    $.name[]
    $.job[]
    $.createdAt[]
    $.updatedAt[]
  ]

@testAll_selectUnknownGroup[]
  ^self._createTestUsers(5)

  ^self.assertRaises[pfSQLTable.unknown.group]{
    $lRes[^self.sut.all[$.selectFieldsGroups[short, ext, unknown] $.asTable(true)]]
  }

@testAll_aggregateGroups[]
  ^self._createTestUsers(5)

  $lRes[^self.sut.aggregate[
    _groups(base);
    _fields(createdAt) as ca;
    _groups();
  ][
    $.asTable(true)]
  ]
  $lColumns[^lRes.columns[]]
  ^self.assertHashEquals[
    ^lColumns.hash[column]{}
  ][
    $.userID[]
    $.login[]
    $.name[]
    $.passwordHash[]
    $.isAdmin[]
    $.isActive[]
    $.createdAt[]
  ]

@testAll_aggregateUnknownGroup[]
  ^self._createTestUsers(5)

  ^self.assertRaises[pfSQLTable.unknown.group]{
    $lRes[^self.sut.aggregate[
      _groups(unknown);
    ][
      $.asTable(true)
    ]]
  }

@testOne_skipOrderBy[]
  ^self._createTestUsers(5)
  $self.sut._defaultOrderBy[unknown]

  $lUser[^self.sut.one[
    $.userID[1]
    $.selectFieldsGroups[base]
  ]]

  ^self.assert($lUser.userID == 1)[UserID is $lUser.userID]

#----------------------------------------------------------------------------------------------------------------------

@CLASS
_TestUserModel

@BASE
pfSQLTable

@create[aOptions]
  ^BASE:create[users;$aOptions]

  ^self.addFields[
    $.userID[$.dbField[user_id] $.processor[int] $.primary(true) $.widget[none] $.groups[full, base, short]]
    $.login[$.label[] $.groups[full, base, short]]
    $.name[$.label[] $.groups[full, base, short]]
    $.job[$.label[] $.groups[ext]]
    $.passwordHash[$.dbField[password_hash] $.label[] $.groups[full, base]]
    $.isAdmin[$.dbField[is_admin] $.processor[bool] $.default(false) $.label[] $.groups[full, base]]
    $.isActive[$.dbField[is_active] $.processor[bool] $.default(true) $.widget[none] $.groups[full, base]]
    $.createdAt[$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true) $.widget[none] $.groups[ext]]
    $.updatedAt[$.dbField[updated_at] $.processor[auto_now] $.widget[none] $.groups[ext]]
  ]

  $self._defaultOrderBy[$.userID[asc]]

#----------------------------------------------------------------------------------------------------------------------

@CLASS
TestSQLite3SQLORMPFSQLTable

@BASE
ORMPFSQLTableTests

@GET_connectString[]
  $result[$self._sqliteConnectString]

@createTestSchema[]
  ^connect[$self.connectString]{
    ^void:sql{
      CREATE TABLE users (
          user_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          login varchar(250) NOT NULL,
          name varchar(250) DEFAULT NULL,
          job varchar(250) DEFAULT NULL,
          password_hash varchar(250) DEFAULT NULL,
          is_admin smallint DEFAULT 0 NOT NULL,
          is_active smallint DEFAULT 1 NOT NULL,
          created_at datetime,
          updated_at datetime,
          UNIQUE(login)
      )
    }
  }

#----------------------------------------------------------------------------------------------------------------------

@CLASS
TestMySQLORMPFSQLTable

@BASE
ORMPFSQLTableTests

@GET_connectString[]
  $result[$self._mysql57ConnectString]

@createTestSchema[]
  ^connect[$self.connectString]{
    ^void:sql{
      CREATE TABLE users (
          user_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
          login varchar(250) NOT NULL,
          name varchar(250) DEFAULT NULL,
          job varchar(250) DEFAULT NULL,
          password_hash varchar(250) DEFAULT NULL,
          is_admin smallint DEFAULT 0 NOT NULL,
          is_active smallint DEFAULT 1 NOT NULL,
          created_at datetime,
          updated_at datetime,
          UNIQUE(login)
      )
    }
  }

#----------------------------------------------------------------------------------------------------------------------

@CLASS
TestPostgresORMPFSQLTable

@BASE
ORMPFSQLTableTests

@GET_connectString[]
  $result[$self._postgresConnectString]

@createTestSchema[]
  ^connect[$self.connectString]{
    ^void:sql{
      CREATE TABLE users (
          user_id SERIAL NOT NULL,
          login character varying(250) NOT NULL,
          name character varying(250) DEFAULT NULL::character varying,
          job character varying(250) DEFAULT NULL::character varying,
          password_hash character varying(250) DEFAULT NULL::character varying,
          is_admin smallint DEFAULT 0 NOT NULL,
          is_active smallint DEFAULT 1 NOT NULL,
          created_at timestamp without time zone,
          updated_at timestamp without time zone
      )
    }

    ^void:sql{
      CREATE UNIQUE INDEX users_login_uindex ON users USING btree (login)
    }
  }
