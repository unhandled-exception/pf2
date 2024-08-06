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
  $lSQL[^pfSQLConnection::create[postgresql://]]
  $self.sut[^pfUsersModel::create[
    $.sql[$lSQL]
    $.cryptoProvider[^pfSQLSecurityCrypt::create[
      $.sql[$lSQL]
      $.secretKey[secret1]
    ]]
  ]]

@testDefaultAPR1[]
  $lPassword[password_1]
  $lHashed[^self.sut.makePasswordHash[$lPassword]]
  ^self.assertRegexpMatch[^^\^$apr1\^$\S{8}\^$\S{22}^$;$lHashed]
  ^self.assertEq[$lHashed;^self.sut.makePasswordHash[$lPassword;$lHashed]]

@testYescrypt[]
  $self.sut.passwordHashType[yescrypt]
  $lPassword[password_1]
  $lHashed[^self.sut.makePasswordHash[$lPassword]]
  ^self.assertRegexpMatch[^^\^$y\^$j9T\^$\S{16}\^$\S{32,}^$;$lHashed]
  ^self.assertEq[$lHashed;^self.sut.makePasswordHash[$lPassword;$lHashed]]

@testGostYescrypt[]
  $self.sut.passwordHashType[gost-yescrypt]
  $lPassword[password_1]
  $lHashed[^self.sut.makePasswordHash[$lPassword]]
  ^self.assertRegexpMatch[^^\^$gy\^$j9T\^$\S{16}\^$\S{32,}^$;$lHashed]
  ^self.assertEq[$lHashed;^self.sut.makePasswordHash[$lPassword;$lHashed]]
