# PF2 Library

@USE
pf2/lib/common.p

## Фреймворк для консольных скриптов.

@CLASS
pfConsoleApp

@BASE
pfClass

@create[aOptions]
## aOptions.argv[$request:argv]
## aOptions.help
  ^BASE:create[]
  ^pfChainMixin:mixin[$self]

  $_commands[^hash::create[]]

  $_argv[^if(def $aOptions.argv){$aOptions.argv}{$request:argv}]
  $args[^_parseArgs[$_argv]]
  $name[$args.name]

  $help[$aOptions.help]

@assignCommand[aCommandName;aClassDef;aOptions]
  $result[]
  ^assignModule[$aCommandName;$aClassDef;
    ^hash::create[$aOptions]
    $.app[$self]
    $.name[$aCommandName]
  ]
  $_commands.[$aCommandName][^hash::create[]]

@getCommand[aCommandName]
  ^if(!def $aCommandName || !^_commands.contains[$aCommandName]){^fail[]}
  $result[^getModule[$aCommandName]]

@run[aOptions][locals]
  ^try{
    ^if(^args.switches.contains[help]){^fail[]}
    $lCommand[^getCommand[$args.command.name]]
    ^lCommand.process[$args.command.args;$args.command.switches]
  }{
     ^switch[$exception.type]{
       ^case[console.app.usage]{
          $exception.handled(true)
         ^usage[$exception.comment]
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

@usage[aErrorMessage][locals]
  ^if(def $aErrorMessage){
    ^print[$aErrorMessage]
    ^print[-------------;$.end[^#0A^#0A]]
  }

  ^if(def $help){
    ^print[$help;$.end[^#0A^#0A]]
  }
  ^print[Usage: $name [APP SWITCHES] COMMAND [SUBCOMMAND [SWITCHES]] args…;$.end[^#0A^#0A]]

  ^print[App switches:]
  ^print[--help		Prints this help message and quits.;$.end[^#0A^#0A]]

  ^if($_commands){
    ^print[Commands:]
    ^_commands.foreach[k;v]{
      $lCommand[^getCommand[$k]]
      ^print[$k		$lCommand.help See "$name $k --help" for more info.;$.start[  ]]
    }
  }

@print[aLine;aOptions]
  $result[^pfConsoleAppStdout:print[$aLine;$aOptions]]

@_parseArgs[aArgs][locals]
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
           $result.command.switches.[$match.1][$match.2]
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
static

@auto[]
  $_buffer[^hash::create[]]

@print[aLine;aOptions]
## aOptions.end[^#0A] — окончание строки. Если не надо переходить на следующую строку передаем пустой $.end[].
## aOptions.start[] — начало строки. Удобно через него задавать отступы.
  $aOptions[^hash::create[$aOptions]]
  $result[]
  $_buffer.[^_buffer._count[]][
    $.line[$aLine]
    $.start[$aOptions.start]
    $.end[^if(^aOptions.contains[end]){$aOptions.end}{^#0A}]
  ]

@stdout[][locals]
  $result[^_buffer.foreach[_;l]{${l.start}${l.line}${l.end}}]

#--------------------------------------------------------------------------------------------------

@CLASS
pfConsoleCommand

@BASE
pfClass

@create[aOptions]
## aOptions.app
## aOptions.name — имя команды в приложении
## aOptions.help
  ^BASE:create[]

  $app[$aOptions.app]
  $name[$aOptions.name]
  $help[$aOptions.help]

@process[aArgs;aSwitches]
## Этот метод вызывает приложение, когда передает упралвение команде.
## Его надо перекрыть в наследнике.
## aSwitches
## aArgs
  $result[]
  ^if(^aSwitches.contains[help]){^fail[]}

@usage[aErrorMessage]
  $result[]
  ^if(def $aErrorMessage){
    ^print[$aErrorMessage]
    ^print[-------------;$.end[^#0A^#0A]]
  }

  ^print[Usage: $app.name $name [COMMAND [SWITCHES]] args…;$.end[^#0A^#0A]]

  ^print[Switches:]
  ^print[--help   Prints this help message and quits.;$.end[^#0A^#0A]]

@print[aLine;aOptions]
  $result[^pfConsoleAppStdout:print[$aLine;$aOptions]]

@fail[aErrorMessage]
  ^throw[console.command.usage;;$aErrorMessage]



