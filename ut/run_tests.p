#!/usr/bin/env parser3

@USE
../lib/tests/unittest.p

@auto[]
  $CLASS_PATH[./]

@main[][locals]
  $tests[^pfUnittestProgram::create[]]
  $result[^tests.main[]]

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
