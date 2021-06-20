@CLASS
TestPFTestCase

@BASE
pfTestCase

@OPTIONS
locals

@setUp[]
  $self.sut[^__pfTestCase::create[]]

@tearDown[]
  $self.sut[]

@assertRaisesFailureException[aCode]
  ^self.assertRaises[$pfTestExceptions:failure]{
    $result[$aCode]
  }
  $caller.[exception][$exception]

@testAsString[]
  ^self.assertEq[^sut.asString[];__pfTestCase.runTest]

@testSetupAndTeardown[]
  ^self.assertNotDef[$self.sut.setupValue]
  ^self.assertNotDef[$self.sut.tearDownValue]
  ^self.sut.run[]
  ^self.assertEq[$self.sut.setupValue;value 1]
  ^self.assertEq[$self.sut.tearDownValue;value 2]

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

#--------------------------------------------------------------------------------------------------

@CLASS
__pfTestCase

@BASE
pfTestCase

@setUp[]
  $self.setupValue[value 1]

@tearDown[]
  $self.tearDownValue[value 2]
