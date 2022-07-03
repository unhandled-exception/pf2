@USE
pf2/lib/sql/connection.p

@CLASS
BaseTestSQLConnection

@OPTIONS
locals

@BASE
pfTestCase

@auto[]
  $self._sqliteConnectString[sqlite://:memory:]
  $self._mysqlConnectString[mysql://test:test@127.0.0.1:8306/mysql_test]
  $self._postgresConnectString[postgresql://test:test@127.0.0.1:8432/pg_test]

@setUp[]
  ^BASE:setUp[]
  $self.connection[^pfSQLConnection::create[$self.connectString;
    $.enableQueriesLog(true)
    $.enableMemoryCache(true)
  ]]
  ^self.clearTestDatabase[]
  ^self.createTestSchema[]

@tearDown[]
  $self.connection[]
  ^BASE:tearDown[]

@createTestSchema[]

@assertSQLStatementsList[aExpected]
## aExpected[string|hash]
  $lActual[^#0A^self.sut.stat.queries.foreach[;v]{$v.query}[^#0A]^#0A]
  $lActual[^lActual.match[(AUTO_SAVEPOINT)_.+?\b][g]{$match.1}]
  ^if($aExpected is hash){
    $aExpected[^aExpected.foreach[;v]{$v}[^#0A]]
  }
  ^self.assertEq[$lActual;^#0A$aExpected^#0A]

@assertEqualsAsJSON[aActual;aExpected]
  ^self.assertEq[^json:string[$aActual;$.indent(true)];^json:string[$aExpected;$.indent(true)]]

@createTestTable[aOptions]
## aOptions.rows(20)
  ^self.fail[Not implemented]

@fetchTestDatabaseSchema[]
  ^switch[$self.connection.dialect.name]{
    ^case[postgres]{
      ^self._postgresFetchTestDatabaseSchema[]
    }
    ^case[mysql]{
      ^self._mysqlFetchTestDatabaseSchema[]
    }
    ^case[sqlite]{
      ^self._sqliteFetchTestDatabaseSchema[]
    }
    ^case[DEFAULT]{
      ^self.fail[$self.connection.dialect.name is an unknown sql-dialect]
    }
  }

@_mysqlFetchTestDatabaseSchema[]
  ^connect[$self.connectString]{
    $result[^table::sql{
        select case upper(table_type)
                 when 'BASE TABLE' then 'table'
                 when 'VIEW' then 'view'
                 else lower(table_type)
               end as type,
               table_name as name
          from information_schema.tables
         where table_type in ('BASE TABLE', 'VIEW')
    }]
  }

@_sqliteFetchTestDatabaseSchema[]
# https://www.sqlite.org/schematab.html
  ^connect[$self.connectString]{
    $result[^table::sql{
        select type, name, tbl_name
          from sqlite_master
         where name not in ('sqlite_sequence', 'sqlite_schema', 'sqlite_master')
      order by name, type
    }]
  }

@_postgresFetchTestDatabaseSchema[]
  ^connect[$self.connectString]{
    $result[^table::sql{
        select case upper(table_type)
                 when 'BASE TABLE' then 'table'
                 when 'VIEW' then 'view'
                 else lower(table_type)
               end as type,
               table_name as name
          from information_schema.tables
         where table_type in ('BASE TABLE', 'VIEW')
               and table_schema = 'public'
    }]
  }

@clearTestDatabase[]
  $lSchema[^self.fetchTestDatabaseSchema[]]]

  ^lSchema.foreach[;v]{
    ^connect[$self.connectString]{
      ^switch[^v.type.lower[]]{
        ^case[table]{
          ^void:sql{DROP TABLE IF EXISTS ^taint[as-is][$v.name]}
        }
        ^case[view]{
          ^void:sql{DROP VIEW IF EXISTS ^taint[as-is][$v.name]}
        }
        ^case[trigger]{
          ^void:sql{DROP TRIGGER IF EXISTS ^taint[as-is][$v.name]}
        }
      }
    }
  }
