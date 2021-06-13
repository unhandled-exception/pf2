# PF2 library

@USE
pf2/lib/common.p

@CLASS
pfSQLModelGenerator

## Базовый предок генераторов. Для каждого сервера надо написать наследника,
## реализующего методы _hasTable и _getFields.

@OPTIONS
locals

@BASE
pfClass

@create[aTableName;aOptions]
## aOptions.sql — объект соединения с БД
## aOptions.schema[] — схема в БД
## aOptions.classPrefix[] — префикс класса
  ^self.cleanMethodArgument[]
  ^self.assert(def $aOptions.sql)[Не задан объект для соединения к СУБД.]
  ^BASE:create[]

  $self._sql[$aOptions.sql]
  ^self.defReadProperty[CSQL;_sql]

  $self._schema[$aOptions.schema]
  $self._tableName[$aTableName]
  $self._classPrefix[$aOptions.classPrefix]

  ^if(^self._hasTable[]){
    ^throw[table.not.found]
  }

  $self._fields[^self._getFields[]]

@_hasTable[]
  ^throw[abstract.method]

@_getFields[aOptions]
  ^throw[abstract.method]

@_makeName[aName]
  $aName[^aName.lower[]]
  $result[^aName.match[_(\w)][g]{^match.1.upper[]}]
  $result[^result.match[Id^$][][ID]]
  $result[^result.match[Ip^$][][IP]]

