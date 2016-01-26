# PF2 library

@USE
pf2/lib/common.p

@CLASS
pfTableModelGenerator

## Генерирует текст класса модели по DDL.
## Класс умеет получать описания таблиц только из MySQL.

@BASE
pfClass

@create[aTableName;aOptions]
## aOptions.sql
## aOptions.schema
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aOptions.sql)[Не задан объект для соединения к СУБД.]
  ^pfAssert:isTrue($aOptions.sql.serverType eq "mysql")[Класс умеет получать описания таблиц только из MySQL.]
  ^BASE:create[]

  $_sql[$aOptions.sql]
  ^defReadProperty[CSQL;_sql]

  $_schema[$aOptions.schema]
  $_tableName[$aTableName]
  ^if(!def $_tableName || !^CSQL.table{show tables ^if(def $_schema){from `$_schema`} like "$_tableName"}){
    ^throw[table.not.found]
  }

  $_fields[^_getFields[]]

@_getFields[][locals]
  $result[^hash::create[]]
  $lDDL[^CSQL.table{describe ^if(def $_schema){`$_schema`.}`$_tableName`}]
  $lHasPrimary(^lDDL.select($lDDL.Key eq "PRI") == 1)
  $self._primary[]

  ^lDDL.menu{
    $lName[^_makeName[$lDDL.Field]]
    $lData[^hash::create[]]

    ^if($lDDL.Field ne $lName){$lData.dbField[$lDDL.Field]}

    $lType[^_parseType[$lDDL.Type]]
    ^switch[^lType.type.lower[]]{
      ^case[int;integer;smallint;mediumint]{
        $lData.processor[^if($lType.unsigned){uint}{int}]
        ^unsafe{$lData.default(^lDDL.Default.int[])}
      }
      ^case[tinyint]{
        $lData.processor[^if($lType.unsigned){uint}{int}]
        ^unsafe{$lData.default(^lDDL.Default.int[])}
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
        ^unsafe{$lData.default(^lDDL.Default.double[])}
      }
      ^case[date]{$lData.processor[date]}
      ^case[datetime]{$lData.processor[datetime]}
      ^case[time]{$lData.processor[time]}
    }

    ^if($lDDL.Key eq "PRI" && $lHasPrimary){
      $lData.primary(true)
      $self._primary[$lName]
      ^if(!^lDDL.Extra.match[auto_increment][in]){
        $lData.sequence(false)
      }
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

@_makeName[aName]
  $aName[^aName.lower[]]
  $result[^aName.match[_(\w)][g]{^match.1.upper[]}]
  $result[^result.match[Id^$][][ID]]
  $result[^result.match[Ip^$][][IP]]

@generate[aOptions]
  ^cleanMethodArgument[]
  $result[
  ^@CLASS
  ^_makeClassName[$_tableName]

  ^@USE
  pf2/lib/sql/models/structs.p

  ^@BASE
  pfModelTable

  ^@OPTIONS
  locals

  ^@create^[aOptions^]
  ## aOptions.tableName
    ^^BASE:create^[^^hash::create^[^$aOptions^]^if(def $_schema){^#0A      ^$.schema[$_schema]}
      ^$.tableName[^^ifdef[^$aOptions.tableName]{$_tableName}]
  ^if(def $_primary){#}    ^$.allAsTable(true)
    ^]

  ^_classBody[]
  ]
  $result[^result.match[^^[ \t]{2}][gmx][]]
  $result[^result.match[(^^\s*^$){3,}][gmx][^#0A]]

@_makeClassName[aTableName][locals]
  $lParts[^aTableName.split[_;lv]]
  $result[^lParts.foreach[_;v]{^pfString:changeCase[$v.piece;first-upper]}]

@_classBody[][locals]
$result[
    ^^self.addFields^[
      ^_fields.foreach[k;v]{^$.$k^[^v.foreach[n;m]{^$.$n^if($m is bool){(^if($m){true}{false})}{^if($m is double){^($m^)}{^[$m^]}}}[ ]^]}[^#0A      ]
    ^]

  ^if(def $_primary){
    ^$self._defaultOrderBy^[^$.${_primary}[asc]]
  }

  ^if(^_fields.contains[isActive] && def $_primary){
  $lArgument[a^pfString:changeCase[$_primary;first-upper]]
  ^@delete^[$lArgument^]
    ^$result^[^^self.modify^[^$$lArgument^;^$.isActive(false)^]^]

  ^@restore^[$lArgument^]
    ^$result^[^^self.modify^[^$$lArgument^;^$.isActive(true)^]^]
  }
]
