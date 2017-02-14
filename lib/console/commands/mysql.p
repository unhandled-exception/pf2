@USE
pf2/lib/console/console_app.p
pf2/lib/sql/models/structs.p

@CLASS
pfMySQLCommand

## Команда для работы с MySQL-сервером.

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

  $self.help[A MySQL management command.]

  $self._binPath[$self.SQL_COMMAND_BIN]
  $self._mysqldumpBin[$self._binPath/mysqldump]
  $self._rootPath[^self.ifdef[$aOptions.rootPath]{$request:document-root}]

  $self._settings[^self._parseConnectString[$self.CSQL.connectString]]
  ^pfAssert:isTrue($self._settings){"$self.CSQL.connectString" is an invalid connect string.}

  ^self.assignSubcommand[databases [prefix];$databases][
    $.help[Show available schemas.]
  ]
  ^self.assignSubcommand[dump file_name [--gzip|--bzip2] [--tables=table1,table2] [--ignore=table3,table4];$dump][
    $.help[Dump data to file.]
  ]
  ^self.assignSubcommand[schema [file_name];$schema;
    $.help[Dump a database schema.]
  ]
  ^self.assignSubcommand[settings;$settings][
    $.help[Show connection settings.]
  ]
  ^self.assignSubcommand[tables [prefix];$tables][
    $.help[Show schemas tables.]
  ]
  ^self.assignSubcommand[mysql_shell_command;$mysql_shell_command;
    $.help[Make a mysql shell command.]
  ]

@dump[aArgs;aSwitches]
  $lFile[^aArgs.1.trim[]]
  ^if(def $lFile){
    $lOptions[^self._defaultMysqlOptions[]]
    ^lOptions.append{--skip-comments}
    ^lOptions.append{--single-transaction}
    ^lOptions.append{--events}
    ^lOptions.append{--routines}
    ^lOptions.append{--force}

    ^if(def $self._settings.schema){
      ^lOptions.append{$self._settings.schema}
      ^if(^aSwitches.contains[tables]){
        $lTables[^aSwitches.tables.split[,;lv]]
        ^lTables.foreach[_;v]{
          ^lOptions.append{^v.piece.trim[]}
        }
      }
      ^if(^aSwitches.contains[ignore]){
        $lIgnore[^aSwitches.ignore.split[,;lv]]
        ^lIgnore.foreach[_;v]{
          $lTable[^v.piece.trim[]]
          ^if(^lTable.pos[.] < 0){
            $lTable[${self._settings.schema}.$lTable]
          }
          ^lOptions.append{--ignore-table=$lTable}
        }
      }
    }{
       ^lOptions.append{--all-databases}
    }

    $lEnv[^hash::create[]]
    $lEnv.CGI_MANAGE_MYSQL_DUMP_FILE[^if(^lFile.left(1) ne "/"){$self._rootPath/$lFile}{$lFile}]
    ^if(^aSwitches.contains[gzip]){
      $lEnv.CGI_MANAGE_MYSQL_DUMP_ARCHIVER[gzip]
    }(^aSwitches.contains[bzip2]){
      $lEnv.CGI_MANAGE_MYSQL_DUMP_ARCHIVER[bzip2]
    }

    $lMysqldump[^file::exec[$self._mysqldumpBin;$lEnv;$lOptions]]
    ^if($lMysqldump.status == 0){

      $lNow[^date::now[]]
      ^self.print[Database have dumped to file $lFile at ^lNow.iso-string[].]
    }{
       ^self.print[Error $lMysqldump.status: $lMysqldump.stderr]
     }
  }{
     ^self.usage[]
   }

