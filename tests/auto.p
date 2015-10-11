@auto[filespec]
  $CLASS_PATH[/../../]

  $parserlibsdir[../../../cgi-bin/]
  $charsetsdir[$parserlibsdir/charsets]
  $sqldriversdir[$parserlibsdir/lib]

	$SQL[
		$.drivers[^table::create{protocol	driver	client
mysql	$sqldriversdir/libparser3mysql.so	libmysqlclient.so
sqlite	$sqldriversdir/libparser3sqlite.so	libsqlite3.so
#pgsql	$sqldriversdir/libparser3pgsql.so	libpq.so
}]]

#  $CHARSETS[
#    $.iso-8859-1[$charsetsdir/windows-1250.cfg]
#    $.windows-1251[$charsetsdir/windows-1251.cfg]
#  ]

  ^if(^env:PARSER_VERSION.pos[darwin] >= 0){
#   Подключаем libcurl на маке, установленный через homebrew.
    ^curl:options[$.library[/usr/local/opt/curl/lib/libcurl.dylib]]
  }

@unhandled_exception[exception;stack]
Unhandled Exception

^if(def $exception.type){Type: ${exception.type}}
Source: $exception.source
Comment: $exception.comment

Stack trace:
^if(def $exception.file){
	File: $exception.file (${exception.lineno}:$exception.colno)
}
^if($stack){
  ^stack.menu{
  $stack.name	$stack.file (${stack.lineno}:$stack.colno)
  }
}
