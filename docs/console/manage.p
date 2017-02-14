#!/usr/bin/env parser3

## Пример менеджера консольных скриптов для Юникса.
##
## Предположим, что папка нашего пользователя /usr/home/parser_user,
## а проект на pf2 лежит в /usr/home/parser_user/pf2_project
##
## Создаем Папку /usr/home/parser_user/bin и кладем в папку parser3,
## драйверы для базы данных и кодировки:
## bin/
## bin/parser3
## bin/lib/libparser3mysql.so
## bin/charsets/koi8-r.cfg
## bin/charsets/windows-1250.cfg
## bin/charsets/windows-1251.cfg
## bin/charsets/windows-1254.cfg
## bin/charsets/windows-1257.cfg
##
## Кладем этот manage.p в корень нашего проекта.
##
## Не забываем сделать "chmod u+x manage.p". Тогда можно будет вызывать файл напрямую из командной строки:
## > ./manage.p
## Usage: manage.p [APP SWITCHES] COMMAND [SUBCOMMAND [SWITCHES]] args…
##
## App switches:
## --help    Prints this help message and quits.
##
## Commands:
##   generate    Generate models, forms and controllers. See "manage.p generate --help" for more info.
##   sql   A MySQL management command. See "manage.p sql --help" for more info.
##   core:regions    See "manage.p core:regions --help" for more info.
##
## Но можно вызывать и с помощью бинарника Парсера:
## > parser3 ./manage.p [команды]
##

@main[]
# Для подключения пакетов в main используем функцию use.
# Обязательно добавляем папку в которой находится программа.
  ^CLASS_PATH.append{./}

# Задаем пути поиска библиотек.
  ^CLASS_PATH.append{/../vendor/}

# Строка подключения к базе данных.
  $connect_string[mysql://test@localhost/test]

# Подключаем и настраиваем соединение с БД и модели нашего проекта.
  ^use[pf2/lib/sql/connection.p]
  ^use[models/core.p]

  $csql[^pfSQLConnection::create[$connect_string;
    $.enableMemoryCache(true)
    $.enableQueriesLog(true)
  ]]
  $core[^appCore::create[$.sql[$csql]]]

# Подключаем классы для организации консольных команд.
  ^use[pf2/lib/console/console_app.p]

# Создаем консольное приложение.
  $app[^pfConsoleApp::create[]]

# Добавляем команду для генерации кода моделей форм и контроллеров.
# Имя команды может быть любым и не зависит от имени файла с командой или именем класса.
  ^app.assignCommand[generate;pf2/lib/console/commands/generate.p@pfConsoleGenerateCommand;
    $.sql[$csql]
  ]

# Добавляем команду для работы с sql-сервером
  ^app.assignCommand[sql;pf2/lib/console/commands/mysql.p@pfMySQLCommand;
    $.sql[$csql]
  ]

# Подключаем команду из нашего проекта.
# В имени команды можно использовать двоеточие. Это удобно, если у нас есть несколько одинаковых команд
# из разных приложений и мы хотим сделать псевдонеймспейсы в консоли.
  ^app.assignCommand[core:regions;commands/regions.p@appRegionsCommand;$.sql[$csql] $.core[$core]]

# Запускаем приложение.
  $result[^app.run[]]

#--------------------------------------------------------------------------------------------------

@auto[filespec]
## Настраиваем Парсер для автономной работы.

$confdir[^file:dirname[$filespec]]

# Назначаем директорию со скриптом как рут для поиска
$request:document-root[$confdir]

# Задаем путь к библиотекам и кодировкам
$parserlibsdir[$confdir/../bin]

$charsetsdir[$parserlibsdir/charsets]
$sqldriversdir[$parserlibsdir/lib]

$CHARSETS[
#    $.koi8-r[$charsetsdir/koi8-r.cfg]
#    $.windows-1250[$charsetsdir/windows-1250.cfg]
    $.windows-1251[$charsetsdir/windows-1251.cfg]
#    $.windows-1257[$charsetsdir/windows-1257.cfg]
    $.iso-8859-1[$charsetsdir/windows-1250.cfg]
]

$SQL[
	$.drivers[^table::create{protocol	driver	client
mysql	$sqldriversdir/libparser3mysql.so	libmysqlclient.so
pgsql	$sqldriversdir/libparser3pgsql.so	-configure could not guess-
oracle	$sqldriversdir/libparser3oracle.so	-configure could not guess-
sqlite	$sqldriversdir/libparser3sqlite.so	-configure could not guess-
}]
]

$CLASS_PATH[^table::create{path}]

@unhandled_exception[exception;stack]
# Показываем сообщение об ошибке
Unhandled Exception^if(def $exception.type){ ($exception.type)}
Source: $exception.source
Comment: $exception.comment
^if(def $exception.file){File: $exception.file ^(${exception.lineno}:$exception.colno^)}
^if($stack){
Stack trace:
^stack.menu{$stack.name^#09$stack.file ^(${stack.lineno}:$stack.colno^)}[^#0A]
}
