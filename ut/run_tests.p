#!/usr/bin/env parser3

@main[][locals]
  ^use[pf2/lib/tests/unittest.p]
  $tests[^pfUnittestProgram::create[]]
  $result[^tests.main[]]

@auto[filespec]
$CLASS_PATH[^table::create[nameless]{
./
../..
}]
$parser3dir[$env:HOME/bin]
$SQL[$.drivers[^table::create{protocol   driver   client
sqlite	$parser3dir/lib/libparser3sqlite.so	libsqlite3.so
}]]

^if(def $env:PARSER3_LIBCURL){
  ^curl:options[
    $.library[$env:PARSER3_LIBCURL]
  ]
}

@unhandled_exception[exception;stack][locals]
# Показываем сообщение об ошибке
$result[Unhandled Exception^if(def $exception.type){ ($exception.type)}
Source: $exception.source
Comment: $exception.comment
^if(def $exception.file){File: $exception.file ^(${exception.lineno}:$exception.colno^)}
^if($stack){
Stack trace:
^stack.foreach[k;v]{$v.name^#09$v.file ^(${v.lineno}:$v.colno^)}[^#0A]
}
Environment: $MAIN:CONF.envType
]
  $response:status[3]
