#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/sql/models/sql_table.p
pf2/lib/sql/models/generators/sql_table_generators.p
pf2/lib/sql/models/generators/model_form_generators.p

@main[][locals]
SQL orm generators test!

    $dbFile[assets/sql/orm_genertators.sqlite]
    $db[^pfSQLConnection::create[sqlite://${dbFile};
      $.enableQueriesLog(true)
      $.enableMemoryCache(true)
    ]]

    $users[^usersModel::create[$.sql[$db]]]

    $fg2[^pfTableFormGenerator::create[]]
    ^fg2.generate[$users]

    $fg3[^pfTableFormGenerator::create[$.widgets[^pfTableFormGeneratorBootstrap3Widgets::create[]]]]
    ^fg3.generate[$users]

Finish tests.^#0A


@CLASS
usersModel

@BASE
pfSQLTable

@create[aOptions]
  ^BASE:create[users;$aOptions]

  ^self.addFields[
    $.userID[$.dbField[id] $.processor[uint] $.primary(true)]
    $.name[]
    $.comment[$.widget[textarea]]
    $.typeID[$.dbField[type_id] $.processor[int] $.widget[radio]]
    $.uuid[]
    $.createdAt[$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true) $.widget[none]]
    $.createdAt[$.dbField[created_at] $.processor[auto_now] $.widget[none]]
  ]

  $self._defaultOrderBy[$.name[]]
