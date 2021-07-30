#!/usr/bin/env parser3.cgi

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
sqlite	$parser3dir/lib/libparser3sqlite.so	$parser3dir/lib/system/libsqlite3.so
mysql	$parser3dir/lib/libparser3mysql.so	$parser3dir/lib/system/libmysqlclient.so
postgresql	$parser3dir/lib/libparser3pgsql.so	$parser3dir/lib/system/libpq.so
}]]

^if(def $env:PARSER3_LIBCURL){
  $curllibrary[$env:PARSER3_LIBCURL]
}(^env:PARSER_VERSION.match[linux][in]){
  $curllibrary[libcurl.so.4]
}{
  $curllibrary[$parser3dir/lib/system/libcurl.so]
}
^curl:options[
  $.library[$curllibrary]
]

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
