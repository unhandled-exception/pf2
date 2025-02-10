@USE
pf2/lib/sql/connection.p
sql/testutils.p


@CLASS
CommonPFSQLConnectionTests

@BASE
BaseTestSQLConnection

@setUp[]
  ^BASE:setUp[]
  $self.sut[$self.connection]
  $self._testTablesCount(0)

@testConnect[]
 ^self.assertNotRaises[sql.execute]{
    ^self.sut.connect{
      ^int:sql{select 1}
    }
  }

@testStat[]
  ^self.sut.int{select 1}[$.limit(1) $.offset(0)]
  $lStat[$self.sut.stat]
  ^self.assert($lStat.queriesCount == 1)[Queries count is $lStat.queriesCount]
  ^self.assert($lStat.queriesTime > 0)[Queries time is $lStat.queriesCount]
  ^self.assert($lStat.queries > 0)[Queries list is empty]

  $lQuery[$lStat.queries.0]
  ^self.assertEq[$lQuery.type;int]
  ^self.assertEq[$lQuery.query;select 1]
  ^self.assert($lQuery.time > 0)[query.time == $lQuery.time]
  ^self.assertEq[$lQuery.limit;1]
  ^self.assertEq[$lQuery.offset;0]
  ^self.assertEq[$lQuery.results;1]

@testTransaction[]
  ^self.sut.transaction{}
  ^self.assertSQLStatementsList[
    $.0[^self.sut.dialect.begin[]]
    $.1[^self.sut.dialect.commit[]]
  ]

@testTransactionRollback[]
  ^self.assertRaises[test.rollback]{
    ^self.sut.transaction{
      ^throw[test.rollback]
    }
  }
  ^self.assertSQLStatementsList[
    $.0[^self.sut.dialect.begin[]]
    $.1[^self.sut.dialect.rollback[]]
  ]

@testTransactionWithModes[]
  ^self.sut.transaction[READ ONLY]{}
  ^self.assertSQLStatementsList[
    $.0[^self.sut.dialect.begin[READ ONLY]]
    $.1[^self.sut.dialect.commit[]]
  ]

@testNestedTransaction[]
  ^self.sut.transaction{
    ^self.sut.transaction{
      ^self.sut.transaction{
#       Не попадет в лог
        ^int:sql{select 1}
      }
    }
  }
  ^self.assertSQLStatementsList[
    $.0[^self.sut.dialect.begin[]]
    $.1[^self.sut.dialect.commit[]]
  ]

@testSavepoint[]
  ^self.sut.transaction{
    ^self.sut.savepoint[sp1]{}
    ^unsafe{
      ^self.sut.savepoint[sp2]{
        ^throw[test.rollback]
      }
    }
    ^self.sut.savepoint[sp3]{}
  }
  ^self.assertSQLStatementsList[
      $.0[^self.sut.dialect.begin[]]
      $.1[^self.sut.dialect.savepoint[sp1]]
      $.2[^self.sut.dialect.release[sp1]]
      $.3[^self.sut.dialect.savepoint[sp2]]
      $.4[^self.sut.dialect.rollback[sp2]]
      $.5[^self.sut.dialect.savepoint[sp3]]
      $.6[^self.sut.dialect.release[sp3]]
      $.7[^self.sut.dialect.commit[]]
  ]

@testNestedTrnsactionAsSavepoints[]
  ^self.sut.transaction{
    ^self.sut.transaction{
    }
  }[$.nestedAsSavepoints(true)]
  ^self.assertSQLStatementsList[
    $.0[^self.sut.dialect.begin[]]
    $.1[^self.sut.dialect.savepoint[AUTO_SAVEPOINT]]
    $.2[^self.sut.dialect.release[AUTO_SAVEPOINT]]
    $.3[^self.sut.dialect.commit[]]
  ]

@testBegin[]
  ^self.sut.begin[]
  ^self.assertSQLStatementsList[^self.sut.dialect.begin[]]
  ^self.sut.connect{
    ^void:sql{ROLLBACK}
  }

@testCommit[]
  ^self.sut.connect{
    ^void:sql{BEGIN}
  }
  ^self.sut.commit[]
  ^self.assertSQLStatementsList[^self.sut.dialect.commit[]]

@testRollback[]
  ^self.sut.connect{
    ^void:sql{BEGIN}
    ^self.sut.rollback[]
  }
  ^self.assertSQLStatementsList[^self.sut.dialect.rollback[]]

@testRelease[]
  ^self.sut.connect{
    ^void:sql{BEGIN}
    ^void:sql{SAVEPOINT sp1}
    ^self.sut.release[sp1]
    ^void:sql{ROLLBACK}
  }
  ^self.assertSQLStatementsList[^self.sut.dialect.release[sp1]]

@testVoid[]
  $lTable[table_^math:uid64[]]
  ^self.assertNotRaises[sql.execute]{
    ^self.sut.void{CREATE TABLE $lTable (a int, primary key (a))}
  }
  ^self.assertSQLStatementsList[CREATE TABLE $lTable (a int, primary key (a))]

@testTable[]
  $lTable[^self.createTestTable[]]
	^self.assertNotRaises[sql.execute]{
		$lActual[^self.sut.table{select * from $lTable order by a}[$.limit(2) $.offset(5)]]
  }
  ^self.assertEqualsAsJSON[$lActual;^table::create{a,b
6,600
7,700}[$.separator[,]]]

