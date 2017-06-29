@USE
pf2/lib/console/console_app.p
pf2/lib/sql/models/structs.p

@CLASS
pfPgSQLCommand

## Команда для работы с Постгресом.

@OPTIONS
locals

@BASE
pfConsoleCommandWithSubcommands

@auto[aFilespec]
  $self.SQL_COMMAND_ROOT[^file:dirname[$aFilespec]]
  $self.SQL_COMMAND_BIN[^self.SQL_COMMAND_ROOT.match[^^(?:^taint[regex][$request:document-root])(.+?)^$][]{$match.1/bin}]

@create[aOptions]
## aOptions.sql — ссылка на класс соединение с БД.
## aOptions.rootPath[$request:document-root] — рутовая папка от которой пишем файлы
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]
  ^pfModelChainMixin:mixin[$self;$aOptions]

  $self.help[A Postgres management command.]

  $self._binPath[$self.SQL_COMMAND_BIN]
  $self._pgdumpBin[$self._binPath/pg_dump]
  $self._rootPath[^self.ifdef[$aOptions.rootPath]{$request:document-root}]

  $self._settings[^self._parseConnectString[$self.CSQL.connectString]]
  ^pfAssert:isTrue($self._settings){"$self.CSQL.connectString" is an invalid connect string.}

  ^self.assignSubcommand[dump file_name.sql [--gzip|--bzip2] [--tables=t1,tp*] [--ignore=t1,tp*] [--only-data] [--no-owner] [--clean] [--no-acl];$dump][
    $.help[Dump data to file.]
  ]
  ^self.assignSubcommand[schema [file_name] [--no-owner] [--clean] [--no-acl];$schema;
    $.help[Dump a database schema.]
  ]
    ^self.assignSubcommand[table_schema table_name;$table_schema;
    $.help[Dump a clean table schema.]
  ]
  ^self.assignSubcommand[settings;$settings][
    $.help[Show connection settings.]
  ]
  ^self.assignSubcommand[tables [prefix];$tables][
    $.help[Show schemas tables.]
  ]
  ^self.assignSubcommand[psql_shell_command;$psql_shell_command;
    $.help[Make a postgres shell command.]
  ]
  ^self.assignSubcommand[vacuum [prefix];$vacuum;
    $.help[Run a VACUUM ANALYZE command.]
  ]

  $self._maxHelpSubcommandLength(18)

