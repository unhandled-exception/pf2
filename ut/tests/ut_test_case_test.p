@USE
pf2/lib/tests/unittest.p

@CLASS
TestPFTestCase

@BASE
pfTestCase

@OPTIONS
locals

@setUp[]
  $self.sut[^__pfTestCase::create[]]

@assertRaisesFailureException[aCode]
  ^self.assertRaises[$pfTestExceptions:failure]{
    $result[$aCode]
  }
  $caller.[exception][$exception]

@assertNotRaisesFailureException[aCode]
  ^self.assertNotRaises[$pfTestExceptions:failure]{
    $result[$aCode]
  }

@testId[]
  ^self.assertEq[^sut.id[];__pfTestCase.runTest]

@testSetupAndTeardownOk[]
  $lSUT[^__pfTestCase::create[testSuccess]]
  ^self.assertNotDef[$lSUT.setupValue]
  ^self.assertNotDef[$lSUT.tearDownValue]
  ^lSUT.run[]
  ^self.assertEq[$lSUT.setupValue;value 1]
  ^self.assertEq[$lSUT.tearDownValue;value 2]
  ^self.assertTrue(^lSUT.result.wasSuccessful[])

@testSetupAndTeardownIfTestFail[]
  $lSUT[^__pfTestCase::create[testFailed]]
  ^self.assertNotDef[$lSUT.setupValue]
  ^self.assertNotDef[$lSUT.tearDownValue]
  ^lSUT.run[]
  ^self.assertEq[$lSUT.setupValue;value 1]
  ^self.assertEq[$lSUT.tearDownValue;value 2]
  ^self.assertFalse(^lSUT.result.wasSuccessful[])

@testSetupAndTeardownIfSetupFail[]
  $lSUT[^__pfTestCaseSetupFailed::create[testFailed]]
  ^self.assertNotDef[$lSUT.setupValue]
  ^self.assertNotDef[$lSUT.tearDownValue]
  ^lSUT.run[]
  ^self.assertEq[$lSUT.setupValue;value 1]
  ^self.assertNotDef[$lSUT.tearDownValue]
  ^self.assertFalse(^lSUT.result.wasSuccessful[])

@testSetupAndTeardownIfTearDownFail[]
  $lSUT[^__pfTestCaseTearDownFailed::create[testFailed]]
  ^self.assertNotDef[$lSUT.setupValue]
  ^self.assertNotDef[$lSUT.tearDownValue]
  ^lSUT.run[]
  ^self.assertEq[$lSUT.setupValue;value 1]
  ^self.assertEq[$lSUT.tearDownValue;value 2]
  ^self.assertFalse(^lSUT.result.wasSuccessful[])

@testAssertRaisesOk[]
  $lTestException[test.exception]
  ^try{
    ^self.sut.assertRaises[$lTestException]{
      ^throw[$lTestException;source value]
    }
    ^self.assertEq[source value;$exception.source]
  }{
    ^self.fail[Unexpected raise of $exception.type ($exception.source)]
  }

@testAssertRaisesFail[]
  ^try{
    ^self.sut.assertRaises[test.exception.2]{
      ^throw[test.exception.1;source value]
    }
  }{
    ^if($exception.type eq $pfTestExceptions:failure){
      $exception.handled(true)
      ^return[]
    }
    ^self.fail[Unexpected raise of $exception.type ($exception.source)]
  }
  ^self.fail[Not raised failure exception]

@testAssertRaisesRegexpStringOk[]
  $lTestException[test.exception.1]
  ^try{
    ^self.sut.assertRaisesRegexp[exception\.\d{1}^$]{
      ^throw[$lTestException;source value]
    }
    ^self.assertEq[source value;$exception.source]
  }{
    ^self.fail[Unexpected raise of $exception.type ($exception.source)]
  }

@testAssertRaisesRegexpStringFail[]
  ^try{
    ^self.sut.assertRaisesRegexp[test.exception.\D{1}]{
      ^throw[test.exception.1;source value]
    }
  }{
    ^if($exception.type eq $pfTestExceptions:failure){
      $exception.handled(true)
      ^return[]
    }
    ^self.fail[Unexpected raise of $exception.type ($exception.source)]
  }
  ^self.fail[Not raised failure exception]

@testAssertRaisesRegexpRegexOk[]
  $lTestException[test.exception.1]
  ^try{
    ^self.sut.assertRaisesRegexp[^regex::create[exception\.\d{1}^$][n]]{
      ^throw[$lTestException;source value]
    }
    ^self.assertEq[source value;$exception.source]
  }{
    ^self.fail[Unexpected raise of $exception.type ($exception.source)]
  }

@testAssertRaisesRegexpRegexFail[]
  ^try{
    ^self.sut.assertRaisesRegexp[^regex::create[exception\.\D{1}^$][n]]{
      ^throw[test.exception.1;source value]
    }
  }{
    ^if($exception.type eq $pfTestExceptions:failure){
      $exception.handled(true)
      ^return[]
    }
    ^self.fail[Unexpected raise of $exception.type ($exception.source)]
  }
  ^self.fail[Not raised failure exception]

