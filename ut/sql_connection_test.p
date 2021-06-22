@USE
pf2/lib/sql/connection.p

@CLASS
BaseTestSQLConnection

@OPTIONS
locals

@BASE
pfTestCase

@setUp[]
  $self.connectString[sqlite://:memory:]
  $self.sut[^pfSQLConnection::create[$self.connectString;
    $.enableQueriesLog(true)
    $.enableMemoryCache(true)
  ]]

@tearDown[]
  ^BASE:tearDown[]

@assertSQLStatementsList[aExpected]
## aExpected[string|hash]
  $lActual[^#0A^self.sut.stat.queries.foreach[;v]{$v.query}[^#0A]^#0A]
  $lActual[^lActual.match[(AUTO_SAVEPOINT)_.+?\b][g]{$match.1}]
  ^if($aExpected is hash){
    $aExpected[^aExpected.foreach[;v]{$v}[^#0A]]
  }
  ^self.assertEq[$lActual;^#0A$aExpected^#0A]

@assertEqualAsJSON[aActual;aExpected]
  ^self.assertEq[^json:string[$aActual];^json:string[$aExpected]]

@createTestTable[aOptions]
## aOptions.rows(20)
  $result[table_^math:uid64[]]
	$lRows(^aOptions.rows.int(20))
  ^connect[$self.connectString]{
		^void:sql{CREATE TABLE $result (a integer primary key autoincrement, b int)}
		^void:sql{INSERT INTO $result (b) VALUES ^for[i](1;$lRows){($i * 100)}[, ]}
	}

#----------------------------------------------------------------------------------------------------------------------

@CLASS
TestPFConnection

@BASE
BaseTestSQLConnection

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
    $.0[BEGIN TRANSACTION]
    $.1[COMMIT]
  ]

@testTransactionRollback[]
  ^self.assertRaises[test.rollback]{
    ^self.sut.transaction{
      ^throw[test.rollback]
    }
  }
  ^self.assertSQLStatementsList[
    $.0[BEGIN TRANSACTION]
    $.1[ROLLBACK]
  ]

@testTransactionWithModes[]
  ^self.sut.transaction[EXCLUSIVE]{}
  ^self.assertSQLStatementsList[
    $.0[BEGIN EXCLUSIVE TRANSACTION]
    $.1[COMMIT]
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
    $.0[BEGIN TRANSACTION]
    $.1[COMMIT]
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
      $.0[BEGIN TRANSACTION]
      $.1[SAVEPOINT sp1]
      $.2[RELEASE SAVEPOINT sp1]
      $.3[SAVEPOINT sp2]
      $.4[ROLLBACK TO SAVEPOINT sp2]
      $.5[SAVEPOINT sp3]
      $.6[RELEASE SAVEPOINT sp3]
      $.7[COMMIT]
  ]

@testNestedTrnsactionAsSavepoints[]
  ^self.sut.transaction{
    ^self.sut.transaction{
    }
  }[$.nestedAsSavepoints(true)]
  ^self.assertSQLStatementsList[
    $.0[BEGIN TRANSACTION]
    $.1[SAVEPOINT AUTO_SAVEPOINT]
    $.2[RELEASE SAVEPOINT AUTO_SAVEPOINT]
    $.3[COMMIT]
  ]

@testBegin[]
  ^self.sut.begin[]
  ^self.assertSQLStatementsList[BEGIN TRANSACTION]

@testCommit[]
  ^self.sut.commit[]
  ^self.assertSQLStatementsList[COMMIT]

@testRollback[]
  ^self.sut.connect{
    ^void:sql{BEGIN}
    ^self.sut.rollback[]
  }
  ^self.assertSQLStatementsList[ROLLBACK]

@testRelease[]
  ^self.sut.connect{
    ^void:sql{SAVEPOINT sp1}
    ^self.sut.release[sp1]
  }
  ^self.assertSQLStatementsList[RELEASE SAVEPOINT sp1]

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
  ^self.assertEqualAsJSON[$lActual;^table::create{a	b
6	600
7	700}]

@testHash[]
  $lTable[^self.createTestTable[]]
	^self.assertNotRaises[sql.execute]{
		$lActual[^self.sut.hash{select * from $lTable order by a}[
      $.limit(2)
      $.offset(5)
    ]]
	}
  ^self.assertEqualAsJSON[$lActual;
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
    $.0[BEGIN TRANSACTION]
    $.1[select 2+2]
    $.2[select 2+2]
    $.3[select 2+2]
    $.4[COMMIT]
  ]
