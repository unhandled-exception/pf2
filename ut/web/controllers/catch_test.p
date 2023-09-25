@USE
pf2/lib/web/controllers.p

@CLASS
TestControllersCatch

@OPTIONS
locals

@BASE
pfTestCase

@setUp[]
  $self.sut[^__ControllersCatchTest::create[]]

@call[route;opts]
  $result[^sut.dispatch[$route;^pfRequest::create[$.form[$opts]]]]

@test_catch_http.404[]
  $tr[^self.call[/not_found;$.type[http.404]]]
  ^self.assert($tr.status eq "200")
  ^self.assert($tr.body eq "not found")

@test_catch_http.301[]
  $tr[^self.call[/redir.301;$.type[http.301] $.source[http://redir.301]]]
  ^self.assert($tr.status eq "301")
  ^self.assert(^tr.getHeader[Location] eq "http://redir.301")

@test_catch_http.302[]
  $tr[^self.call[/redir.302;$.type[http.302] $.source[http://redir.302]]]
  ^self.assert($tr.status eq "302")
  ^self.assert(^tr.getHeader[Location] eq "http://redir.302")

@test_catch_unknown_exception[]
  ^self.assertRaises[test.catch.catch.*.unknown.exception]{
    $tr[^self.call[/unknown;$.type[unknown.exception]]]
  }

#--------------------

@CLASS
__ControllersCatchTest

@BASE
pfController

@create[aOptions]
  ^BASE:create[]
  $self.testExceptionPrefix[test.catch]

@catch<*>[r;e]
  ^throw[${self.testExceptionPrefix}.catch.*.$e.type;$e.type - $e.source - $e.comment]

@/DEFAULT[r]
  ^throw[$r.type;$r.source;$r.comment]

@/NOTFOUND[r]
  $result[not found]
