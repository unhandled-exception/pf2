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
  ^self.assert($self._settings){"$self.CSQL.connectString" is an invalid connect string.}

  ^self.assignSubcommand[dump file_name.sql [--gzip|--bzip2] [--tables=t1,tp*] [--ignore=t1,tp*] [--only-data] [--no-owner] [--clean] [--no-acl] [--format=plain] [--jobs=n] [--lock-wait-timeout=n] [--column-inserts];$dump][
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
    $.help[Make a Postgres shell command.]
  ]
  ^self.assignSubcommand[pgbouncer_shell_command;$pgbouncer_shell_command;
    $.help[Make a Pg_bouncer shell command.]
  ]
  ^self.assignSubcommand[vacuum [prefix] [--cluster];$vacuum;
    $.help[Run a VACUUM ANALYZE command.]
  ]

  $self._maxHelpSubcommandLength(18)

@usage[aErrorMessage]
  $response:status[2]
  ^BASE:usage[$aErrorMessage]

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
## aSwitches.format[plain] — формат дампа (plain|custom|directory|tar)
## aSwitches.jobs(1) — количество потоков для формата directory
## aSwitches.lock-timeout — таймаут ожидания лока базы в милисекундах
## aSwitches.column-inserts — Выгружать данные таблиц в виде команд INSERT с явным указанием столбцов
## aSwitches.compress[уровень|метод[:строка_информации]] — Указывает метод и/или уровень сжатия. В качестве метода сжатия можно выбрать gzip, lz4, zstd или none (без сжатия). В качестве дополнительной информации можно передать параметры сжатия.

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

    ^if(^aSwitches.contains[column-inserts]){
      ^lOptions.append{--column-inserts}
    }

    ^if(^aSwitches.[jobs].int(0) > 0){
      ^lOptions.append{--jobs=$aSwitches.jobs}
    }

    ^if(def $aSwitches.format){
      ^lOptions.append{--format=$aSwitches.format}
    }{
      $aSwitches.format[plain]
    }

    ^if(def $aSwitches.compress){
      ^lOptions.append{--compress=$aSwitches.compress}
    }

    ^if(^aSwitches.[lock-wait-timeout].int(0)){
      ^lOptions.append{--lock-wait-timeout=$aSwitches.[lock-wait-timeout]}
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
    ^if($aSwitches.format eq "plain"){
      $lEnv.CGI_MANAGE_PGSQL_DUMP_FILE[^if(^lFile.left(1) ne "/"){$self._rootPath/$lFile}{$lFile}]
    }{
      ^lOptions.append{--file=^if(^lFile.left(1) ne "/"){$self._rootPath/$lFile}{$lFile}}
    }

    ^if(^aSwitches.contains[gzip]){
      $lEnv.CGI_MANAGE_PGSQL_DUMP_ARCHIVER[gzip]
    }(^aSwitches.contains[bzip2]){
      $lEnv.CGI_MANAGE_PGSQL_DUMP_ARCHIVER[bzip2]
    }

    $lPgdump[^file::exec[$self._pgdumpBin;$lEnv;$lOptions]]
    $response:status[$lPgdump.status]

    ^if($lPgdump.status == 0){
      $lNow[^date::now[]]
      ^self.print[Database have dumped to $lFile at ^lNow.iso-string[].]
    }{
       ^self.print[$lPgdump.stderr]
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
  $response:status[$lPgdump.status]

  ^if($lPgdump.status == 0){
    $lSchemaDump[$lPgdump.text]
    ^if(def $lFile){
      ^lSchemaDump.save[$lFile]
    }{
       ^self.print[$lSchemaDump]
     }
  }{
     ^self.print[$lPgdump.stderr]
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
  $response:status[$lPgdump.status]

  ^if($lPgdump.status == 0){
    $lSchemaDump[$lPgdump.text]

#   Отрезаем комментарии и лишние команды SET, удаляем пустые строки
    $lSchemaDump[^lSchemaDump.match[^^(?:--|SET)\s.*^$][gm][]]
    $lSchemaDump[^lSchemaDump.match[\n{2,}][g][^#0A^#0A]]
    $lSchemaDump[^lSchemaDump.match[^^\s+][][]]

    ^self.print[$lSchemaDump]
  }{
     ^self.print[$lPgdump.stderr]
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

@pgbouncer_shell_command[aArgs;aSwitches]
  $lOptions[^self._defaultPsqlOptions[
    $.database[pgbouncer]
    $.port[6432]
    $.host[local]
  ]]
  ^lOptions.append{--set}
  ^lOptions.append{PROMPT1=%n@%M:%>/%/%R%#%x}
  ^lOptions.append{--pset}
  ^lOptions.append{pager=off}
  ^self.print[psql ^lOptions.foreach[_;v]{$v.opt}[ ]]

@vacuum[aArgs;aSwitches]
# Отключаем ограничения на запросы
  ^self.CSQL.void{SET statement_timeout = 0}
  ^self.CSQL.void{SET lock_timeout = 36000000}

# Достаем таблицы для вакуума
  $lTables[^self.CSQL.hash{
    select table_name,
           table_catalog,
           table_schema
      from information_schema.tables
     where table_schema not in ('pg_catalog', 'information_schema')
           and table_type = 'BASE TABLE'
           ^if(def $aArgs.1){
             and table_name like '^taint[$aArgs.1]%'
           }
     order by table_schema, table_name
  }]

  ^if($lTables && ^aSwitches.contains[cluster]){
    ^self.print[Cluster tables.]
    ^self.CSQL.void{CLUSTER}
  }

  ^self.print[Vacuum and analyze tables:]
  ^lTables.foreach[t;v]{
    ^self.print[— ${v.table_schema}.${t}]
    ^self.CSQL.void{VACUUM ANALYZE "^taint[${v.table_schema}]"."^taint[${t}]"}
  }
  ^self.print[Done.]

@_parseConnectString[aConnectString] -> [hash]
  $result[^hash::create[]]
  $lParsed[^aConnectString.match[
    ^^(\S+?)://                # 1 - protocol
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

@_defaultPsqlOptions[aOptions] -> [table<opt>]
## aOptions.database
## aOptions.host
## aOptions.port
  $lOptions[^table::create{opt}]

# postgresql://[user[:password]@][netloc][:port][/dbname][?param1=value1&...]
  $lURI[postgresql://]

  ^if(def $self._settings.user){
    $lURI[${lURI}${self._settings.user}^if(def $self._settings.password){:$self._settings.password}@]
  }

  $lHost[^ifdef[$aOptions.host]{$self._settings.host}]
  $lPort[^ifdef[$aOptions.port]{$self._settings.port}]
  ^if(def $lHost){
    $lURI[${lURI}^if($lHost ne "local"){$lHost}]
    ^if(def $lPort){
      $lURI[${lURI}:$lPort]
    }
  }

  $lDatabase[^ifdef[$aOptions.database]{$self._settings.database}]
  ^if(def $lDatabase){
    $lURI[${lURI}/$lDatabase]
  }

  ^lOptions.append{$lURI}
  $result[$lOptions]
