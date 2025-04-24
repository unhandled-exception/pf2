@USE
pf2/lib/web/auth.p
pf2/lib/sql/connection.p

@CLASS
TestAuthPasswordHashes

@OPTIONS
locals

@BASE
pfTestCase

@setUp[]
  $self.sql[^pfSQLConnection::create[postgresql://]]
  $self.sut[^pfUsersModel::create[
    $.sql[$self.sql]
    $.cryptoProvider[^pfSQLSecurityCrypt::create[
      $.sql[$self.sql]
      $.secretKey[secret1]
    ]]
  ]]

@testDefaultAPR1[]
  $lPassword[password_1]
  $lHashed[^self.sut.makePasswordHash[$lPassword]]
  ^self.assertRegexpMatch[^^\^$apr1\^$\S{8}\^$\S{22}^$;$lHashed]
  ^self.assertEq[$lHashed;^self.sut.makePasswordHash[$lPassword;$lHashed]]

@testYescrypt[]
  ^if(!^env:PARSER_VERSION.match[linux][in]){
    ^self.skipTest[]
  }

  $self.sut.passwordHashType[yescrypt]
  $lPassword[password_1]
  $lHashed[^self.sut.makePasswordHash[$lPassword]]
  ^self.assertRegexpMatch[^^\^$y\^$j9T\^$\S{16}\^$\S{32,}^$;$lHashed]
  ^self.assertEq[$lHashed;^self.sut.makePasswordHash[$lPassword;$lHashed]]

@testGostYescrypt[]
  ^if(!^env:PARSER_VERSION.match[linux][in]){
    ^self.skipTest[]
  }

  $self.sut.passwordHashType[gost-yescrypt]
  $lPassword[password_1]
  $lHashed[^self.sut.makePasswordHash[$lPassword]]
  ^self.assertRegexpMatch[^^\^$gy\^$j9T\^$\S{16}\^$\S{32,}^$;$lHashed]
  ^self.assertEq[$lHashed;^self.sut.makePasswordHash[$lPassword;$lHashed]]

@testDisabledTrimPassword[]
  $lPassword[  password_1   ^#0A]
  $lSalt[^$apr1^$12345678^$]
  ^self.assertNe[^self.sut.makePasswordHash[$lPassword;$lSalt];^self.sut.makePasswordHash[^lPassword.trim[];$lSalt]]

@testTrimPassword[]
  $self.sut[^pfUsersModel::create[
    $.sql[$self.sql]
    $.cryptoProvider[^pfSQLSecurityCrypt::create[
      $.sql[$self.sql]
      $.secretKey[secret1]
    ]]
    $.trimPassword(true)
  ]]

  $lPassword[  password_1   ^#0A]
  $lSalt[^$apr1^$12345678^$]
  ^self.assertEq[^self.sut.makePasswordHash[$lPassword;$lSalt];^self.sut.makePasswordHash[^lPassword.trim[];$lSalt]]
