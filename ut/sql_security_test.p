@USE
pf2/lib/sql/connection.p
pf2/lib/security/sql_security.p

@CLASS
BaseTestSQLSecurity

@OPTIONS
locals

@BASE
pfTestCase

@setUp[]
#   $self.connectString[] Set in child
  $self.connection[^pfSQLConnection::create[$self.connectString;
    $.enableQueriesLog(true)
    $.enableMemoryCache(true)
  ]]
  $self.sut[^pfSQLSecurityCrypt::create[
    $.sql[$self.connection]
    $.secretKey[SECRET_KEY]
  ]]

@testBase64Encrypt[]
  $lEncrypted[^self.sut.encrypt[secret data;
    $.serializer[base64]
  ]]
  ^self.assertEq[$lEncrypted;Mmca6DkRsKxPZXAnCgOglA==]

#----------------------------------------------------------------------------------------------------------------------

@CLASS
TestMySQLSecurityCrypt

@BASE
BaseTestSQLSecurity

@setUp[]
  $self.connectString[mysql://test:test@127.0.0.1:8306/mysql_test]
  ^BASE:setUp[]

#----------------------------------------------------------------------------------------------------------------------

@CLASS
TestPostgresSecurityCrypt

@BASE
BaseTestSQLSecurity

@setUp[]
  $self.connectString[postgresql://test:test@127.0.0.1:8432/pg_test]
  ^BASE:setUp[]
