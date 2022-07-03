@CLASS
pfUnittestProgram

@OPTIONS
locals

@create[]
  $self._loader[^pfTestsLoader::create[]]
  $self._stream[^pfTestStdoutStream::create[]]
  $self._runner[^pfTextTestsRunner::create[$.stream[$self._stream]]]

  $self._argv[$request:argv]
  $self._name[^file:basename[$self._argv.0]]
  $self._description[Run unit tests]

  $lArgs[^self.parseArgs[$request:argv]]
  $self._args[$lArgs.args]
  $self._options[$lArgs.options]

  $self._last_random_value(^math:random(10000)*^math:random(10000))

@_random[]
  $self._last_random_value((17839837 * $self._last_random_value + 395312313) % 1339765)
  $result($self._last_random_value)

@main[]
  $result[]
  ^try{
    ^if(^self._options.contains[-h]){
      ^self.usage[]
      ^return[]
    }

    $lTests[^self._loader.loadFromPath[]]
    ^if(!$lTests){
      ^self.println[Tests not found]
      ^self.status[2]
      ^return[]
    }

    ^lTests.sort[;v]{$v.name}
    ^if(^self._options.contains[-r]){
      ^if(^self._options.[-r].int(0) != 0){
        $self._last_random_value($self._options.[-r])
      }

      ^self.println[Tests random seed is $self._last_random_value]
      ^lTests.sort[;v](^self._random[])
    }

    ^if(def $self._args.1){
      $lTests[^self.filterTests[$lTests;$self._args.1]]
    }

    ^switch(true){
      ^case(^self._options.contains[-l]){
        ^self.printTestsList[$lTests]
      }
      ^case[DEFAULT]{
        ^self._runner.runTests[$lTests;
          $.verbose(^self._options.contains[-v])
        ]
      }
    }
  }{}{
    ^self.flush[]
  }

@filterTests[aTests;aFilterRegexp]
  $result[^hash::create[]]

  ^try{
    $lFilterRegexp[^regex::create[^taint[as-is][$aFilterRegexp]][ni]]
  }{
    $exception.handled(true)
    ^self.status[0]
    ^self.println[$exception.type ($exception.source)]
    ^self.println[$exception.comment]
  }

  ^self.println[Filter tests by [$lFilterRegexp.pattern][$lFilterRegexp.options]]
  ^self.flush[]
  ^aTests.foreach[;t]{
    ^if(^t.name.match[$lFilterRegexp]){
      $result.[^eval($result)][$t]
    }
  }

@printTestsList[aTests]
  ^aTests.foreach[;t]{
    ^self.println[$t.name]
  }

@status[aCode]
  $result[]
  $response:status[$aCode]

@parseArgs[aArgv] -> [$.args $.options]
  $result[
    $.args[^hash::create[]]
    $.options[^hash::create[]]
  ]
  ^aArgv.foreach[;v]{
    ^if(^v.left(1) eq "-"){
      $result.options.[^v.left(2)][^v.mid(3)]
      ^continue[]
    }
    $result.args.[^eval($result.args)][$v]
  }

@print[aStr][results]
  ^self._stream.write[$aStr]

@println[aStr][results]
  ^self._stream.writeln[$aStr]

@flush[][results]
  ^self._stream.flush[]

