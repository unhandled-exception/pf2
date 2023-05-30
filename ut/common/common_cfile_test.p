@USE
pf2/lib/common.p

@CLASS
TestPFCFile

@OPTIONS
locals

@BASE
pfTestCase

@setUp[]
  ^BASE:setUp[]
  $self.httpbin[http://localhost:8880]
  $self.httpsbin[https://httpbin.org]

@assertSuccessResponse[aResponse]
  ^self.assert($aResponse is file)[Response is not a file ($aResponse.CLASS_NAME)]
  ^self.assert($aResponse.status >= 200 && $aResponse.status <= 299)[Response status is not successful — $aResponse.status ($aResponse.text)]

@parseResponseBody[aResponse]
  $result[^json:parse[^taint[as-is][$aResponse.text]]]
  ^self.assertDef[$result]{Response body has an empty data}

@testHttps[]
  $lRes[^pfCFile::load[text;$self.httpsbin/get;
    $.any-status(true)
    $.timeout(20)
  ]]
  ^self.assertSuccessResponse[$lRes]

  $lResponse[^self.parseResponseBody[$lRes]]
  ^self.assertEq[$lResponse.url;$self.httpsbin/get]

@testHttpGet[]
  $lRes[^pfCFile::load[text;$self.httpbin/get?url_value1=fvalue_1;
    $.any-status(true)
    $.method[GET]
    $.form[
      $.field1[value1]
      $.field2[value2]
    ]
  ]]
  ^self.assertSuccessResponse[$lRes]

  $lResponse[^self.parseResponseBody[$lRes]]
  ^self.assertEq[$lResponse.url;$self.httpbin/get?url_value1=fvalue_1&field1=value1&field2=value2]

@testHttpPost[]
  $lRes[^pfCFile::load[text;$self.httpbin/post?url_value1=fvalue_1;
    $.method[post]
    $.any-status(true)
    $.form[
      $.field1[value1]
      $.field2[value2]
    ]
  ]]
  ^self.assertSuccessResponse[$lRes]

  $lResponse[^self.parseResponseBody[$lRes]]
  ^self.assertEq[$lResponse.url;$self.httpbin/post?url_value1=fvalue_1]
  ^self.assertEq[^lResponse.form.foreach[k;v]{$k=$v}[,];field1=value1,field2=value2]

@testHttpPostBody[]
  $lRes[^pfCFile::load[text;$self.httpbin/post?url_value1=fvalue_1;
    $.method[post]
    $.any-status(true)
    $.headers[
      $.content-type[application/json]
    ]
    $.body[{"name": "value"}]
  ]]
  ^self.assertSuccessResponse[$lRes]

  $lResponse[^self.parseResponseBody[$lRes]]
  ^self.assertEq[$lResponse.url;$self.httpbin/post?url_value1=fvalue_1]
  ^self.assertEq[$lResponse.json.name;value]

@testHttpPut[]
  $lRes[^pfCFile::load[text;$self.httpbin/put;
    $.method[put]
    $.any-status(true)
  ]]
  ^self.assertSuccessResponse[$lRes]

@testHttpPatch[]
  $lRes[^pfCFile::load[text;$self.httpbin/patch;
    $.method[patch]
    $.any-status(true)
  ]]
  ^self.assertSuccessResponse[$lRes]

@testExceptionOnErrorCodes[]
  ^self.assertRaises[http.status]{
    $lRes[^pfCFile::load[text;$self.httpbin/status/500]]
  }

@testNoExceptionOnErrorCodesIfHasAnyStatusOptions[]
  ^self.assertNotRaises[http.status]{
    $lRes[^pfCFile::load[text;$self.httpbin/status/500;
      $.any-status(true)
    ]]
  }

@testRaiseHTTPHostException[]
  ^self.assertRaises[http.host]{
    $lRes[^pfCFile::load[text;http://unknown-host.domain]]
  }

@testRaiseHTTPTimeoutException[]
  ^self.assertRaises[http.timeout]{
    $lRes[^pfCFile::load[text;$self.httpbin/delay/2;
      $.timeout(1)
    ]]
  }

@testRaiseHTTPConnectException[]
  ^self.assertRaises[http.connect]{
    $lRes[^pfCFile::load[text;http://localhost:60180]]
  }

@testSendCookies[]
  $lCookies[
    $.cookie1[value1]
    $.cookie2[value2]
  ]
  $lRes[^pfCFile::load[text;$self.httpbin/cookies;
    $.any-status(true)
    $.method[GET]
    $.cookies[$lCookies]
  ]]
  ^self.assertSuccessResponse[$lRes]

  $lResponse[^self.parseResponseBody[$lRes]]
  ^self.assertHashEquals[$lResponse.cookies;$lCookies]

@testSendHeaders[]
  $lRes[^pfCFile::load[text;$self.httpbin/headers;
    $.any-status(true)
    $.method[GET]
    $.user-agent[PF2 tests]
    $.referer[test referer]
    $.headers[
      $.[X-PF2-Header][value345]
    ]
  ]]
  ^self.assertSuccessResponse[$lRes]
  $lResponse[^self.parseResponseBody[$lRes]]
  $lExpectedHeaders[
    $.Referer[test referer]
    $.User-Agent[PF2 tests]
    $.X-Pf2-Header[value345]
  ]
  ^self.assertHashEquals[
    ^lResponse.headers.select[k;](^lExpectedHeaders.contains[$k])
  ][
    $lExpectedHeaders
  ]

@testGetBinaryData[]
  $lRes[^pfCFile::load[binary;$self.httpbin/image/jpeg;
    $.any-status(true)
    $.name[test.jpg]
  ]]
  ^self.assertSuccessResponse[$lRes]

  ^self.assertNotRaisesRegexp[.+]{
    $lImage[^image::measure[$lRes]]
  }
