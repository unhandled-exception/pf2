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

@test_add_primary_field_not_first[]
  ^self.sut.addFields[
    $.name[]
    $.fullName[$.primary(false)]
    $.id[$.primary(true)]
  ]

  ^self.assertEq["test_table"."id";$sut.PRIMARYKEY]

@test_sql_field_name[]
  ^self.sut.addFields[
    $.simple[]
    $.dbField[$.dbField[db_field]]
    $.exField[$.expression[sum(db_field_1)]]
    $.exDBField[$.expression[max(db_field_2)] $.dbField[db_field_2]]
    $.fexField[$.expression[min(db_field_3)] $.fieldExpression[db_field_3]]
  ]

  ^self.assertEq[^sut.sqlFieldName[simple];"test_table"."simple"]
  ^self.assertEq[^sut.sqlFieldName[dbField];"test_table"."db_field"]
  ^self.assertEq[^sut.sqlFieldName[exField];sum(db_field_1)]
  ^self.assertEq[^sut.sqlFieldName[exDBField];max(db_field_2)]
  ^self.assertEq[^sut.sqlFieldName[fexField];min(db_field_3)]

  ^self.sut.asContext[group]{
    ^self.assertEq[^sut.sqlFieldName[simple];"test_table"."simple"]
    ^self.assertEq[^sut.sqlFieldName[dbField];"test_table"."db_field"]
    ^self.assertEq[^sut.sqlFieldName[exField];"exField"]
    ^self.assertEq[^sut.sqlFieldName[exDBField];"exDBField"]
    ^self.assertEq[^sut.sqlFieldName[fexField];"fexField"]
  }

  ^self.sut.asContext[where]{
    ^self.assertEq[^sut.sqlFieldName[simple];"test_table"."simple"]
    ^self.assertEq[^sut.sqlFieldName[dbField];"test_table"."db_field"]
    ^self.assertEq[^sut.sqlFieldName[exField];sum(db_field_1)]
    ^self.assertEq[^sut.sqlFieldName[exDBField];max(db_field_2)]
    ^self.assertEq[^sut.sqlFieldName[fexField];db_field_3]
  }

  ^self.sut.asContext[update]{
    ^self.assertEq[^sut.sqlFieldName[simple];"simple"]
    ^self.assertEq[^sut.sqlFieldName[dbField];"db_field"]
    ^self.assertEq[^sut.sqlFieldName[exField];sum(db_field_1)]
    ^self.assertEq[^sut.sqlFieldName[exDBField];"db_field_2"]
    ^self.assertEq[^sut.sqlFieldName[fexField];db_field_3]
  }

  ^self.assertRaises[assert.fail]{
    ^sut.sqlFieldName[unexistant]
  }

@test_sql_json_processors[]
  ^self.sut.addFields[
    $.j1[$.processor[json]]
    $.j2[$.processor[json_null]]
    $.j3[$.processor[json_not_null]]
  ]

  ^self.assertEq[^self.sut.fieldValue[j1;];NULL]
  ^self.assertEq[^self.sut.fieldValue[j1;value];'"value"']
  ^self.assertEq[^self.sut.fieldValue[j1;^hash::create[]];'{}']
  ^self.assertEq[^self.sut.fieldValue[j1;$.k1[v1] $.k2[v2]];'{ "k1":"v1", "k2":"v2" }']

  ^self.assertEq[^self.sut.fieldValue[j2;];NULL]
  ^self.assertEq[^self.sut.fieldValue[j2;value];'"value"']
  ^self.assertEq[^self.sut.fieldValue[j2;^hash::create[]];'{}']
  ^self.assertEq[^self.sut.fieldValue[j2;$.k1[v1] $.k2[v2]];'{ "k1":"v1", "k2":"v2" }']

  ^self.assertEq[^self.sut.fieldValue[j3;];'{}']
  ^self.assertEq[^self.sut.fieldValue[j3;value];'"value"']
  ^self.assertEq[^self.sut.fieldValue[j3;^hash::create[]];'{}']
  ^self.assertEq[^self.sut.fieldValue[j3;$.k1[v1] $.k2[v2]];'{ "k1":"v1", "k2":"v2" }']
