@USE
../lib/common.p

@CLASS
TestPFRetry

@BASE
pfTestCase

@OPTIONS
locals

@setUp[]
  $self.sut[^pfRetry::create[
    $.maxAttempts(3)
  ]]

@testRetryOk[]
  $i(0)
  ^self.assertNotRaises[next.step]{
    ^self.sut.process{
      ^i.inc[]
      ^if($i < $self.sut.maxAttempts){
        ^throw[next.step]
      }
    }
  }
  ^self.assert($i == $self.sut.maxAttempts)[attempts $i != max attempts $self.sut.maxAttempts]

@testRetryFail[]
  $i(0)
  ^self.assertRaises[next.step]{
    ^self.sut.process{
      ^i.inc[]
      ^throw[next.step]
    }
  }
  ^self.assert($i == $self.sut.maxAttempts)[attempts $i != max attempts $self.sut.maxAttempts]

@testRetryDelay[]
  $i(0)
  $lSUT[^pfRetry::create[$.maxDelay(0.2)]]
  ^self.assertDurationGreaterEqual(($lSUT.maxAttempts - 1) * 0.2){
    ^lSUT.process{
      ^i.inc[]
      ^if($i < $lSUT.maxAttempts){
        ^sleep(0.05)
        ^throw[next.step]
      }
    }
  }
  ^self.assert($i == $self.sut.maxAttempts)[attempts $i != max attempts $self.sut.maxAttempts]

#--------------------------------------------------------------------------------------------------

@CLASS
TestPFRetryOnException

@BASE
pfTestCase

@OPTIONS
locals

@setUp[]
  $self.retriableException[next.step]
  $self.sut[^pfRetry::create[
    $.maxAttempts(3)
    $.retryOnException[$self.retriableException]
  ]]

@testRetryOk[]
  $i(0)
  ^self.assertNotRaises[$self.retriableException]{
    ^self.sut.process{
      ^i.inc[]
      ^if($i < $self.sut.maxAttempts){
        ^throw[$self.retriableException]
      }
    }
  }
  ^self.assert($i == $self.sut.maxAttempts)[attempts $i != max attempts $self.sut.maxAttempts]

@testRetryFail[]
  $i(0)
  ^self.assertRaises[$self.retriableException]{
    ^self.sut.process{
      ^i.inc[]
      ^throw[$self.retriableException]
    }
  }
  ^self.assert($i == $self.sut.maxAttempts)[attempts $i != max attempts $self.sut.maxAttempts]

@testUnknownException[]
  $i(0)
  ^self.assertRaises[unknown.exception]{
    ^self.sut.process{
      ^i.inc[]
      ^throw[unknown.exception]
    }
  }
  ^self.assert($i == 1)[attempts $i != max attempts $self.sut.maxAttempts]

@testRetryDelay[]
  $i(0)
  $lSUT[^pfRetry::create[
    $.maxAttempts(3)
    $.retryOnException[$self.retriableException]
    $.maxDelay(0.2)
  ]]
  ^self.assertDurationGreaterEqual(($lSUT.maxAttempts - 1) * 0.2){
    ^lSUT.process{
      ^i.inc[]
      ^if($i < $lSUT.maxAttempts){
        ^sleep(0.05)
        ^throw[$self.retriableException]
      }
    }
  }
  ^self.assert($i == $self.sut.maxAttempts)[attempts $i != max attempts $self.sut.maxAttempts]
