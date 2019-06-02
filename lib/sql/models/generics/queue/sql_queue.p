# PF2 library

@CLASS
pfSQLQueue

## Класс для работы с очередью в базе данных
## Требует поддержки семантики SELECT-FOR-UPDATE в СУБД
## На основе статьи Якова Сироткина — http://telamon.ru/articles/async.html

@OPTIONS
locals

@USE
pf2/lib/sql/models/sql_table.p

@BASE
pfSQLTable

@create[aTableName;aOptions]
## aOptions.defaultTaskType[0] — значение типа задачи по-умолчанию
## aOptions.interval(0.0) — интервал в минутах между попытками обработки задач.
##                          Если ноль, то используем 2 в степени attempt минут.
  ^BASE:create[$aTableName;$aOptions]

  $self._defaultResultType[table]

  ^self.addFields[
    $.taskID[$.dbField[task_id] $.plural[tasks] $.primary(true) $.widget[none]]
    $.taskType[$.dbField[task_type] $.default(^aOptions.defaultTaskType.int(0)) $.processor[uint] $.label[]]
    $.entityID[$.dbField[entity_id] $.plural[entities] $.processor[uint] $.label[]]
    $.processTime[$.dbField[process_time] $.processor[now] $.label[]]
    $.attempt[$.processor[uint] $.default(0) $.label[]]
    $.createdAt[$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true) $.widget[none]]
  ]

  $self._defaultOrderBy[$.taskID[asc]]

  $self._interval(^aOptions.interval.double(0.0))

@fetchOne[aOptions]
## Достает из базы ровно одну задачу
  $result[^self.fetch[^hash::create[$aOptions] $.limit(1) $.asHash(true)]]
  $result[^result._at[first]]

@fetch[aOptions]
## Достает из базы таблицу с задачами и сдвигает время очередной обработки.
## aOptions — параметры как для pfSQLTable.all
## aOptions.limit(1)
  ^self.cleanMethodArgument[]

  $lTail[^switch[$self.CSQL.serverType]{
    ^case[pgsql]{FOR UPDATE OF "$self.TABLE_NAME"}
    ^case[DEFAULT]{FOR UPDATE}
  }]

  ^self.CSQL.transaction{
    $lConds[^hash::create[$aOptions]]
    $result[^self.all[
      $lConds
      $.[processTime <][^date::now[]]
    ][
      $.tail[$lTail]
      $.force(true)
    ]]
    ^result.foreach[k;v]{
      ^self.modify[$v.taskID;
        $.attempt($v.attempt + 1)
        ^if($self._interval > 0){
          $.processTime[^date::create(^date::now[] + ($self._interval/1440))]
        }{
          $.processTime[^date::create(^date::now[] + ^math:pow(2;$v.attempt)/1440)]
        }
      ]
    }
  }

@accept[aTasks]
## Удаляет из очереди все обработанные задачи.
## aTasks[taskID|table|hash]
  $result[]
  ^BASE:deleteAll[
    $.tasks[$aTasks]
  ]