@generate[aOptions]
  ^self.cleanMethodArgument[]
  $result[
  ^@USE
  pf2/lib/sql/models/structs.p

  ^@CLASS
  ^self._makeClassName[$self._tableName]

  ^@BASE
  pfModelTable

  ^@OPTIONS
  locals

  ^@create^[aOptions^]
  ## aOptions.tableName
    ^^BASE:create^[^^hash::create^[^$aOptions^]^if(def $self._schema){^#0A      ^$.schema[$self._schema]}
      ^$.tableName[^^ifdef[^$aOptions.tableName]{$self._tableName}]
  ^if(def $self._primary){#}    ^$.allAsTable(true)
    ^]

  ^self._classBody[]
  ]
  $result[^result.match[^^[ \t]{2}][gmx][]]
  $result[^result.match[(^^\s*^$){3,}][gmx][^#0A]]

@_makeClassName[aTableName]
  $lParts[^aTableName.split[_;lv]]
  $result[${self._classPrefix}^lParts.foreach[_;v]{^pfString:changeCase[$v.piece;first-upper]}]

@_classBody[]
$result[
    ^^self.addFields^[
      ^self._fields.foreach[k;v]{^$.$k^[^v.foreach[n;m]{^$.$n^if($m is bool){(^if($m){true}{false})}{^if($m is double){^($m^)}{^[$m^]}}}[ ]^]}[^#0A      ]
    ^]

  ^if(def $self._primary){
    ^$self._defaultOrderBy^[^$.${self._primary}[asc]]
  }

  ^if(^self._fields.contains[isActive] && def $self._primary){
  $lArgument[a^pfString:changeCase[$self._primary;first-upper]]
  ^@delete^[$lArgument^]
    ^$result^[^^self.modify^[^$$lArgument^;^$.isActive(false)^]^]

  ^@restore^[$lArgument^]
    ^$result^[^^self.modify^[^$$lArgument^;^$.isActive(true)^]^]
  }

  ^@cleanFormData[aFormData^;aOptions] -> [hash]
    ^^cleanMethodArgument[]
    ^$result[^^BASE:cleanFormData[^$aFormData]]

    ^self._fields.foreach[k;v]{^if($v.processor eq "bool" && $v.widget ne "none"){^$result.${k}[^^aFormData.${k}.bool(false)]}}[^#0A    ]
]

#--------------------------------------------------------------------------------------------------

@CLASS
pfMySQLTableModelGenerator

## Генерирует текст класса модели по DDL MySQL.

@OPTIONS
locals

@BASE
pfSQLModelGenerator

@create[aTableName;aOptions]
  ^self.cleanMethodArgument[]
  ^BASE:create[$aTableName;$aOptions]
  ^self.assert($CSQL.serverType eq "mysql")[Класс умеет получать описания таблиц только из MySQL.]

@_hasTable[]
  $result(
    !def $self._tableName
    || !^CSQL.table{show tables ^if(def $self._schema){from `^taint[$self._schema]`} like "^taint[$self._tableName]"}
  )

@_getFields[]
  $result[^hash::create[]]
  $lDDL[^CSQL.table{describe ^if(def $self._schema){`$self._schema`.}`$self._tableName`}]
  $lHasPrimary(^lDDL.select($lDDL.Key eq "PRI") == 1)
  $self._primary[]

  ^lDDL.menu{
    $lName[^self._makeName[$lDDL.Field]]
    $lData[^hash::create[]]

    ^if($lDDL.Field ne $lName){$lData.dbField[$lDDL.Field]}

    $lType[^self._parseType[$lDDL.Type]]
    ^switch[^lType.type.lower[]]{
      ^case[int;integer;smallint;mediumint]{
        $lData.processor[^if($lType.unsigned){uint}{int}]
        ^self.unsafe{$lData.default(^lDDL.Default.int[])}
      }
      ^case[tinyint]{
        $lData.processor[^if($lType.unsigned){uint}{int}]
        ^self.unsafe{$lData.default(^lDDL.Default.int[])}
        ^if(^lType.format.int(0) == 1
            || ^lDDL.Field.pos[is_] == 0){
          $lData.processor[bool]
          $lData.default(^lDDL.Default.bool(true))
        }
      }
      ^case[float;double;decimal;numeric]{
        $lData.processor[double]
        ^if(def $lType.format){
          $lData.format[^lType.format.match[^^(\d+)\,(\d+)^$][]{%${match.1}.${match.2}f}]
        }
        ^self.unsafe{$lData.default(^lDDL.Default.double[])}
      }
      ^case[date]{$lData.processor[date]}
      ^case[datetime]{$lData.processor[datetime]}
      ^case[time]{$lData.processor[time]}
      ^case[json]{$lData.processor[json]}
    }

    ^if($lDDL.Key eq "PRI" && $lHasPrimary){
      $lData.primary(true)
      $self._primary[$lName]
      ^if(!^lDDL.Extra.match[auto_increment][in]){
        $lData.sequence(false)
      }
      $lData.widget[none]
    }
    ^if(^lDDL.Field.match[_id^$][ni]){
      $lData.widget[none]
    }
    ^if($lName eq "createdAt"){
      $lData.processor[auto_now]
      $lData.skipOnUpdate(true)
      $lData.widget[none]
    }
    ^if($lName eq "updatedAt"){
      $lData.processor[auto_now]
      $lData.widget[none]
    }
    ^if($lName eq "isActive"){
      $lData.widget[none]
    }
    ^if(^lName.match[IP^$][n] || $lName eq "ip"){
      ^if(!def $lData.dbField){
        $lData.dbField[$lName]
      }
      $lData.processor[inet_ip]
      $lData.expression[inet_ntoa(^^_builder.quoteIdentifier[^$TABLE_ALIAS].^^_builder.quoteIdentifier[$lData.dbField])]
      $lData.fieldExpression[^^_builder.quoteIdentifier[^$TABLE_ALIAS].^^_builder.quoteIdentifier[$lData.dbField]]
    }

    ^if(!def $lData.widget){
      $lData.label[]
    }

    ^if(^lDDL.Extra.match[\bgenerated\b][in]){
      $lData.skipOnInsert(true)
      $lData.skipOnUpdate(true)
    }

    $result.[$lName][$lData]
  }

@_parseType[aTypeString]
  $aTypeString[^aTypeString.lower[]]
  $result[^hash::create[]]
  ^aTypeString.match[^^(\w+)(\(.+?\))?(.+)?][]{
    $result.type[$match.1]
    $result.format[^match.2.trim[both;()]]
    $result.options[$match.3]
    ^if(^result.options.match[unsigned][in]){
      $result.unsigned(true)
    }
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfPostgresTableModelGenerator

## Генерирует текст класса модели по DDL Постгреса.

@OPTIONS
locals

@BASE
pfSQLModelGenerator

@create[aTableName;aOptions]
  ^self.cleanMethodArgument[]
  ^BASE:create[$aTableName;$aOptions]
  ^self.assert($CSQL.serverType eq "pgsql" || $CSQL.serverType eq "postgresql")[Класс умеет получать описания таблиц только из Postgres.]

@_hasTable[]
  $result(
    !def $self._tableName
    || !^CSQL.int{
          select count(*)
            from information_schema.tables
           where table_schema = '^taint[^ifdef[$self._schema]{public}]'
                 and table_name = '^taint[$self._tableName]'
       }
  )

@_getFields[]
  $result[^hash::create[]]
  $lDDL[^CSQL.table{
      select cols.*,
             (case
                when
                  i.column_name is not null
                  and i.position_in_unique_constraint is null
                then 'PRI'
              end) as key
        from information_schema.columns as cols
   left join information_schema.key_column_usage as i using (table_schema, table_name, column_name)
       where cols.table_schema = '^taint[^ifdef[$self._schema]{public}]'
             and cols.table_name = '^taint[$self._tableName]'
    order by cols.ordinal_position asc
  }]

  $lHasPrimary(^lDDL.select($lDDL.key eq "PRI") == 1)
  $self._primary[]

  ^lDDL.menu{
    $lName[^self._makeName[$lDDL.column_name]]
    $lData[^hash::create[]]

    ^if($lDDL.column_name ne $lName){$lData.dbField[$lDDL.column_name]}

    $lType[^self._parseType[$lDDL.fields]]
    ^switch[^lType.type.lower[]]{
      ^case[int;integer;smallint]{
        $lData.processor[int]
        ^self.unsafe{$lData.default(^lType.default.int[])}
      }
      ^case[float;double;decimal;numeric]{
        $lData.processor[double]
        ^if(def $lType.numericScale){
          $lData.format[%.${lType.numericScale}f]
        }
        ^self.unsafe{$lData.default(^lDDL.default.double[])}
      }
      ^case[date]{$lData.processor[date]}
      ^case[timestamp]{$lData.processor[datetime]}
      ^case[time]{$lData.processor[time]}
      ^case[json;jsonb]{$lData.processor[json]}
    }

    ^if($lDDL.key eq "PRI" && $lHasPrimary){
      $lData.primary(true)
      $self._primary[$lName]
      ^if(
        !^lDDL.column_default.match[^^nextval][in]
        && (!^lDDL.fields.contains[identity_generation] || !^lDDL.identity_generation.match[(ALWAYS|BY DEFAULT)][in])
      ){
        $lData.sequence(false)
      }
      $lData.widget[none]
    }
    ^if(^lType.columnName.match[_id^$][ni]){
      $lData.widget[none]
    }
    ^if($lName eq "createdAt"){
      $lData.processor[auto_now]
      $lData.skipOnUpdate(true)
      $lData.widget[none]
    }
    ^if($lName eq "updatedAt"){
      $lData.processor[auto_now]
      $lData.widget[none]
    }
    ^if($lName eq "isActive"){
      $lData.widget[none]
    }
    ^if(^lType.columnName.match[^^(?:is_|can_).+]){
      $lData.processor[bool]
      ^if(def $lData.default){
        $lData.default(^lData.default.bool[])
      }
    }
    ^if(!def $lData.widget){
      $lData.label[]
    }

    $result.[$lName][$lData]
  }

@_parseType[aField]
  $result[^hash::create[]]
  $result.type[^aField.data_type.match[^^(\w+).*][]{$match.1}]
  $result.default[$aField.column_default]
  $result.columnName[$aField.column_name]
  $result.numericScale[$aField.numeric_scale]
