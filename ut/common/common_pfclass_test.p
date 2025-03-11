@USE
pf2/lib/tests/unittest.p
pf2/lib/common.p

@CLASS
TestPFClass

@OPTIONS
locals

@BASE
pfTestCase

@testDynamicA[]
  $sut[^pfClass::create[]]
  $res[^sut.A[dyn;1;2;$.three[val1];$void;;four](5;6.34;true)[^array::create[1;2;3]]]]
  ^self.assertEq[^json:string[$res;$.one-line(true)];[ "dyn", "1", "2", { "three":"val1" }, null, "", "four", 5, 6.34, true, [ "1", "2", "3" ] ]]

@testStaticA[]
  $res[^pfClass:A[sta;1;2;$.three[val1];$void;;four](5;6.34;true)[^array::create[1;2;3]]]]
  ^self.assertEq[^json:string[$res;$.one-line(true)];[ "sta", "1", "2", { "three":"val1" }, null, "", "four", 5, 6.34, true, [ "1", "2", "3" ] ]]
