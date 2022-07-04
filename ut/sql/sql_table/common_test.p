@USE
pf2/lib/sql/connection.p
pf2/lib/sql/models/sql_table.p

@CLASS
TestPFSQLTableFields

@OPTIONS
locals

@BASE
pfTestCase

@GET_connectString[]
  $result[sqlite://:memory:]

@setUp[]
  $self.connection[^pfSQLConnection::create[$self.connectString;
    $.enableQueriesLog(true)
    $.enableMemoryCache(true)
  ]]
  $self.sut[^pfSQLTable::create[test_table;
    $.sql[$self.connection]
  ]]

@test_add_simple_field[]
  ^self.sut.addField[test_field][
    $.plural[test_fields]
    $.processor[null]
    $.default[test_def_value]
    $.format[#.###]
    $.comment[Test field]
    $.widget[none]
  ]
  ^self.assertHashEquals[
    $sut.FIELDS.[test_field]
  ][
    $.name[test_field]
    $.plural[test_fields]
    $.processor[null]
    $.default[test_def_value]
    $.format[#.###]
    $.label[test_field]
    $.comment[Test field]
    $.widget[none]
    $.dbField[test_field]
    $.primary(false)
    $.sequence(false)
  ]

@test_has_field[]
  ^self.sut.addFields[
    $.id[]
    $.name[]
    $.fullName[]
  ]
  ^self.assertTrue(^sut.hasField[name])
  ^self.assertFalse(^sut.hasField[comment])

@test_remove_field[]
  ^self.sut.addFields[
    $.id[]
    $.name[]
    $.fullName[]
  ]
  ^sut.removeField[name]
  ^self.assertFalse(^sut.hasField[name])

@test_add_fields_groups[]
  ^self.sut.addFields[
    $.id[$.groups[full, base, short]]
    $.login[$.groups[full, base, short]]
    $.name[$.groups[full, base]]
    $.comment[$.groups[full]]
    $.createdAt[]
  ]

  ^self.assertHashEquals[
    $sut.FIELDS_GROUPS
  ][
    $.full[$.id(true) $.login(true) $.name(true) $.comment(true)]
    $.short[$.id(true) $.login(true)]
    $.base[$.id(true) $.login(true) $.name(true)]
  ]
