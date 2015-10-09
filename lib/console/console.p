# PF2 Library

@CLASS
pfConsole

## Класс накапливает строки перед выводом в консоль.

# http://www.opennet.ru/docs/RUS/shell_awk/

@OPTIONS
static

@auto[]
  ^clear[]

  $_colors[
    $.black[$.value(0)]

    $.red[$.value(1)]
    $.green[$.value(2)]
    $.brown[$.value(3)]
    $.blue[$.value(4)]
    $.purple[$.value(5)]
    $.cyan[$.value(6)]
    $.gray[$.value(7)]

    $.white[$.value(7) $.mode(1)]
    $.pink[$.value(1) $.mode(1)]
    $.lightGreen[$.value(2) $.mode(1)]
    $.yellow[$.value(3) $.mode(1)]
    $.lightBlue[$.value(4) $.mode(1)]
    $.violet[$.value(5) $.mode(1)]
    $.lightCyan[$.value(6) $.mode(1)]

    $._default[$.value(7)]
  ]

  $_ccRestore[^#1B^[0m]

  $_isColoring(true)

@GET_stdout[][k;v]
  ^if($_STDOUT){
    $result[^_STDOUT.foreach[_;v]{${v.line}^if($v.color){$_ccRestore}^if($v.break){^#0A}}]
  }{
     $result[]
   }

@GET_isEmpty[]
  $result(!$_STDOUT)

@clear[]
  $_STDOUT[^hash::create[]]

@disableColors[]
  $_isColoring(false)

@enableColors[]
  $_isColoring(true)

@setColor[aForeground;aBackground]
  ^if($_isColoring){
    ^if(!def $aBackground){$aBackground[black]}
    ^write[^#1B^[^if(def $_colors.[$aForeground].mode){${_colors.[$aForeground].mode}^;}^eval(30+$_colors.[$aForeground].value)^;^eval(40+$_colors.[$aBackground].value)m]
  }

@resetColor[]
  ^if($_isColoring){
    ^write[^#1B^[0m]
  }

@write[aLine]
  $_STDOUT.[^eval($_STDOUT + 1)][$.line[$aLine] $.break(0) $.color(0)]

@writeln[aLine]
  $_STDOUT.[^eval($_STDOUT + 1)][$.line[$aLine] $.break(1) $.color($_isColoring)]

@clearScreen[]
  ^if($_isColoring){
    ^write[^#1Bc]
  }