@testAssertNotRaisesOk[]
  $lTestException[test.exception]
  ^try{
    ^self.sut.assertNotRaises[test.exception.2]{
      ^throw[$lTestException;source value]
    }
    ^self.assertEq[source value;$exception.source]
  }{
    ^if($exception.type eq $lTestException){
      $exception.handled(true)
      ^return[]
    }
    ^self.fail[Unexpected raise of $exception.type ($exception.source)]
  }

@testAssertNotRaisesFail[]
  ^try{
    ^self.sut.assertNotRaises[test.exception.2]{
      ^throw[test.exception.2;source value]
    }
  }{
    ^if($exception.type eq $pfTestExceptions:failure){
      $exception.handled(true)
      ^return[]
    }
    ^self.fail[Unexpected raise of $exception.type ($exception.source)]
  }
  ^self.fail[Not raised failure exception]

@testAssertNotRaisesRegexpStringOk[]
  $lTestException[test.exception.1]
  ^try{
    ^self.sut.assertNotRaisesRegexp[exception\.2^$]{
      ^throw[$lTestException;source value]
    }
  }{
    ^self.fail[Unexpected raise of $exception.type ($exception.source)]
  }

@testAssertNotRaisesRegexpStringFail[]
  ^try{
    ^self.sut.assertNotRaisesRegexp[test.exception\.1^$]{
      ^throw[test.exception.1;source value]
    }
  }{
    ^if($exception.type eq $pfTestExceptions:failure){
      $exception.handled(true)
      ^return[]
    }
    ^self.fail[Unexpected raise of $exception.type ($exception.source)]
  }
  ^self.fail[Not raised failure exception]

@testAssertNotRaisesRegexpRegexOk[]
  $lTestException[test.exception.1]
  ^try{
    ^self.sut.assertNotRaisesRegexp[^regex::create[exception\.2^$][n]]{
      ^throw[$lTestException;source value]
    }
  }{
    ^self.fail[Unexpected raise of $exception.type ($exception.source)]
  }

@testAssertNotRaisesRegexpRegexFail[]
  ^try{
    ^self.sut.assertNotRaisesRegexp[^regex::create[exception\.1^$][n]]{
      ^throw[test.exception.1;source value]
    }
  }{
    ^if($exception.type eq $pfTestExceptions:failure){
      $exception.handled(true)
      ^return[]
    }
    ^self.fail[Unexpected raise of $exception.type ($exception.source)]
  }
  ^self.fail[Not raised failure exception]

@testAssertOk[]
  ^self.sut.assert(true)

@testAssertFail[]
  ^self.assertRaisesFailureException{
    ^self.sut.assert(false)
  }
  ^self.assert($self.sut.__failureStack >= 1)[Failure stack is empty]

@testAssertTrueOk[]
  ^self.sut.assertTrue(true)

@testAssertTrueFail[]
  ^self.assertRaisesFailureException{
    ^self.sut.assertTrue(false)
  }

@testSkipTestOk[]
  ^self.assertRaises[$pfTestExceptions:skipTest]{
    ^self.sut.skipTest[]
  }

@testSkipTestIfOk[]
  ^self.assertRaises[$pfTestExceptions:skipTest]{
    ^self.sut.skipTestIf(true)
  }

@testNotSkipTestIf[]
  ^self.assertNotRaises[$pfTestExceptions:skipTest]{
    ^self.sut.skipTestIf(false)
  }

@testAssertDefOk[]
  $value[value]
  ^self.sut.assertDef[$value]

@testAssertDefFail[]
  ^self.assertRaisesFailureException{
    ^self.sut.assertDef[$void]
  }

@testAssertNotDefOk[]
  ^self.sut.assertNotDef[$void]

@testAssertNotDefFail[]
  $value[value]
  ^self.assertRaisesFailureException{
    ^self.sut.assertNotDef[$value]
  }

@testAssertEqOk[]
  ^self.sut.assertEq[str1;str1]

@testAssertEqFail[]
  ^self.assertRaisesFailureException{
    ^self.sut.assertEq[str1;str2]
  }

@testAssertNeOk[]
  ^self.sut.assertNe[str1;str2]

@testAssertNeFail[]
  ^self.assertRaisesFailureException{
    ^self.sut.assertNe[str1;str1]
  }

@testAssertNumEqOk[]
  ^self.sut.assertNumEq(3245;3245.0)

@testAssertNumEqFail[]
  ^self.assertRaisesFailureException{
    ^self.sut.assertNumEq(5245;3245.0)
  }

@testAssertNumNeOk[]
  ^self.sut.assertNumNe(5245;3245.0)

@testAssertNumNeFail[]
  ^self.assertRaisesFailureException{
    ^self.sut.assertNumNe(3245;3245.0)
  }

@testAssertRegexpMatchStringOk[]
  ^sut.assertRegexpMatch[test results;this is test results]

@testAssertRegexpMatchRegexOk[]
  ^sut.assertRegexpMatch[^regex::create[test results];this is test results]