@testHash[]
  $lTable[^self.createTestTable[]]
	^self.assertNotRaises[sql.execute]{
		$lActual[^self.sut.hash{select * from $lTable order by a}[
      $.limit(2)
      $.offset(5)
    ]]
  }
  ^self.assertEqualsAsJSON[$lActual;
    $.6[$.b[600]]
    $.7[$.b[700]]
  ]

@testString[]
  ^self.assertEq[^self.sut.string{select 'string data'};string data]

@testInt[]
  $lValue(^self.sut.int{select 12345})
  ^self.assert($lValue == 12345)[value is $lValue]

@testDouble[]
  $lValue(^self.sut.double{select 12345.12})
  ^self.assert($lValue == 12345.12)[value is $lValue]

@testSafeInsert[]
  $lTable[^self.createTestTable[]]
  $lCalled(false)
  ^self.assertNotRaises[sql.execute]{
    ^self.sut.safeInsert{
      ^void:sql{INSERT INTO $lTable (a, b) VALUES (1, 1001)}
    }{
      $lCalled(true)
      ^void:sql{INSERT INTO $lTable (a, b) VALUES (1001, 1001)}
    }
  }
  ^self.assertTrue($lCalled)[aExistsCode not called]

@testLastInsertID[]
  $lTable[^self.createTestTable[$.rows(50)]]
  ^self.sut.void{INSERT INTO $lTable (b) VALUES (1001)}
  ^self.assertEq[^self.sut.lastInsertID[];51]

@testMemoryCache[]
  ^self.sut.int{select 2+2}
  ^self.sut.int{select 2+2}
  ^self.sut.int{select 2+2}
  ^self.assertSQLStatementsList[select 2+2]

@testDisableMemoryCacheByTransaction[]
  ^self.sut.transaction{
    ^self.sut.int{select 2+2}
    ^self.sut.int{select 2+2}
    ^self.sut.int{select 2+2}
  }[
    $.disableMemoryCache(true)
  ]
  ^self.assertSQLStatementsList[
    $.0[^self.sut.dialect.begin[]]
    $.1[select 2+2]
    $.2[select 2+2]
    $.3[select 2+2]
    $.4[^self.sut.dialect.commit[]]
  ]

#----------------------------------------------------------------------------------------------------------------------

@CLASS
TestSQLite3SQLConnection

@BASE
CommonPFSQLConnectionTests

@GET_connectString[]
  $result[$self._sqliteConnectString]

@createTestTable[aOptions]
## aOptions.rows(20)
  ^self._testTablesCount.inc[]
  $result[test_table_$self._testTablesCount]
	$lRows(^aOptions.rows.int(20))
  ^connect[$self.connectString]{
		^void:sql{CREATE TABLE $result (a integer primary key autoincrement, b integer)}
		^void:sql{INSERT INTO $result (b) VALUES ^for[i](1;$lRows){($i * 100)}[, ]}
  }

@testTransactionWithModes[]
  ^self.sut.transaction[EXCLUSIVE]{}
  ^self.assertSQLStatementsList[
    $.0[^self.sut.dialect.begin[EXCLUSIVE]]
    $.1[^self.sut.dialect.commit[]]
  ]

#----------------------------------------------------------------------------------------------------------------------

@CLASS
TestMySQL57Connection

@BASE
CommonPFSQLConnectionTests

@GET_connectString[]
  $result[$self._mysql57ConnectString]

@createTestTable[aOptions]
## aOptions.rows(20)
  ^self._testTablesCount.inc[]
  $result[test_table_$self._testTablesCount]
  $lRows(^aOptions.rows.int(20))
  ^connect[$self.connectString]{
    ^void:sql{CREATE TABLE $result (a integer primary key auto_increment, b integer)}
    ^void:sql{INSERT INTO $result (b) VALUES ^for[i](1;$lRows){($i * 100)}[, ]}
  }

#----------------------------------------------------------------------------------------------------------------------

@CLASS
TestMySQL8Connection

@BASE
CommonPFSQLConnectionTests

@GET_connectString[]
  $result[$self._mysql8ConnectString]

@createTestTable[aOptions]
## aOptions.rows(20)
  ^self._testTablesCount.inc[]
  $result[test_table_$self._testTablesCount]
  $lRows(^aOptions.rows.int(20))
  ^connect[$self.connectString]{
    ^void:sql{CREATE TABLE $result (a integer primary key auto_increment, b integer)}
    ^void:sql{INSERT INTO $result (b) VALUES ^for[i](1;$lRows){($i * 100)}[, ]}
  }

#----------------------------------------------------------------------------------------------------------------------

@CLASS
TestPostgresConnection

@BASE
CommonPFSQLConnectionTests

@GET_connectString[]
  $result[$self._postgresConnectString]

@createTestTable[aOptions]
## aOptions.rows(20)
  ^self._testTablesCount.inc[]
  $result[test_table_$self._testTablesCount]
  $lRows(^aOptions.rows.int(20))
  ^connect[$self.connectString]{
    ^void:sql{CREATE TABLE $result (a serial primary key, b integer)}
    ^void:sql{INSERT INTO $result (b) VALUES ^for[i](1;$lRows){($i * 100)}[, ]}
  }
