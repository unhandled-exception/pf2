@USE
pf2/lib/sql/connection.p
pf2/lib/locks/pg_locks.p

@CLASS
TestPGLocks

@OPTIONS
locals

@BASE
pfTestCase

@setUp[]
  $self.connection1[^pfSQLConnection::create[postgresql://test:test@127.0.0.1:8432/pg_test;
    $.enableQueriesLog(true)
    $.enableMemoryCache(true)
  ]]
  $self.connection2[^pfSQLConnection::create[postgresql2://test:test@127.0.0.1:8432/pg_test;
    $.enableQueriesLog(true)
    $.enableMemoryCache(true)
  ]]

  $self.sut1[^pfPGLocksManager::create[$self.connection1]]
  $self.sut2[^pfPGLocksManager::create[$self.connection2]]

@tearDown[]
  ^self.connection1.string{select pg_advisory_unlock_all()}
  ^self.connection2.string{select pg_advisory_unlock_all()}

@test_keyToPGLiteral[]
  $lTests[
    $.0[$.key[123456789] $.result[x'25f9e794323b4538'::bigint]]
    $.1[$.key[000000000000000000000000000000000000000000] $.result[x'f573e011b414bf3f'::bigint]]
    $.2[$.key[-1000000] $.result[x'115e589db5ec8ec6'::bigint]]
    $.3[$.key[3924098320498230jf098fufjs98w34uj9sfe8jf98j98fsj98sfj9w8m94038jjf4q398fj398j349843jf98j] $.result[x'5761121f59bdba64'::bigint]]
  ]
  ^lTests.foreach[;t]{
    ^self.assertEq[^self.sut1.keyToPGLiteral[$t.key];$t.result]
  }

@test_lock_keys[]
  $lTests[
    $.0[123456789]
    $.1[000000000000000000000000000000000000000000]
    $.2[-1000000]
    $.3[3924098320498230jf098fufjs98w34uj9sfe8jf98j98fsj98sfj9w8m94038jjf4q398fj398j349843jf98j]
  ]
  ^lTests.foreach[;v]{
    $_(^self.sut1.tryAdvisoryXACTLock[$v])
  }

@test_tryAdvisoryLock[aKey]
  ^self.assertTrue(^self.sut1.tryAdvisoryLock[key])[Берем лок из первого соединения]
  ^self.assertFalse(^self.sut2.tryAdvisoryLock[key])[Берем лок из второго соединения]

@test_advisoryUnlock[]
  ^self.assertTrue(^self.sut1.tryAdvisoryLock[key])[Берем лок из первого соединения]
  ^self.assertFalse(^self.sut2.tryAdvisoryLock[key])[Берем лок из второго соединения]
  ^self.sut1.advisoryUnlock[key]
  ^self.assertTrue(^self.sut2.tryAdvisoryLock[key])[Берем лок из второго соединения после снятия всех блокировок]

@test_advisoryUnlockAll[]
  ^self.assertTrue(^self.sut1.tryAdvisoryLock[key])[Берем лок из первого соединения]
  ^self.assertFalse(^self.sut2.tryAdvisoryLock[key])[Берем лок из второго соединения]
  ^self.sut1.advisoryUnlockAll[]
  ^self.assertTrue(^self.sut2.tryAdvisoryLock[key])[Берем лок из второго соединения после снятия всех блокировок]

@test_tryAdvisoryXACTLock[aKey]
  ^self.connection1.transaction{
    ^self.assertTrue(^self.sut1.tryAdvisoryXACTLock[key])[Берем лок из первого соединения]
    ^self.assertFalse(^self.sut2.tryAdvisoryXACTLock[key])[Берем лок из второго соединения]
  }
  ^self.assertTrue(^self.sut2.tryAdvisoryXACTLock[key])[Берем лок из второго соединения после транзакции]

@test_exclusiveTransaction_ok[]
  ^self.sut1.exclusiveTransaction[key]{
    ^self.assertTrue(true)
  }{
    ^self.assertTrue(false)
  }

@test_exclusiveTransaction_fail[]
  ^self.assertTrue(^self.sut2.tryAdvisoryLock[key])[Берем лок из второго соединения]
  ^self.sut1.exclusiveTransaction[key]{
    ^self.assertTrue(false)
  }{
    ^self.assertTrue(true)
  }