@testAssertRegexpMatchStringFail[]
  ^self.assertRaisesFailureException{
    ^sut.assertRegexpMatch[is test results;this is not test results]
  }
  ^self.assertEq[$exception.source;"this is not test results" is not matched to regexp [is test results][n])]

@testAssertRegexpMatchRegexFail[]
  ^self.assertRaisesFailureException{
    ^sut.assertRegexpMatch[^regex::create[is test results];this is not test results]
  }
  ^self.assertEq[$exception.source;"this is not test results" is not matched to regexp [is test results][])]

@testAssertRegexpNotMatchStringOk[]
  ^sut.assertRegexpNotMatch[is not test results;this is test results]

@testAssertRegexpNotMatchRegexOk[]
  ^sut.assertRegexpNotMatch[^regex::create[is not test results];this is test results]

@testAssertRegexpNotMatchStringFail[]
  ^self.assertRaisesFailureException{
    ^sut.assertRegexpNotMatch[is test results;this is test results]
  }
  ^self.assertEq[$exception.source;"this is test results" is matched to regexp [is test results][n])]

@testAssertRegexpNotMatchRegexFail[]
  ^self.assertRaisesFailureException{
    ^sut.assertRegexpNotMatch[^regex::create[is test results];this test results]
  }
  ^self.assertEq[$exception.source;"this test results" is matched to regexp [is test results][])]

@testTimeIt[]
  $lDuration(^self.sut.timeIt{
    ^sleep(0.55)
  })
  ^self.assert($lDuration >= 0.5 && $lDuration <= 1)[duration is $lDuration]

@testAssertDurationGreaterEqualOk[]
  ^self.assertNotRaisesFailureException{
    ^self.sut.assertDurationGreaterEqual(0.2){
      ^sleep(0.3)
    }
  }

@testAssertDurationGreaterEqualFail[]
  ^self.assertRaisesFailureException{
    ^self.sut.assertDurationGreaterEqual(1){
      ^sleep(0.3)
    }
  }
  ^self.assertRegexpMatch[Duration \d\.\d+ <= 1;$exception.source]

@testAssertHashEqualsOk[]
  ^self.sut.assertHashEquals[
    $.f1[v1]
    $.f2(25)
    $.f3(33.1)
    $.f4[$void]
    $.f5[$.f1[v1] $.f2[v1] $.f3[$.0[1] $.1[2]]]
    $.f6[^array::create[1;2;3;4;5;6]]
    $.f7[^table::create{one,two
1,2}[$.separator[,]]]
  ][
    $.f7[^table::create{one,two
1,2}[$.separator[,]]]
    $.f6[^array::create[1;2;3;4;5;6]]
    $.f5[$.f2[v1] $.f3[$.1[2] $.0[1]] $.f1[v1]]
    $.f4[]
    $.f3(33.10)
    $.f2(25)
    $.f1[v1]
  ]

@testAssertHashEqualsFail[]
  ^self.assertRaisesFailureException{
    ^self.sut.assertHashEquals[
      $.f1[v1]
      $.f2[v2]
    ][
      $.f1[v1]
    ]
  }

  ^self.assertRaisesFailureException{
    ^self.sut.assertHashEquals[
      $.f1[v1]
      $.f2[v1]
    ][
      $.f1[v2]
      $.f2[v1]
    ]
  }

  ^self.assertRaisesFailureException{
    ^self.sut.assertHashEquals[
      $.f1(10)
    ][
      $.f1(11)
    ]
  }

  ^self.assertRaisesFailureException{
    ^self.sut.assertHashEquals[
      $.f1(10.12)
    ][
      $.f1(11.12)
    ]
  }

  ^self.assertRaisesFailureException{
    ^self.sut.assertHashEquals[
      $.f1(25)
    ][
      $.f1[25]
    ]
  }

  ^self.assertRaisesFailureException{
    ^self.sut.assertHashEquals[
      $.f1[$.f1[v1] $.f2[v2]]
    ][
      $.f1[$.f1[v2] $.f2[v2]]
    ]
  }

  ^self.assertRaisesFailureException{
    ^self.sut.assertHashEquals[
      $.f1[^array::create[1,2,3,4]]
    ][
      $.f1[^array::create[2,2,3,4]]
    ]
  }

#--------------------------------------------------------------------------------------------------

@CLASS
__pfTestCase

@BASE
pfTestCase

@setUp[]
  $self.setupValue[value 1]

@tearDown[]
  $self.tearDownValue[value 2]

@testFailed[]
  ^self.fail[Failed test]

@testSuccess[]

#--------------------------------------------------------------------------------------------------

@CLASS
__pfTestCaseSetupFailed

@BASE
__pfTestCase

@setUp[]
  $self.setupValue[value 1]
  ^self.fail[Fail setUp]

#--------------------------------------------------------------------------------------------------

@CLASS
__pfTestCaseTearDownFailed

@BASE
__pfTestCase

@tearDown[]
  $self.tearDownValue[value 2]
  ^self.fail[Fail tearDown]