@schema[aArgs;aSwitches]
## aArgs.1 — имя файла
  $lOptions[^self._defaultMysqlOptions[]]
  ^lOptions.append{--no-data}
  ^lOptions.append{--skip-comments}
  ^lOptions.append{--single-transaction}
  ^lOptions.append{--events}
  ^lOptions.append{--routines}
  ^lOptions.append{--force}
  ^if(def $self._settings.schema){
    ^lOptions.append{$self._settings.schema}
  }

  $lFile[^aArgs.1.trim[]]
  $lMysqldump[^file::exec[$self._mysqldumpBin;$lEnv;$lOptions]]
  ^if($lMysqldump.status == 0){
    $lSchemaDump[^lMysqldump.text.match[\sauto_increment=\d+][ig][]]
    ^if(def $lFile){
      ^lSchemaDump.save[$lFile]
    }{
       ^self.print[$lSchemaDump]
     }
  }{
    ^self.print[Error $lMysqldump.status: $lMysqldump.stderr]
  }

@settings[aArgs;aSwitches]
  ^self.print[SQL settings]
  ^self._settings.foreach[k;v]{
    ^self.print[${k}: ^self.ifdef[$v]{—};$.start[  ]]
  }

@tables[aArgs;aSwitches]
## aArgs.1 — префикс таблиц
  $lPrefix[^aArgs.1.trim[]]
  $lTables[^self.CSQL.hash{show tables ^if(def $lPrefix){like '$lPrefix%'}}]
  ^if($lTables){
    ^self.print[Found ^lTables._count[] tables^if(def $lPrefix){ starts with "$lPrefix"}:]
    ^lTables.foreach[name;_]{
      ^self.print[— $name]
    }
  }{
     ^self.print[Tables not found.]
   }

@databases[aArgs;aSwitches]
## aArgs.1 — префикс базы
  $lPrefix[^aArgs.1.trim[]]
  $lTables[^self.CSQL.hash{show databases ^if(def $lPrefix){like '$lPrefix%'}}]
  ^if($lTables){
    ^self.print[Found ^lTables._count[] schemas^if(def $lPrefix){ starts with "$lPrefix"}:]
    ^lTables.foreach[name;_]{
      ^self.print[— $name]
    }
  }{
     ^self.print[Schemas not found.]
   }

@mysql_shell_command[aArgs;aSwitches]
  $lOptions[^self._defaultMysqlOptions[]]
  ^lOptions.append{--prompt=\u@\h\_(\d)>\_}
  ^if(def $self._settings.schema){
    ^lOptions.append{--database=$self._settings.schema}
  }
  ^self.print[mysql ^lOptions.foreach[_;v]{$v.opt}[ ]]

@_parseConnectString[aConnectString] -> [hash]
  $result[^hash::create[]]
  $lParsed[^aConnectString.match[
    ^^(mysql)://                # 1 - protocol
      (?:(.+?)(?:\:(.*))?)?     # 2 - user, 3 - password
      @(?:(?:\[(.+?)\])|(.+?))  # 4 - socket, 5 - host
      (?:\/(.+?))?              # 6 - schema
      (?:\?(.*))?               # 7 - options
    ^$
  ][x]]
  ^if($lParsed){
    $result.connectString[$aConnectString]
    $result.protocol[$lParsed.1]

    ^if(def $lParsed.4){
      $result.socket[$lParsed.4]
    }{
       $result.host[$lParsed.5]
       $lColonPos(^result.host.pos[:])
       ^if($lColonPos >= 0){
         $result.port[^result.host.mid($lColonPos + 1)]
         $result.host[^result.host.left($lColonPos)]
       }
     }

    $result.schema[$lParsed.6]
    $result.user[$lParsed.2]
    $result.password[$lParsed.3]

    $result.options[$lParsed.7]
  }

@_defaultMysqlOptions[] -> [table<opt>]
  $lOptions[^table::create{opt}]

  ^if(def $self._settings.user){
    ^lOptions.append{--user=$self._settings.user}
    ^lOptions.append{--password=$self._settings.password}
  }

  ^if(def $self._settings.socket){
    ^lOptions.append{--socket=$self._settings.socket}
  }

  ^if(def $self._settings.host){
    ^lOptions.append{--host=$self._settings.host}
  }

  ^if(def $self._settings.port){
    ^lOptions.append{--port=$self._settings.port}
  }
  $result[$lOptions]
