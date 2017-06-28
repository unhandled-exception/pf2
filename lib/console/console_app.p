# PF2 Library

@USE
pf2/lib/common.p

## Фреймворк для консольных скриптов.

@CLASS
pfConsoleApp

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
## aOptions.argv[$request:argv]
## aOptions.help
  ^BASE:create[]
  ^pfChainMixin:mixin[$self]

  $self._commands[^hash::create[]]

  $self._argv[^if(def $aOptions.argv){$aOptions.argv}{$request:argv}]
  $self.args[^self._parseArgs[$self._argv]]
  $self.name[$args.name]

  $self.help[$aOptions.help]
  $self._maxHelpCommandLength(10)

@assignCommand[aCommandName;aClassDef;aOptions]
  $result[]

# Меняем двоеточие в имени команды, для поддержки неймспесов для команд.
  $lModuleName[^aCommandName.replace[:;__]]

  ^self.assignModule[$lModuleName;$aClassDef;
    ^hash::create[$aOptions]
    $.app[$self]
    $.name[$aCommandName]
  ]
  $self._commands.[$aCommandName][
    $.moduleName[$lModuleName]
  ]

@getCommand[aCommandName]
  ^if(!def $aCommandName || !^self._commands.contains[$aCommandName]){^self.fail[]}
  $result[^self.getModule[$self._commands.[$aCommandName].moduleName]]

@run[aOptions]
  ^try{
    ^if(^self.args.switches.contains[help]){^self.fail[]}
    $lCommand[^self.getCommand[$self.args.command.name]]
    ^lCommand.process[$self.args.command.args;$self.args.command.switches]
  }{
     ^switch[$exception.type]{
       ^case[console.app.usage]{
          $exception.handled(true)
         ^self.usage[$exception.comment]
       }
       ^case[console.command.usage]{
          $exception.handled(true)
         ^lCommand.usage[$exception.comment]
       }
     }
   }
  $result[^pfConsoleAppStdout:stdout[]]

@fail[aErrorMessage]
  ^throw[console.app.usage;;$aErrorMessage]