@dump[aArgs;aSwitches]
## aArgs.1 — имя файда с дампом
## aSwitches.gzip
## aSwitches.bzip2
## aSwitches.tables[table1,table2]
## aSwitches.ignore[table3,table4]
## aSwitches.only-data
## aSwitches.no-owner — убрать владльца из схемы
## aSwitches.clean — выдать команды на очистку базы
## aSwitches.no-acl — не выдавать grant/revoke-команды.
  $lFile[^aArgs.1.trim[]]
  ^if(def $lFile){
    $lOptions[^self._defaultPsqlOptions[]]

    ^if(^aSwitches.contains[only-data]){
      ^lOptions.append{--data-only}
    }{
      ^if(^aSwitches.contains[no-owner]){
        ^lOptions.append{--no-owner}
      }

      ^if(^aSwitches.contains[clean]){
        ^lOptions.append{--clean}
      }

      ^if(^aSwitches.contains[no-acl]){
        ^lOptions.append{--no-acl}
      }
    }

    ^if(^aSwitches.contains[tables]){
      $lTables[^aSwitches.tables.trim[both;"]]
      $lTables[^lTables.split[,;lv]]
      ^lTables.foreach[_;v]{
        ^lOptions.append{--table=^v.piece.trim[]}
      }
    }

    ^if(^aSwitches.contains[ignore]){
      $lTables[^aSwitches.ignore.trim[both;"]]
      $lTables[^lTables.split[,;lv]]
      ^lTables.foreach[_;v]{
        ^lOptions.append{--exclude-table=^v.piece.trim[]}
      }
    }


    $lEnv[^hash::create[]]
    $lEnv.CGI_MANAGE_PGSQL_DUMP_FILE[^if(^lFile.left(1) ne "/"){$self._rootPath/$lFile}{$lFile}]
    ^if(^aSwitches.contains[gzip]){
      $lEnv.CGI_MANAGE_PGSQL_DUMP_ARCHIVER[gzip]
    }(^aSwitches.contains[bzip2]){
      $lEnv.CGI_MANAGE_PGSQL_DUMP_ARCHIVER[bzip2]
    }

    $lPgdump[^file::exec[$self._pgdumpBin;$lEnv;$lOptions]]
    ^if($lPgdump.status == 0){

      $lNow[^date::now[]]
      ^self.print[Database have dumped to file $lFile at ^lNow.iso-string[].]
    }{
       ^self.print[Error $lPgdump.status: $lPgdump.stderr]
     }
  }{
     ^self.usage[]
   }

@schema[aArgs;aSwitches]
## aArgs.1 — имя файла
## aSwitches.no-owner — убрать владльца из схемы
## aSwitches.clean — выдать команды на очистку базы
## aSwitches.no-acl — не выдавать grant/revoke-команды.
  $lOptions[^self._defaultPsqlOptions[]]
  ^lOptions.append{--schema-only}

  ^if(^aSwitches.contains[no-owner]){
    ^lOptions.append{--no-owner}
  }

  ^if(^aSwitches.contains[clean]){
    ^lOptions.append{--clean}
  }

  ^if(^aSwitches.contains[no-acl]){
    ^lOptions.append{--no-acl}
  }

  $lFile[^aArgs.1.trim[]]
  $lPgdump[^file::exec[$self._pgdumpBin;$lEnv;$lOptions]]
  ^if($lPgdump.status == 0){
    $lSchemaDump[$lPgdump.text]
    ^if(def $lFile){
      ^lSchemaDump.save[$lFile]
    }{
       ^self.print[$lSchemaDump]
     }
  }{
    ^self.print[Error $lPgdump.status: $lPgdump.stderr]
  }

@table_schema[aArgs;aSwitches]
## aArgs.1 — имя таблицы
  ^if(!def $aArgs.1){
    ^self.usage[]
    ^return[]
  }

  $lOptions[^self._defaultPsqlOptions[]]
  ^lOptions.append{--schema-only}
  ^lOptions.append{--no-acl}
  ^lOptions.append{--no-owner}

  ^if(!^self.CSQL.int{
      select count(*)
        from information_schema.tables
       where table_schema not in ('pg_catalog', 'information_schema')
             and table_name = '^taint[$aArgs.1]'
  }){
    ^self.print[Table "$aArgs.1" not found.]
    ^return[]
  }
  ^lOptions.append{-t}
  ^lOptions.append{$aArgs.1}

  $lPgdump[^file::exec[$self._pgdumpBin;$lEnv;$lOptions]]
  ^if($lPgdump.status == 0){
    $lSchemaDump[$lPgdump.text]

#   Отрезаем комментарии и лишние команды SET, удаляем пустые строки
    $lSchemaDump[^lSchemaDump.match[^^(?:--|SET)\s.*^$][gm][]]
    $lSchemaDump[^lSchemaDump.match[\n{2,}][g][^#0A^#0A]]
    $lSchemaDump[^lSchemaDump.match[^^\s+][][]]

    ^self.print[$lSchemaDump]
  }{
    ^self.print[Error $lPgdump.status: $lPgdump.stderr]
  }

@settings[aArgs;aSwitches]
  ^self.print[SQL settings]
  ^self._settings.foreach[k;v]{
    ^self.print[${k}: ^self.ifdef[$v]{—};$.start[  ]]
  }

@tables[aArgs;aSwitches]
## aArgs.1 — префикс таблиц
  $lPrefix[^aArgs.1.trim[]]
  $lTables[^self.CSQL.hash{
    select table_name,
           table_catalog,
           table_schema
      from information_schema.tables
     where table_schema not in ('pg_catalog', 'information_schema')
           ^if(def $aArgs.1){
             and table_name like '^taint[$aArgs.1]%'
           }
     order by table_schema, table_name
  }]
  ^if($lTables){
    ^self.print[Found ^lTables._count[] tables^if(def $lPrefix){ starts with "$lPrefix"}:]
    ^lTables.foreach[name;v]{
      ^self.print[— ^if($v.table_schema ne "public"){${v.table_schema}.}$name]
    }
  }{
     ^self.print[Tables not found.]
   }

@psql_shell_command[aArgs;aSwitches]
  $lOptions[^self._defaultPsqlOptions[]]
  ^lOptions.append{--set}
  ^lOptions.append{PROMPT1=%n@%M:%>/%/%R%#%x}
  ^lOptions.append{--pset}
  ^lOptions.append{pager=off}
  ^self.print[psql ^lOptions.foreach[_;v]{$v.opt}[ ]]

@vacuum[aArgs;aSwitches]
  $lTables[^self.CSQL.hash{
    select table_name,
           table_catalog,
           table_schema
      from information_schema.tables
     where table_schema not in ('pg_catalog', 'information_schema')
           ^if(def $aArgs.1){
             and table_name like '^taint[$aArgs.1]%'
           }
     order by table_schema, table_name
  }]
  ^self.print[Vacuum and analyze tables:]
  ^lTables.foreach[t;v]{
    ^self.print[— ${v.table_schema}.${t}]
    ^CSQL.void{VACUUM ANALYZE "^taint[${v.table_schema}]"."^taint[${t}]"}
  }
  ^self.print[Done.]

@_parseConnectString[aConnectString] -> [hash]
  $result[^hash::create[]]
  $lParsed[^aConnectString.match[
    ^^(pgsql)://                # 1 - protocol
      (?:(.+?)(?:\:(.*))?)?     # 2 - user, 3 - password
      @(.*?)                    # 4 - host
      (?:\/(.+?))?              # 5 - database
      (?:\?(.*))?               # 6 - options
    ^$
  ][x]]
  ^if($lParsed){
    $result.connectString[$aConnectString]
    $result.protocol[$lParsed.1]

    ^if(def $lParsed.4){
      $result.host[$lParsed.4]
      $lColonPos(^result.host.pos[:])
      ^if($lColonPos >= 0){
        $result.port[^result.host.mid($lColonPos + 1)]
        $result.host[^result.host.left($lColonPos)]
      }
    }

    $result.database[$lParsed.5]
    $result.user[$lParsed.2]
    $result.password[$lParsed.3]

    $result.options[$lParsed.6]
  }

@_defaultPsqlOptions[] -> [table<opt>]
  $lOptions[^table::create{opt}]

# postgresql://[user[:password]@][netloc][:port][/dbname][?param1=value1&...]
  $lURI[postgresql://]

  ^if(def $self._settings.user){
    $lURI[${lURI}${self._settings.user}^if(def $self._settings.password){:$self._settings.password}@]
  }

  ^if(def $self._settings.host){
    $lURI[${lURI}^if($self._settings.host ne "local"){$self._settings.host}]
    ^if(def $self._settings.port){
      $lURI[${lURI}:$self._settings.port]
    }
  }

  ^if(def $self._settings.database){
    $lURI[${lURI}/$self._settings.database]
  }

  ^lOptions.append{$lURI}
  $result[$lOptions]
