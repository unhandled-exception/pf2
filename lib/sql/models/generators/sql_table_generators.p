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
  $result[^aName.match[_(\w)][g']{^if(def $match.prematch){^match.1.upper[]}{$match.match}}]
  $result[^result.match[Id^$][][ID]]
  $result[^result.match[Ip^$][][IP]]
  $result[^result.match[Uuid^$][][UUID]]
  $result[^result.match[Guid^$][][GUID]]
  $result[^result.match[Uan^$][][UAN]]

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

  $result[^result.trim[start]]
  $result[^result.match[^^[ \t]{2}][gm][]]
  $result[^result.match[^^\s*^$][gm][^#0A]]
  $result[^result.match[\n{3,}][g][^#0A^#0A]]
  $result[^result.match[\n*?^$][][^#0A]]

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

@_fetchDDL[]
  $result[^CSQL.table{
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

@_getFields[]
  $result[^hash::create[]]
  $lDDL[^self._fetchDDL[]]

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
      ^case[uuid]{
        $lData.processor[uuid]
        $lData.widget[none]
      }
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

    ^if($lDDL.is_generated eq "ALWAYS"){
      $lData.skipOnInsert(true)
      $lData.skipOnUpdate(true)
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
    ^if(^lType.columnName.match[^^(?:is_|can_|has_).+] || ^lType.columnName.match[(?:_enabled|_required)^$]){
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

#--------------------------------------------------------------------------------------------------

@CLASS
pfPostgres18MatviewISTableModelGenerator

## Генерирует текст класса модели по DDL Постгреса.
##
## Постгрес не хочет добавлять собственны материализованные представления в инфомрационную схему — нет в стандарте.
## Поэтому делаем хак. Берем код вьюх инфосхемы из 18 Постгреса и добавляем матвьюхи :)

@OPTIONS
locals

@BASE
pfPostgresTableModelGenerator

@create[aTableName;aOptions]
  ^BASE:create[$aTableName;$aOptions]

@_hasTable[]
  $result(
    !def $self._tableName
    || !^CSQL.int{
       select count(*)
         from pg_catalog.pg_class c
              left join pg_catalog.pg_namespace n on n.oid = c.relnamespace
         where c.relname = '^taint[$self._tableName]'
               and n.nspname = '^taint[^ifdef[$self._schema]{public}]'
               and pg_catalog.pg_table_is_visible(c.oid)
               and c.relkind = ANY (ARRAY['r'::"char", 'v'::"char", 'f'::"char", 'p'::"char", 'm'::"char"])
       }
  )

@_fetchDDL[]
  $result[^CSQL.table{
  with cols as (
      SELECT current_database()::information_schema.sql_identifier AS table_catalog,
          nc.nspname::information_schema.sql_identifier AS table_schema,
          c.relname::information_schema.sql_identifier AS table_name,
          a.attname::information_schema.sql_identifier AS column_name,
          a.attnum::information_schema.cardinal_number AS ordinal_position,
              CASE
                  WHEN a.attgenerated = ''::"char" THEN pg_get_expr(ad.adbin, ad.adrelid)
                  ELSE NULL::text
              END::information_schema.character_data AS column_default,
              CASE
                  WHEN a.attnotnull OR t.typtype = 'd'::"char" AND t.typnotnull THEN 'NO'::text
                  ELSE 'YES'::text
              END::information_schema.yes_or_no AS is_nullable,
              CASE
                  WHEN t.typtype = 'd'::"char" THEN
                  CASE
                      WHEN bt.typelem <> 0::oid AND bt.typlen = '-1'::integer THEN 'ARRAY'::text
                      WHEN nbt.nspname = 'pg_catalog'::name THEN format_type(t.typbasetype, NULL::integer)
                      ELSE 'USER-DEFINED'::text
                  END
                  ELSE
                  CASE
                      WHEN t.typelem <> 0::oid AND t.typlen = '-1'::integer THEN 'ARRAY'::text
                      WHEN nt.nspname = 'pg_catalog'::name THEN format_type(a.atttypid, NULL::integer)
                      ELSE 'USER-DEFINED'::text
                  END
              END::information_schema.character_data AS data_type,
          information_schema._pg_char_max_length(information_schema._pg_truetypid(a.*, t.*), information_schema._pg_truetypmod(a.*, t.*))::information_schema.cardinal_number AS character_maximum_length,
          information_schema._pg_char_octet_length(information_schema._pg_truetypid(a.*, t.*), information_schema._pg_truetypmod(a.*, t.*))::information_schema.cardinal_number AS character_octet_length,
          information_schema._pg_numeric_precision(information_schema._pg_truetypid(a.*, t.*), information_schema._pg_truetypmod(a.*, t.*))::information_schema.cardinal_number AS numeric_precision,
          information_schema._pg_numeric_precision_radix(information_schema._pg_truetypid(a.*, t.*), information_schema._pg_truetypmod(a.*, t.*))::information_schema.cardinal_number AS numeric_precision_radix,
          information_schema._pg_numeric_scale(information_schema._pg_truetypid(a.*, t.*), information_schema._pg_truetypmod(a.*, t.*))::information_schema.cardinal_number AS numeric_scale,
          information_schema._pg_datetime_precision(information_schema._pg_truetypid(a.*, t.*), information_schema._pg_truetypmod(a.*, t.*))::information_schema.cardinal_number AS datetime_precision,
          information_schema._pg_interval_type(information_schema._pg_truetypid(a.*, t.*), information_schema._pg_truetypmod(a.*, t.*))::information_schema.character_data AS interval_type,
          NULL::integer::information_schema.cardinal_number AS interval_precision,
          NULL::name::information_schema.sql_identifier AS character_set_catalog,
          NULL::name::information_schema.sql_identifier AS character_set_schema,
          NULL::name::information_schema.sql_identifier AS character_set_name,
              CASE
                  WHEN nco.nspname IS NOT NULL THEN current_database()
                  ELSE NULL::name
              END::information_schema.sql_identifier AS collation_catalog,
          nco.nspname::information_schema.sql_identifier AS collation_schema,
          co.collname::information_schema.sql_identifier AS collation_name,
              CASE
                  WHEN t.typtype = 'd'::"char" THEN current_database()
                  ELSE NULL::name
              END::information_schema.sql_identifier AS domain_catalog,
              CASE
                  WHEN t.typtype = 'd'::"char" THEN nt.nspname
                  ELSE NULL::name
              END::information_schema.sql_identifier AS domain_schema,
              CASE
                  WHEN t.typtype = 'd'::"char" THEN t.typname
                  ELSE NULL::name
              END::information_schema.sql_identifier AS domain_name,
          current_database()::information_schema.sql_identifier AS udt_catalog,
          COALESCE(nbt.nspname, nt.nspname)::information_schema.sql_identifier AS udt_schema,
          COALESCE(bt.typname, t.typname)::information_schema.sql_identifier AS udt_name,
          NULL::name::information_schema.sql_identifier AS scope_catalog,
          NULL::name::information_schema.sql_identifier AS scope_schema,
          NULL::name::information_schema.sql_identifier AS scope_name,
          NULL::integer::information_schema.cardinal_number AS maximum_cardinality,
          a.attnum::information_schema.sql_identifier AS dtd_identifier,
          'NO'::character varying::information_schema.yes_or_no AS is_self_referencing,
              CASE
                  WHEN a.attidentity = ANY (ARRAY['a'::"char", 'd'::"char"]) THEN 'YES'::text
                  ELSE 'NO'::text
              END::information_schema.yes_or_no AS is_identity,
              CASE a.attidentity
                  WHEN 'a'::"char" THEN 'ALWAYS'::text
                  WHEN 'd'::"char" THEN 'BY DEFAULT'::text
                  ELSE NULL::text
              END::information_schema.character_data AS identity_generation,
          seq.seqstart::information_schema.character_data AS identity_start,
          seq.seqincrement::information_schema.character_data AS identity_increment,
          seq.seqmax::information_schema.character_data AS identity_maximum,
          seq.seqmin::information_schema.character_data AS identity_minimum,
              CASE
                  WHEN seq.seqcycle THEN 'YES'::text
                  ELSE 'NO'::text
              END::information_schema.yes_or_no AS identity_cycle,
              CASE
                  WHEN a.attgenerated <> ''::"char" THEN 'ALWAYS'::text
                  ELSE 'NEVER'::text
              END::information_schema.character_data AS is_generated,
              CASE
                  WHEN a.attgenerated <> ''::"char" THEN pg_get_expr(ad.adbin, ad.adrelid)
                  ELSE NULL::text
              END::information_schema.character_data AS generation_expression,
              CASE
                  WHEN (c.relkind = ANY (ARRAY['r'::"char", 'p'::"char"])) OR (c.relkind = ANY (ARRAY['v'::"char", 'f'::"char"])) AND pg_column_is_updatable(c.oid::regclass, a.attnum, false) THEN 'YES'::text
                  ELSE 'NO'::text
              END::information_schema.yes_or_no AS is_updatable
        FROM pg_attribute a
          LEFT JOIN pg_attrdef ad ON a.attrelid = ad.adrelid AND a.attnum = ad.adnum
          JOIN (pg_class c
          JOIN pg_namespace nc ON c.relnamespace = nc.oid) ON a.attrelid = c.oid
          JOIN (pg_type t
          JOIN pg_namespace nt ON t.typnamespace = nt.oid) ON a.atttypid = t.oid
          LEFT JOIN (pg_type bt
          JOIN pg_namespace nbt ON bt.typnamespace = nbt.oid) ON t.typtype = 'd'::"char" AND t.typbasetype = bt.oid
          LEFT JOIN (pg_collation co
          JOIN pg_namespace nco ON co.collnamespace = nco.oid) ON a.attcollation = co.oid AND (nco.nspname <> 'pg_catalog'::name OR co.collname <> 'default'::name)
          LEFT JOIN (pg_depend dep
          JOIN pg_sequence seq ON dep.classid = 'pg_class'::regclass::oid AND dep.objid = seq.seqrelid AND dep.deptype = 'i'::"char") ON dep.refclassid = 'pg_class'::regclass::oid AND dep.refobjid = c.oid AND dep.refobjsubid = a.attnum
        WHERE NOT pg_is_other_temp_schema(nc.oid) AND a.attnum > 0 AND NOT a.attisdropped
              AND (c.relkind = ANY (ARRAY['r'::"char", 'v'::"char", 'f'::"char", 'p'::"char", 'm'::"char"]))
              AND (pg_has_role(c.relowner, 'USAGE'::text) OR has_column_privilege(c.oid, a.attnum, 'SELECT, INSERT, UPDATE, REFERENCES'::text))
        ),
        i as (
          SELECT current_database()::information_schema.sql_identifier AS constraint_catalog,
              ss.nc_nspname::information_schema.sql_identifier AS constraint_schema,
              ss.conname::information_schema.sql_identifier AS constraint_name,
              current_database()::information_schema.sql_identifier AS table_catalog,
              ss.nr_nspname::information_schema.sql_identifier AS table_schema,
              ss.relname::information_schema.sql_identifier AS table_name,
              a.attname::information_schema.sql_identifier AS column_name,
              (ss.x).n::information_schema.cardinal_number AS ordinal_position,
                  CASE
                      WHEN ss.contype = 'f'::"char" THEN information_schema._pg_index_position(ss.conindid, ss.confkey[(ss.x).n])
                      ELSE NULL::integer
                  END::information_schema.cardinal_number AS position_in_unique_constraint
            FROM pg_attribute a,
              ( SELECT r.oid AS roid,
                      r.relname,
                      r.relowner,
                      nc.nspname AS nc_nspname,
                      nr.nspname AS nr_nspname,
                      c.oid AS coid,
                      c.conname,
                      c.contype,
                      c.conindid,
                      c.confkey,
                      c.confrelid,
                      information_schema._pg_expandarray(c.conkey) AS x
                    FROM pg_namespace nr,
                      pg_class r,
                      pg_namespace nc,
                      pg_constraint c
                    WHERE nr.oid = r.relnamespace AND r.oid = c.conrelid AND nc.oid = c.connamespace
                         AND (c.contype = ANY (ARRAY['p'::"char", 'u'::"char", 'f'::"char"]))
                         AND (r.relkind = ANY (ARRAY['r'::"char", 'p'::"char", 'm'::"char"]))
                         AND NOT pg_is_other_temp_schema(nr.oid)) ss
            WHERE ss.roid = a.attrelid AND a.attnum = (ss.x).x AND NOT a.attisdropped AND (pg_has_role(ss.relowner, 'USAGE'::text)
                  OR has_column_privilege(ss.roid, a.attnum, 'SELECT, INSERT, UPDATE, REFERENCES'::text))
        )
            select cols.*,
                  (case
                      when
                        i.column_name is not null
                        and i.position_in_unique_constraint is null
                      then 'PRI'
                    end) as key
              from cols
        left join i using (table_schema, table_name, column_name)
            where cols.table_schema = '^taint[^ifdef[$self._schema]{public}]'
                  and cols.table_name = '^taint[$self._tableName]'
          order by cols.ordinal_position asc
  }]