@usage[]
  ^self.println[$self._name [test_regex]]
  ^self.println[$self._description]
  ^self.println[]
  ^self.println[Options:]
  ^self.println[[test_regex]^#09Filter tests by pattern]
  ^self.println[^#09-h^#09Print usage and exit]
  ^self.println[^#09-l^#09Print tests list and exit]
  ^self.println[^#09-r[=seed]^#09Run test in random order]
  ^self.println[^#09-v^#09Verbose]
  ^self.flush[]

#--------------------------------------------------------------------------------------------------

@CLASS
pfTestsLoader

@OPTIONS
locals

@create[]
  $self._testClassPattern[^regex::create[^^Test\p{Lu}][n]]
  $self._testMethodPattern[^regex::create[^^test[\p{Lu}_]][n]]

@loadFromParser[aOptions]
## aOptions.pathPrefix — удалить из пути префикс
  $result[^hash::create[]]
  $lClasses[^reflection:classes[]]

  ^lClasses.foreach[class_name;]{
    ^if(^class_name.match[$self._testClassPattern]){
      $lClass[^reflection:class_by_name[$class_name]]
      $lClassPath[^reflection:filename[$lClass]]

      $lClassTests[^hash::create[]]
      $lMethods[^reflection:methods[$class_name;$.reverse(false)]]
      ^lMethods.foreach[method;]{
        ^if(^method.match[$self._testMethodPattern]){
          $result.[^eval($result)][
            $.path[$lClassPath]
            $.className[$class_name]
            $.class[$lClass]
            $.method[$method]
            $.name[^self._removePathPrefix[$lClassPath;$aOptions.pathPrefix]@${class_name}.$method]
          ]
        }
      }
    }
  }

@loadFromPath[aPath;aOptions]
## aOptions.filter[_test\.p^$]
## aOptions.recursive(true)
  $aPath[^if(def $aPath){$aPath}{.}]
  $lFilter[^regex::create[^if(def $aOptions.filter){$aOptions.filter}{_test\.p^$}]]

  ^self._walk[$aPath][fname]{
    ^if(!^fname.match[$lFilter]){
      ^continue[]
    }
    ^use[$fname]
  }

  $result[^self.loadFromParser[
    $.pathPrefix[^if($aPath eq "."){$request:document-root}{$aPath}]
  ]]

@_removePathPrefix[aPath;aPrefix]
  $result[$aPath]
  ^if(def $aPrefix){
    $result[^result.match[^^(?:^taint[regex][$aPrefix])][]{}]
    $result[^result.match[(\.\/)+][g]{}]
  }

@_walk[aPath;aVarName;aCode;aOptions]
## Обходит дерево файлов начиная с aPath и выполняет для каждого найденного файла aCode.
## Имя файла c путем попадает в переменную с именем из aVarName.
## Файлы сортируются по именам.
## aOptions.recursive(true)
  $aPath[^aPath.trim[right;/\]]
  $lRecursive(^aOptions.recursive.bool(true))

  $lFiles[^file:list[$aPath]]
  ^lFiles.sort{$lFiles.name}[asc]

  ^lFiles.menu{
    ^if(-d "$aPath/$lFiles.name"){
      ^if(!$lRecursive){
        ^continue[]
      }
      ^self._walk[$aPath/$lFiles.name;caller.$aVarName]{$aCode}[$aOptions]
    }{
      ^process{^$caller.caller.$aVarName^[$aPath/$lFiles.name^]}
      $aCode
    }
  }

  ^if(^aVarName.left(7) ne "caller."){$caller.$aVarName[]}

#--------------------------------------------------------------------------------------------------

@CLASS
pfTestResult

@OPTIONS
locals

@create[aOptions]
## aOptions.description
  $self.description[$aOptions.description]

  $self.failures[^hash::create[]]
  $self.errors[^hash::create[]]
  $self.testsRun(0)
  $self.skipped[^hash::create[]]

  $self.expectedFailures[^hash::create[]]
  $self.unexpectedSuccesses[^hash::create[]]

@printErrors[]
## Called by TestRunner after test run
  $result[]

@startTest[aTest]
## Called when the given test is about to be run
  ^self.testsRun.inc[]
  $result[]

@startTestRun[]
## Called once before any tests are executed.
  $result[]

@stopTest[aTest]
## Called when the given test has been run
  $result[]

@stopTestRun[]
## Called once after all tests are executed.
  $result[]

@addError[aTest;aException;aStack]
## Called when an error has occurred.
  $result[]
  $self.errors.[^eval($self.errors)][
    $.test[$aTest]
    $.exception[$aException]
    $.stack[$aStack]
  ]

@addFailure[aTest;aException;aStack]
## Called when an error has occurred.
  $result[]
  $self.failures.[^eval($self.failures)][
    $.test[$aTest]
    $.exception[$aException]
    $.stack[$aStack]
  ]

@addSubTest[aTest;subtest;aException;aStack]
## Called at the end of a subtest.
  $result[]

@addSuccess[aTest]
## Called when a test has completed successfully
  $result[]

@addSkip[aTest;aReason]
## Called when a test is skipped.
  $result[]
  $self.skipped.[^eval($self.skipped)][
    $.test[$aTest]
    $.reason[$aReason]
  ]

@addExpectedFailure[aTest;aException;aStack]
## Called when an expected failure/error occurred.
  $result[]
  $self.expectedSuccess.[^eval($self.expectedSuccess)][
    $.test[$aTest]
    $.reason[$aReason]
  ]

@addUnexpectedSuccess[aTest]
## Called when a test was expected to fail, but succeed.
  $result[]
  $self.unexpectedSuccess.[^eval($self.unexpectedSuccess)][
    $.test[$aTest]
  ]

@wasSuccessful[]
## Tells whether or not this result was a success.
  $result(
    $self.failures == 0
    && $self.errors == 0)
    && !$self.unexpectedSuccesses
    )

@stop[]
## Indicates that the tests should be aborted.
  $result[]
  $self.shouldStop(true)

#--------------------------------------------------------------------------------------------------

@CLASS
pfTestStdoutStream

@create[aOptions]
  $self.buffer[^hash::create[]]

@addToBuffer[aStr;aNewLine]
  $result[]
  $self.buffer.[^eval($self.buffer)][
    $.s[$aStr]
    $.n(^aNewLine.bool(false))
  ]

@write[aStr]
  $result[]
  ^self.addToBuffer[$aStr](false)

@writeln[aStr]
  $result[]
  ^self.addToBuffer[$aStr](true)

@flush[]
## Выводит консоль в поток, в конце ставит \n
  $result[]
  ^if($self.buffer){
    $console:line[^self.buffer.foreach[;v]{$v.s^if($v.n){^#0A}}]
    ^self.buffer.delete[]
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfTextTestResult

@BASE
pfTestResult

@OPTIONS
locals

@create[aOptions]
## aOptions.stream
## aOptions.verbose(false)
  ^BASE:create[]
  $self.separator1[^for[i](1;70){=}]
  $self.separator2[^for[i](1;70){-}]
  $self.stream[^if(def $aOptions.stream){$aOptions.stream}{^pfTestStdoutStream::create[]}]
  $self.verbose(^aOptions.verbose.bool(false))

@getDescription[aTest]
  $result[^aTest.id[]]
  ^if(def $aTest.description){
    $result[$self.description]
  }

@startTestRun[]
  ^self.stream.writeln[Start tests]

@stopTestRun[]
  ^self.stream.writeln[Finish all tests]

@startTest[aTest]
  ^BASE:startTest[$aTest]
  ^if($self.verbose){
    ^self.stream.write[^self.getDescription[$aTest] ... ]
  }

@addSkip[aTest;aReason]
  ^BASE:addSkip[$aTest]
  ^if($self.verbose){
    ^self.stream.write[SKIP^if(def $aReason){ ($aReason)}]
  }

@addSuccess[aTest]
  ^BASE:addSuccess[$aTest]
  ^if($self.verbose){
    ^self.stream.write[OK]
  }

@addError[aTest;aException;aStack]
  ^BASE:addError[$aTest;$aException;$aStack]
  ^if($self.verbose){
    ^self.stream.write[ERROR]
  }

@addFailure[aTest;aException;aStack]
  ^BASE:addFailure[$aTest;$aException;$aStack]
  ^if($self.verbose){
    ^self.stream.write[FAIL]
  }

@stopTest[aTest]
  ^BASE:stopTest[$aTest]
  ^self.stream.flush[]

@printErrors[]
  ^if($self.errors || $self.failures){
    ^self.stream.writeln[]
  }
  ^self.printErrorList[ERROR;$self.errors]
  ^self.printErrorList[FAIL;$self.failures]

@printErrorList[aFlavour;aList]
  ^aList.foreach[;err]{
    ^self.stream.writeln[$self.separator2]
    ^self.stream.writeln[$aFlavour ^self.getDescription[$err.test]]
    ^self.stream.writeln[$self.separator2]
    ^self.stream.writeln[^if(def $err.exception.source){$err.exception.source}{Unhandled exception} ($err.exception.type)]
    ^if(def $err.exception.comment){
      ^self.stream.writeln[$err.exception.comment]
    }
    ^if($err.stack){
      ^self.stream.writeln[]
      ^err.stack.foreach[;v]{
        ^self.stream.writeln[$v.name^#09$v.file ($v.line)]
      }
    }(def $err.exception.file){
      ^self.stream.writeln[^#0A$err.exception.file (${err.exception.lineno}:$err.exception.colno^)]
    }
    ^self.stream.writeln[]
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfTextTestsRunner

@OPTIONS
locals

@create[aOptions]
## aOptions.steam
  $self.stream[^if(def $aOptions.stream){$aOptions.stream}{^pfTestStdoutStream::create[]}]

  $self._minMemoryLimit(4096)
  $self._compacts(0)

@doCleanup[aCode]
  $lStartMem[$status:memory]
  ^try{
    $result[$aCode]
  }{}{
    $lStopMem[$status:memory]
    ^if($lStopMem.ever_allocated_since_compact - $lStartMem.ever_allocated_since_compact > $self._minMemoryLimit){
      ^memory:compact[]
      ^self._compacts.inc[]
    }
  }

@runTests[aTests;aOptions]
## aOptions.verbose(false)
  $result[]
  $lStat[$.total(0) $.ok(0) $.fail(0)]

  $lTestTextResult[^pfTextTestResult::create[
    $.stream[$self.stream]
    $.verbose(^aOptions.verbose.bool(false))
  ]]

  $lStartRusage[$status:rusage]
  ^lTestTextResult.startTestRun[]
  ^aTests.foreach[;t]{
    ^self.doCleanup{
      $lTest[^reflection:create[$t.className;create;$t.method;
        $.name[$t.name]
      ]]
      ^lTest.run[$lTestTextResult]
    }
  }
  ^lTestTextResult.stopTestRun[]
  ^lTestTextResult.printErrors[]

  ^self.stream.writeln[^#0A$lTestTextResult.separator1]

  $lStopRusage[$status:rusage]
  $lStopMemory[$status:memory]
  ^self.stream.writeln[Run $lTestTextResult.testsRun tests in ^eval($lStopRusage.tv_sec - $lStartRusage.tv_sec + ($lStopRusage.tv_usec - $lStartRusage.tv_usec)/1000000)[%.2f] s (^eval($lStopMemory.free + $lStopMemory.used) KB memory, $self._compacts compacts)]

  $lInfos[^hash::create[]]

  ^if(!^lTestTextResult.wasSuccessful[]){
    ^self.stream.write[FAIL]
    $lInfos.[^lInfos._count[]][failures=^eval($lTestTextResult.failures)]
    $lInfos.[^lInfos._count[]][errors=^eval($lTestTextResult.errors)]
    $response:status[2]
  }{
    ^self.stream.write[OK]
  }
  ^if($lTestTextResult.skipped){
    $lInfos.[^lInfos._count[]][skipped=^eval($lTestTextResult.skipped)]
  }

  ^if($lInfos){
    ^self.stream.write[ (^lInfos.foreach[;v]{$v}[, ])]
  }

  ^self.stream.flush[]

#--------------------------------------------------------------------------------------------------

@CLASS
pfTestExceptions

@OPTIONS
locals

@auto[]
  $self.skipTest[pf.tests.skip.test]
  $self.failure[pf.test.failure]
  $self.notImplementedSUT[pf.test.sut.not.implemented]

#--------------------------------------------------------------------------------------------------

@CLASS
pfTestCase

@OPTIONS
locals

@create[aTestName;aOptions]
## aOptions.name
  $self.testName[^if(def $aTestName){$aTestName}{runTest}]
  $self.path[^reflection:filename[$self]]
  $self.name[^if(def $aOptions.name){$aOptions.name}{${self.CLASS_NAME}.$self.testName}]
  $self.description[]
  $self.__failureStack[]

@id[]
  $result[$self.name]

@defaultTestResult[]
  $result[^pfTestResult::create[]]

@fail[aReason;aComment]
  $self.__failureStack[^reflection:stack[]]
  ^throw[$pfTestExceptions:failure;$aReason;$aComment]

@skipTest[aReason]
  ^throw[$pfTestExceptions:skipTest;$aReason]

@skipTestIf[aCondition;aReason]
  $result[]
  ^if($aCondition){
    ^self.skipTest[$aReason]
  }

@setUp[]
  $self.sut[^__pfTestCaseNotImplementedSUT::create[]]

@tearDown[]
  $self.sut[]

@run[aResult]
  ^if(!def $aResult){
    $aResult[^if(def $aResult){$aResult}{^self.defaultTestResult[]}]
    ^aResult.startTestRun[]
  }
  $self.result[$aResult]
  ^try{
    ^aResult.startTest[$self]
    ^self.setUp[]
    ^try{
      ^self.[$self.testName][]
      ^aResult.addSuccess[$self]
    }{}{
      ^self.tearDown[]
    }
  }{
    ^switch[$exception.type]{
      ^case[$pfTestExceptions:skipTest]{
        ^aResult.addSkip[$self;$exception.source]
        $exception.handled(true)
      }
      ^case[$pfTestExceptions:failure]{
        ^aResult.addFailure[$self;$exception;$self.__failureStack]
        $exception.handled(true)
      }
      ^case[DEFAULT]{
        ^aResult.addError[$self;$exception]
        $exception.handled(true)
      }
    }
  }{
    ^aResult.stopTest[$self]
  }

@runTest[]
  $result[]

@unsafe[aCode;aCatchCode]
  $result[^try{$aCode}{$exception.handled(true)$aCatchCode}]

@assert[aCondition;aReason]
  $result[^self.assertTrue($aCondition)[$aReason]]

@assertTrue[aCondition;aReason][result]
  ^if(!$aCondition){
    ^self.fail[^if(def $aReason){$aReason}{Condition is not true}]
  }

@assertFalse[aCondition;aReason][result]
  ^if($aCondition){
    ^self.fail[^if(def $aReason){$aReason}{Condition is not false}]
  }

@_formatException[aException][result]
^taint[as-is][
Original exception:
$aException.type ($aException.comment)

Comment:
$aException.comment

$aException.file (${aException.lineno}:$aException.colno)]

@assertRaises[aExpectedExceptionType;aCode]
  ^try{
    $result[$aCode]
  }{
    ^if($exception.type eq $aExpectedExceptionType){
      $exception.handled(true)
      $caller.exception[$exception]
      ^return[]
    }{
      ^self.fail[$exception.type raised instead of $aExpectedExceptionType;^self._formatException[$exception]]
    }
  }
  ^self.fail[$aExpectedExceptionType not raised]

@assertRaisesRegexp[aExceptionRegexp;aCode]
  ^if(!($aExceptionRegexp is regex)){
    $aExceptionRegexp[^regex::create[$aExceptionRegexp]]
  }
  ^try{
    $result[$aCode]
  }{
    ^if(^exception.type.match[$aExceptionRegexp]){
      $exception.handled(true)
      $caller.exception[$exception]
      ^return[]
    }{
      ^self.fail[$exception.type not matched to [$aExceptionRegexp.pattern][$aExceptionRegexp.options];^self._formatException[$exception]]
    }
  }
  ^self.fail[$exception.type not raised]

@assertNotRaises[aExpectedExcetionType;aCode]
  ^try{
    $result[$aCode]
  }{
    ^if($exception.type eq $aExpectedExcetionType){
      ^self.fail[$exception.type was unexpected raised;^self._formatException[$exception]]
    }
  }

@assertNotRaisesRegexp[aExceptionRegexp;aCode]
  ^if(!($aExceptionRegexp is regex)){
    $aExceptionRegexp[^regex::create[$aExceptionRegexp]]
  }
  ^try{
    $result[$aCode]
  }{
    ^if(^exception.type.match[$aExceptionRegexp]){
      ^self.fail[$exception.type is unexpected matched to [$aExceptionRegexp.pattern][$aExceptionRegexp.options];^self._formatException[$exception]]
    }{
      $exception.handled(true)
    }
  }

@assertDef[aValue;aReason]
  ^if(!def $aValue){
    ^self.fail[^if(def $aReason){$aReason}{The value is not definded}]
  }

@assertNotDef[aValue;aReason]
  ^if(def $aValue){
    ^self.fail[^if(def $aReason){$aReason}{The value is definded}]
  }

@assertEq[aStr1;aStr2;aReason][result]
  ^if($aStr1 ne $aStr2){
    ^self.fail[^if(def $aReason){$aReason}{"$aStr1" not equals to "$aStr2"}]
  }

@assertNe[aStr1;aStr2;aReason][result]
  ^if($aStr1 eq $aStr2){
    ^self.fail[^if(def $aReason){$aReason}{"$aStr1" equals to "$aStr2"}]
  }

@assertRegexpMatch[aRegexp;aStr;aReason][result]
  ^if(!($aRegexp is regex)){
    $aRegexp[^regex::create[$aRegexp][n]]
  }
  ^if(!^aStr.match[$aRegexp]){
    ^self.fail[^if(def $aReason){$aReason}{"$aStr" is not matched to regexp [$aRegexp.pattern][$aRegexp.options])}]
  }

@assertRegexpNotMatch[aRegexp;aStr;aReason][result]
  ^if(!($aRegexp is regex)){
    $aRegexp[^regex::create[$aRegexp][n]]
  }
  ^if(^aStr.match[$aRegexp]){
    ^self.fail[^if(def $aReason){$aReason}{"$aStr" is matched to regexp [$aRegexp.pattern][$aRegexp.options])}]
  }

@timeIt[aCode] -> double(duration in seconds)
  $lStart[$status:rusage]
  $void[$aCode]
  $lStop[$status:rusage]
  $result($lStop.tv_sec - $lStart.tv_sec + ($lStop.tv_usec - $lStart.tv_usec)/1000000)

@assertDurationGreaterEqual[aDurationInSeconds;aCode]
  $lDuration(^self.timeIt{
    $result[$aCode]
  })
  ^if($lDuration <= $aDurationInSeconds){
    ^self.fail[Duration $lDuration <= $aDurationInSeconds]
  }

@assertHashEquals[aActual;aExpected]
  $aActual[^hash::create[$aActual]]
  $aExpected[^hash::create[$aExpected]]

  $lEqualsTypes[
    $.int[math]
    $.double[math]
    $.bool[math]
    $.string[string]
    $.void[string]
    $._default[fail]
  ]
  ^try{
    ^if($aActual != $aExpected){
      ^throw[hashes.not.equals;Different length]
    }
    ^aExpected.foreach[k;v]{
      ^if(!^aActual.contains[$k]){
        ^throw[hashes.not.equals;Actual hasn't contains "$k" key]
      }
      $lExpEqType[$lEqualsTypes.[$v.CLASS_NAME]]
      $lAqEqType[$lEqualsTypes.[$aActual.[$k].CLASS_NAME]]
      ^if($lExpEqType ne $lAqEqType){
        ^throw[hashes.not.equals;Key $k has diff equal types]
      }
      ^if(
        ($lExpEqType eq "math" && $aActual.[$k] != $v)
        || ($lExpEqType eq "string" && $aActual.[$k] ne $v)
      ){
        ^throw[hashes.not.equals;Not equals value for "$k" key]
      }($lExpEqType eq "fail" || $lAqEqType eq "fail"){
        ^throw[hashes.not.equals;Can't compare $v.CLASS_NAME and $aActual.[$k].CLASS_NAME for "$k" key]
      }
    }
  }{
    ^if($exception.type eq "hashes.not.equals"){
      $exception.handled(true)
      ^self.fail[Hashes not equals ($exception.source).^#0A^#0AActual:^#0A^json:string[$aActual;$.indent(true)]^#0A^#0AExpected:^#0A^json:string[$aExpected;$.indent(true)]^#0A]
    }
  }

#--------------------------------------------------------------------------------------------------

@CLASS
__pfTestCaseNotImplementedSUT

@create[]

@GET_DEFAULT[]
  ^throw[$pfTestExceptions:notImplementedSUT]
