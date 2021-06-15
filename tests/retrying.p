#!/usr/bin/env parser3

@USE
pf2/lib/common.p

@main[][locals]
  Test the pfRetry class

  Retry and fail
  $r1[^pfRetry::create[]]
  ^pfClass:unsafe{
    $i(0)
    ^r1.process{
      ^i.inc[]
      [^if($i < 3){ok}{fail}] $i run test
      ^throw[exception]
    }
    [fail] Failed test
  }{
    [ok] Passed test
  }

  Retry and success
  $r2[^pfRetry::create[]]
  ^pfClass:unsafe{
    $i(0)
    ^r2.process{
      ^i.inc[]
      ^if($i < 3){^throw[exception]}
      [^if($i == 3){ok}{fail}] $i test
    }
    [ok] Passed test
  }{
    [fail] Failed test
  }

  Do not retry and success
  $r2[^pfRetry::create[]]
  ^pfClass:unsafe{
    $i(0)
    ^r2.process{
      ^i.inc[]
      [^if($i > 1){fail}{ok}] $i test

      ^if($i > 1){^throw[exception]}
    }
    [ok] Passed test
  }{
    [fail] Failed test
  }

  Retry on exception
  $r3[^pfRetry::create[$.retryOnException[exception]]]
  ^try{
    $i(0)
    ^r3.process{
      ^i.inc[]
      [^if($i < 3){ok}{fail}] $i run test
      ^if($i < 3){
        ^throw[exception]
      }{
        ^throw[uncatch.exception]
      }
    }
    [fail] Failed test
  }{
    ^if($exception.type eq "uncatch.exception"){
      $exception.handled(true)
      [ok] Passed test
    }{
      $exception.handled(true)
      [fail] Failed test ($exception.type)
    }
  }
