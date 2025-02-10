@USE
pf2/lib/sql/connection.p
pf2/lib/security/sql_security.p

@CLASS
BaseTestSQLSecurity

@OPTIONS
locals

@BASE
pfTestCase

@auto[]
  $self.DB_HOST[^if(def $env:CI_TESTS_DIND_HOST){$env:CI_TESTS_DIND_HOST}{127.0.0.1}]
  $self._sqliteConnectString[sqlite://:memory:]
  $self._mysql57ConnectString[mysql57://test:test_57@${self.DB_HOST}:8306/mysql_test_57]
  $self._mysql8ConnectString[mysql8://test:test_8@${self.DB_HOST}:9306/mysql_test_8]
  $self._postgresConnectString[postgresql://test:test@${self.DB_HOST}:8432/pg_test]

@setUp[]
# $self.connectString[] — setup in children
  $self.connection[^pfSQLConnection::create[$self.connectString;
    $.enableQueriesLog(true)
    $.enableMemoryCache(true)
  ]]
  $self.sut[^pfSQLSecurityCrypt::create[
    $.sql[$self.connection]
    $.secretKey[SECRET_KEY]
    $.serializer[base64]
  ]]
  $self.tokenData[
    $.id[123]
    $.value[value 1]
    $.data[
      $.innerValue[inner value]
      $.inner_id[321]
    ]
  ]

@testHEXEncrypt[]
  $lEncrypted[^self.sut.encrypt[secret data;
    $.serializer[hex]
  ]]
  ^self.assertEq[$lEncrypted;32671ae83911b0ac4f6570270a03a094]

@testHEXDecrypt[]
  $lDecrypted[^self.sut.decrypt[32671ae83911b0ac4f6570270a03a094;
    $.serializer[hex]
  ]]
  ^self.assertEq[$lDecrypted;secret data]

@testBase64Encrypt[]
  $lEncrypted[^self.sut.encrypt[secret data;
    $.serializer[base64]
  ]]
  ^self.assertEq[$lEncrypted;Mmca6DkRsKxPZXAnCgOglA==]

@testBase64Decrypt[]
  $lDecrypted[^self.sut.decrypt[Mmca6DkRsKxPZXAnCgOglA==;
    $.serializer[base64]
  ]]
  ^self.assertEq[$lDecrypted;secret data]

@testLongBase54EncryptedStringHasNotCR[]
  $lLongData[^for[i](1;20){data string with cr}[^#0A]]
  $lEncrypted[^self.sut.encrypt[$lLongData;$.serializer[base64]]]
  ^self.assertNe[$lLongData;$lEncrypted]
  ^self.assertRegexpNotMatch[\n;$lEncrypted]

  $lDecrypted[^self.sut.decrypt[$lEncrypted;$.serializer[base64]]]
  ^self.assertEq[$lDecrypted;$lLongData]

@testDigest[]
  ^self.assertEq[^self.sut.digest[secret string digest];2SNgbecIqs+I/OvvIrg/JDpDSBcvpnSsX2D6GNmaeNU=]

@testSignString[]
  ^self.assertEq[^self.sut.signString[secret string digest];2SNgbecIqs+I/OvvIrg/JDpDSBcvpnSsX2D6GNmaeNU=.secret string digest]

@testValidateSignatureAndReturnString[]
  ^self.assertEq[^self.sut.validateSignatureAndReturnString[2SNgbecIqs+I/OvvIrg/JDpDSBcvpnSsX2D6GNmaeNU=.secret string digest];secret string digest]

@testFailValidateSignatureAndReturnString[]
  ^self.assertRaises[security.invalid.signature]{
    ^self.assertEq[^self.sut.validateSignatureAndReturnString[invalid_sign.secret string digest];secret string digest]
  }

@testMakeToken[]
  $lToken[^self.sut.makeToken[$self.tokenData]]
  ^self.assertEq[$lToken;P1ZTatGuURqUh1d2wR461j8NArJI4IdCMu78AguVrF+cgMQ3yn3Z5LCGe1iGn9P1m3FIFsXHTM5CnjumBhmtlqY/QuF3MCLMGtCXz268dug9R5/8RI/tFaCiHboSpEQXNp/Ig0MPocBsccLkd2ONtNuR2I1m9EaZuHp/9SqwKqDsXhq5u9EULIOcezt99zKR]

@testParseAndValidateToken[]
  $lToken[P1ZTatGuURqUh1d2wR461j8NArJI4IdCMu78AguVrF+cgMQ3yn3Z5LCGe1iGn9P1m3FIFsXHTM5CnjumBhmtlqY/QuF3MCLMGtCXz268dug9R5/8RI/tFaCiHboSpEQXNp/Ig0MPocBsccLkd2ONtNuR2I1m9EaZuHp/9SqwKqDsXhq5u9EULIOcezt99zKR]
  ^self.assertEq[
    ^json:string[^self.sut.parseAndValidateToken[$lToken];$.indent(true)]
  ][
    ^json:string[$self.tokenData;$.indent(true)]
  ]

@testFailParseAndValidateToken[]
  $lToken[P1ZTatGuURqUh1d2wR461j8NArJI4IdCMu78AguVrF+cgMQ3yn3Z5LCGe1iGn9P1m3FIFsXHTM5CnjumBhmtlqY]
  ^self.assertRaises[security.invalid.token]{
    $lTokenData[^self.sut.parseAndValidateToken[$lToken]]
  }

#----------------------------------------------------------------------------------------------------------------------

@CLASS
TestMySQL57SecurityCrypt

@BASE
BaseTestSQLSecurity

@GET_connectString[]
  $result[$self._mysql57ConnectString]

@setUp[]
  ^BASE:setUp[]
# Включаем режим шифрования, совсместимый с Postgres
  ^self.connection.void{
    SET block_encryption_mode = 'aes-128-cbc';
  }

#----------------------------------------------------------------------------------------------------------------------

@CLASS
TestMySQL8SecurityCrypt

@BASE
BaseTestSQLSecurity

@GET_connectString[]
  $result[$self._mysql8ConnectString]

@setUp[]
  ^BASE:setUp[]
# Включаем режим шифрования, совсместимый с Postgres
  ^self.connection.void{
    SET block_encryption_mode = 'aes-128-cbc';
  }

#----------------------------------------------------------------------------------------------------------------------

@CLASS
TestPostgresSecurityCrypt

@BASE
BaseTestSQLSecurity

@GET_connectString[]
  $result[$self._postgresConnectString]