@usage[aErrorMessage]
  ^if(def $aErrorMessage){
    ^self.print[$aErrorMessage]
    ^self.print[-------------;$.end[^#0A^#0A]]
  }

  ^if(def $self.help){
    ^self.print[$self.help;$.end[^#0A^#0A]]
  }
  ^self.print[Usage: $self.name [APP SWITCHES] COMMAND [SUBCOMMAND [SWITCHES]] args…;$.end[^#0A^#0A]]

  ^self.print[App switches:]
  ^self.print[--help		Prints this help message and quits.;$.end[^#0A^#0A]]

  ^if($self._commands){
    ^self.print[Commands:]
    ^self._commands.foreach[k;]{
      $lCommand[^self.getCommand[$k]]
      ^self.print[  $k^if(^k.length[] <= $self._maxHelpCommandLength){^for[i](1;$self._maxHelpCommandLength - ^k.length[]){ }}{^#0A  ^for[i](1;$self._maxHelpCommandLength){ }}  $lCommand.help]
    }
    ^self.print[See "$self.name command --help" for more info.;$.start[^#0A]]
  }

@print[aLine;aOptions]
  $result[^pfConsoleAppStdout:print[$aLine;$aOptions]]

@_parseArgs[aArgs]
  $aArgs[^hash::create[$aArgs]]
  $result[
    $.name[^file:basename[$aArgs.0]]
    $.switches[^hash::create[]]
    $.command[
      $.name[]
      $.switches[^hash::create[]]
      $.args[^hash::create[]]
    ]
  ]
  ^aArgs.delete[0]

  $lStage[app]
  ^aArgs.foreach[k;v]{
    ^if(^v.left(2) eq "--"){
      ^v.match[^^--(.+?)(?:=(.*))?^$][]{
        ^if($lStage eq app){
          $result.switches.[$match.1][$match.2]
        }{
           ^if(def $match.2){
             $result.command.switches.[$match.1][$match.2]
           }{
              $result.command.switches.[$match.1](true)
            }
         }
      }
    }{
       ^if($lStage eq app){
         $result.command.name[$v]
         $lStage[command]
       }{
          $result.command.args.[^result.command.args._count[]][$v]
        }
     }
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfConsoleAppStdout

@OPTIONS
locals
static

@auto[]
  $self._buffer[^hash::create[]]

# Режим вывода
# console — выводим результаты через console:line
# buffer — накапливаем в буфер и отдаем в вызывающую программу при вызове метода stdout
  $self.mode[console]

@print[aLine;aOptions]
## aOptions.end[^#0A] — окончание строки. Если не надо переходить на следующую строку передаем пустой $.end[]. Отменить переход на новую строку в режиме console не получится.
## aOptions.start[] — начало строки. Удобно через него задавать отступы.
  $aOptions[^hash::create[$aOptions]]
  $result[]
  ^if($self.mode eq "console"){
#    Убираем лишний перевод строки
    ^if(^aOptions.end.right(1) eq ^#0A){$aOptions.end[^aOptions.end.left(^aOptions.end.length[] - 1)]}
    $console:line[${aOptions.start}${aLine}${aOptions.end}]
  }{
    $self._buffer.[^self._buffer._count[]][
      $.line[$aLine]
      $.start[$aOptions.start]
      $.end[^if(^aOptions.contains[end]){$aOptions.end}{^#0A}]
    ]
  }

@stdout[]
  $result[]
  ^if($self.mode ne console){
    $result[^self._buffer.foreach[_;l]{${l.start}${l.line}${l.end}}]
  }

@clear[]
  $result[]
  $self._buffer[^hash::create[]]

#--------------------------------------------------------------------------------------------------

@CLASS
pfConsoleCommand

## Базовая команда. Менеджер (pfConsoleApp) создает объект команды и вызвает метод process.
## Описание команды для usage берется из поля help.

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
## aOptions.app
## aOptions.name — имя команды в приложении
  ^BASE:create[]

  $self.app[$aOptions.app]
  $self.name[$aOptions.name]
  $self.help[]

@process[aArgs;aSwitches]
## Этот метод вызывает приложение, когда передает управление команде.
## Его надо перекрыть в наследнике.
## aArgs[$.0[command] $.1[param_1] $.2[...]] — хеш с аргументами команды. Имя команды приходит в поле 0.
## aSwitches[$.switch-name[value] ...] — хеш со свитчами команды (--switch-name[=value]). Имя свитча приходит без начальных "--".
  $result[]
  ^if(^aSwitches.contains[help]){^self.fail[]}

@usage[aErrorMessage;aCode]
## aErrorMessage — сообщение об ошибке. Выводим перед описанием скрипта.
## aCode — код, который выполняется сразу после печати строки "Usage:...". Нужно,  если хотим вывести список команд свитчей.
  $result[]
  ^if(def $aErrorMessage){
    ^self.print[$aErrorMessage]
    ^self.print[-------------;$.end[^#0A^#0A]]
  }

  ^if(def $self.help){
    ^self.print[$self.help;$.end[^#0A^#0A]]
  }

  ^self.print[Usage: $self.app.name $self.name [COMMAND [SWITCHES]] args…;$.end[^#0A^#0A]]
  $aCode
  ^self.print[Switches:]
  ^self.print[--help   Prints this help message and quits.;$.end[^#0A^#0A]]

@print[aLine;aOptions]
  $result[^pfConsoleAppStdout:print[$aLine;$aOptions]]

@fail[aErrorMessage]
  ^throw[console.command.usage;;$aErrorMessage]

#--------------------------------------------------------------------------------------------------

@CLASS
pfConsoleCommandWithSubcommands

## Команда с вложенными командами.
## Субкоманда — это метод объекта. Имя субкоманды и метод задаем через assignSubcommand.

@OPTIONS
locals

@BASE
pfConsoleCommand

@create[aOptions]
  ^BASE:create[$aOptions]

  $self._subCommands[^hash::create[]]
  $self._maxHelpSubcommandLength(10)

@assignSubcommand[aCommandDef;aFunction;aOptions]
## aCommandDef — имя команды и параметры: [command param1 [param2]]
## aFunction — имя или ссылка на функцию с командой
## aOptions.help — описание команды для usage.
  $result[]
  ^pfAssert:isTrue(def $aCommandDef){Не задано имя команды.}
  ^pfAssert:isTrue($aFunction is junction || def $aFunction){На задано имя или ссылка на функцию с командой.}

  $lParsedCommand[^aCommandDef.match[^^\s*(\S+)\s*(.*?)\s*^$][]]
  $lName[$lParsedCommand.1]
  $lParams[$lParsedCommand.2]
  ^pfAssert:isTrue(!^self._subCommands.contains[$lName]){Субкоманда "$lName" уже задана.}

  $lFunction[^if($aFunction is junction){$aFunction}{$self.[$aFunction]}]
  ^pfAssert:isTrue($lFunction is junction){Не найдена функция для команды "$lName".}

  $self._subCommands.[$lName][
    $.name[$lName]
    $.function[$lFunction]
    $.params[$lParams]

    $.help[$aOptions.help]
    $.helpCommand[^aCommandDef.trim[]]
  ]

@usage[aErrorMessage;aCode]
  ^BASE:usage[$aErrorMessage]{
    $aCode
    ^if($self._subCommands){
      ^self.print[Commands:]
      ^self._subCommands.foreach[;v]{
        ^self.print[  $v.helpCommand^if(^v.helpCommand.length[] <= $self._maxHelpSubcommandLength){^for[i](1;$self._maxHelpSubcommandLength - ^v.helpCommand.length[]){ }}{^#0A  ^for[i](1;$self._maxHelpSubcommandLength){ }}  $v.help]
      }
      ^self.print[]
    }
  }

@process[aArgs;aSwitches]
  ^BASE:process[$aArgs;$aSwitches]
  ^if(^self._subCommands.contains[$aArgs.0]){
    $result[^self._subCommands.[$aArgs.0].function[$aArgs;$aSwitches]]
  }{
     ^self.fail[]
   }
