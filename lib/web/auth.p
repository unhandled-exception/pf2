# PF2 Library

@USE
pf2/lib/common.p
pf2/lib/sql/connection.p

## Фреймворк для работы с аутентификацией и авторизацией.

## Базовые классы (наследники pfAuthBase) реализуют общую логику.
## Базовый класс агрегирует стораджи и авторизацию в единый интерфейс.
## Стораджи (наследники pfAuthStorage) реализуют сохрвнение данных во внешних хранилищах.
## Логика авторизации реализуется в наследниках pfAuthSecurity.

## Помимо общих предков, пакет включает классы:
## pfAuthApache — базовая авторизация через Апач.
##
## pfAuthCookie — авторизация на базе cookie.
## pfAuthDBStorage — хранилище данных пользователя в базе данных.
##
## pfAuthDBRolesStorage — наследник pfAuthDBStorage, который умеет хранить роли.
## pfAuthDBRolesSecurity — Авторизация на основе ролей.

@CLASS
pfAuthBase

## Базовый класс авторизации.

@BASE
pfClass

@create[aOptions]
## aOptions.storage - объект-хранилище данных аутентификации
## aOptions.security - объект, реализующий контроль доступа
## aOptions.formPrefix[auth.] - префикс для переменных форм и кук.
  ^cleanMethodArgument[]

  ^if(def $aOptions.storage){
    $_storage[$aOptions.storage]
  }{
     $_storage[^pfAuthStorage::create[]]
   }

  ^if(def $aOptions.security){
    $_security[$aOptions.security]
  }{
     $_security[^pfAuthSecurity::create[]]
   }

  ^if(def $aOptions.formPrefix){$_formPrefix[$aOptions.formPrefix]}{$_formPrefix[auth.]}

  $_isUserLogin(false)
  $_user[^hash::create[]]

@GET_user[]
  $result[$_user]

@GET_isUserLogin[]
  $result($_isUserLogin)

@GET_security[]
  $result[$_security]

@GET_storage[]
  $result[$_storage]

@identify[aOptions]
## Пытаемся определить пользователя сами, или зовем логин
  $result(false)

@login[aOptions]
## Принудительный логин. Текущие сессии игнорируются
  $result(false)

@logout[aOptions]
## Принудительный логаут пользователя
  $result(true)

@checkLoginAndPassword[aLogin;aPassword]
## Проверяет логин и пароль.
  $result(false)

@makeRandomPassword[][passwd_length;vowels;consonants]
  $passwd_length(10)
  $vowels[aeiouy]
  $consonants[bcdfghklmnprstvxz]
  $result[^for[i](1;$passwd_length){^if($i % 2 ){^consonants.mid(^math:random(^consonants.length[] );1)}{^vowels.mid(^math:random(^vowels.length[]);1)}}]

@can[aPermission]
## Интерфейс к AuthSecurity для текущего пользователя
  $result(^security.can[$user;$aPermission])

@grant[aPermission]
## Интерфейс к AuthSecurity для текущего пользователя
  $result[^security.grant[$user;$aPermission]]

#--------------------------------------------------------------------------------------------------

@CLASS
pfAuthStorage

## Базовый класс хранилища данных аутентификации и авторизации.

@BASE
pfClass

@create[aOptions]
  ^cleanMethodArgument[]

@getUser[aID]
## Загрузить данные о пользователе по ID (как правило логину)
## Возвращает хэш с параметрами.
  $result[^hash::create[]]

@getSession[aOptions]
## Загрузить сессию по UID и SID
  $result[^hash::create[]]

@addSession[aOptions]
## Добавляем сессию в хранилище
  $result(false)

@updateSession[aOptions]
## Обновить данные о сессии в хранилище
  $result(false)

@deleteSession[aOptions]
## Удалить сессию из хранилища
  $result(false)

@isValidPassword[aID;aPassword]
## Возвращает true, если пароль для пользователя с aID правильный.
  $result(false)

@userAdd[aOptions]
## Добавляет пользователя
## result[id пользователя]
  $result[]

@userModify[aUserID;aOptions]
## Изменяет данные пользователя
  $result[]

@userDelete[aUserID;aOptions]
## Удаляет пользователя
  $result[]

#--------------------------------------------------------------------------------------------------

@CLASS
pfAuthSecurity

@BASE
pfClass

@create[aOptions]
## aOptions.storage
  ^cleanMethodArgument[]

  $_storage[$aOptions.storage]

  $_permissions[^hash::create[]]
  $_groups[
    $.DEFAULT[$.title[] $.permissions[^hash::create[]]]
  ]
  $_grants[^hash::create[]]

  $_pnRegex1[^regex::create[\s*:\s+][]]
  $_pnRegex2[^regex::create[\s+][g]]

@GET_permissions[]
  $result[$_permissions]

@GET_groups[]
  $result[$_groups]

@can[aUser;aPermission;aOptions][lHasPermission]
## aOptions.ignoreNonExists(false) - не выдает ошибку, если права нет в системе
  ^pfAssert:isTrue(def $aUser.id)[Не задан id пользователя.]

  $aPermission[^_processName[$aPermission]]
  $lHasPermission(^_permissions.contains[$aPermission])
  ^pfAssert:isTrue(!^aOptions.ignoreNonExists.bool(false) || $lHasPermission)[Неизвестное право "$aPermission".]

  $result(^_grants.contains[$aUser.id] && ^_grants.[$aUser.id].contains[$aPermission])

@newPermission[aName;aTitle;aOptions][lPermission]
## Добавляет право в систему
## aPermission[[group:]permission]
  $result[]
  $aName[^_processName[$aName]]
  ^pfAssert:isTrue(def $aName)[Не задано имя права.]
  ^pfAssert:isFalse(^_permissions.contains[$aName])[Право "$aName" уже создано.]

  $lPermission[^_parsePermisson[$aName]]
  $_permissions.[$aName][$.title[^if(def $aTitle){$aTitle}{$aName}]]

  ^pfAssert:isTrue(!def $lPermission.group || ^_groups.contains[$lPermission.group])[Неизвестная группа прав "$lPermission.group".]
  $_groups.[^if(def $lPermission.group){$lPermission.group}{DEFAULT}].permissions.[$aName][1]

@newGroup[aName;aTitle;aOptions]
## Добавляет в систему группу
  $result[]
  $aName[^_processName[$aName]]
  ^pfAssert:isTrue(def $aName)[Не задано имя группы прав.]
  ^pfAssert:isFalse(^_groups.contains[$aName])[Группа прав "$aName" уже создана.]

  $_groups.[$aName][$.title[^if(def $aTitle){$aTitle}{$aName}] $.permissions[^hash::create[]]]

@grant[aUser;aPermission;aOptions][lHasPermission;lIgnoreNonExists]
## Разрешает пользователю воспользоваться правом aPermission.
## aOptions.ignoreNonExists(false) - не выдает ошибку, если права нет в системе
  $result[]
  $aPermisson[^_processName[$aPermission]]
  $lHasPermission(^_permissions.contains[$aPermission])
  $lIgnoreNonExists(^aOptions.ignoreNonExists.bool(false))
  ^pfAssert:isTrue(def $aUser.id)[Не задан id пользователя.]
  ^pfAssert:isTrue(!$lIgnoreNonExists || $lHasPermission)[Неизвестное право "$aPermission".]
  ^if($lHasPermission){
    ^if(!^_grants.contains[$aUser.id]){
      $_grants.[$aUser.id][^hash::create[]]
    }
    $_grants.[$aUser.id].[$aPermission][1]
  }

@_processName[aName]
  $result[^aName.trim[both]]
  $result[^result.lower[]]
  $result[^result.match[$_pnRegex1][][:]]
  $result[^result.match[$_pnRegex2][][_]]

@_parsePermisson[aName][lPos]
  $lPos(^aName.pos[:])
  $result[
    ^if($lPos > 0){
      $.group[^aName.mid(0;$lPos)]
      $.permission[^aName.mid($lPos+1)]
    }{
       $.permission[$aName]
     }
  ]

#--------------------------------------------------------------------------------------------------

@CLASS
pfAuthApache

@BASE
pfAuthBase

@create[aOptions]
## aOptions.security - объект, реализующий контроль доступа
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]
  $_isUserLogin(false)
  $_user[^hash::create[]]

@identify[aOptions]
## Пытаемся определить пользователя сами, или зовем логин
  $result(false)
    $_user[
      ^if(def $env:REMOTE_USER || def $env:REDIRECT_REMOTE_USER){
        $.id[^if(def $env:REMOTE_USER){$env:REMOTE_USER}{$env:REDIRECT_REMOTE_USER}]
      }
      $.ip[$env:REMOTE_ADDR]
    ]
  $_user.login[$_user.id]
  $result(true)
  $_isUserLogin($result)

@login[aOptions]
## Принудительный логин. Текущие сессии игнорируются
  $result(^identify[])

@logout[aOptions]
## Принудительный логаут пользователя
  ^_user{^hash::create[]}
  ^_isUserLogin(false)
  $result(true)

#--------------------------------------------------------------------------------------------------

@CLASS
pfAuthCookie

@BASE
pfAuthBase

@create[aOptions]
## aOptions.storage - объект-хранилище данных аутентификации
## aOptions.security - объект, реализующий контроль доступа
## aOptions.formPrefix[auth.] - префикс для переменных форм и кук.
## aOptions.timeout(60) - время (в минутах) текущей сессии
## aOptions.persistentSessionLifetime(14) - время (в днях) на которое ставится сессионная кука,
##                                           если нам нужно поставить сессионную куку.
## aOptions.debugMode(0) - в этом режиме разработчик может войти под любым логином,
##                         использовать крайне осторожно!
## aOptions.secureCookie(false) - куки будут установлены пользователю только при работе через
##                                защищенное соединение.

  ^BASE:create[$aOptions]
  ^cleanMethodArgument[]

  $_debugMode(^aOptions.debugMode.int(0))
  $_secureCookie(^aOptions.secureCookie.bool(false))

  $_formPrefix[^if(def $aOptions.formPrefix){$aOptions.formPrefix}{auth.}]

  $_timeout(^aOptions.timeout.int(60))
  $_persistentSessionLifetime(^aOptions.persistentSessionLifetime.int(14))
  $_UIDLifetime(365)
  $_now[^date::now[]]

# Данные сессии
  $_session[^hash::create[]]

@GET_formPrefix[]
  $result[$_formPrefix]

@GET_session[]
  $result[$_session]

@identify[aOptions;aCanUpdateSession][lSession;lNewSession;lSID;lUser]
## Пытаемся определить пользователя сами, или зовем логин
## Если пользователь хочет залогинится, то зовем ^login[]
## aOptions - данные для авторизации (если не заданы, то берем из form и cookie).
## aCanUpdateSession(true) - можно ли обновить сессию.
  ^cleanMethodArgument[]
  ^if(!$aOptions){$aOptions[$form:fields]}

  ^if(def $aOptions.[${_formPrefix}dologin]){
    $result(^login[$aOptions])
  }{
#   Иначе пытаемся залогинить юзера по сессии
     $lSession[^storage.getSession[
                 ^if(def $aOptions.[${_formPrefix}uid] && def $aOptions.[${_formPrefix}sid]){
                     $.uid[$aOptions.[${_formPrefix}uid]]]
                     $.sid[$aOptions.[${_formPrefix}sid]]]
                 }{
                     $.uid[$cookie:[${_formPrefix}uid]]
                     $.sid[$cookie:[${_formPrefix}sid]]
                  }
              ]]

#    Если найдена сессия то пытаемся получаем данные о пользователе
     ^if($lSession){
       $lUser[^storage.getUser[$lSession.login]]
       ^if($lUser){
#      Если с момента последнего доступа прошло больше $_temout минут,
#      то обновляем данные сессии
         ^if(^aCanUpdateSession.bool(true) && ^date::create[$lSession.dt_access] < ^date::create($_now-($_timeout/(24*60)))){
           $lNewSession[
             $.uid[$lSession.uid]
             $.sid[^_makeUID[]]
             $.dt_access[^_now.sql-string[]]
             $.is_persistent[$lSession.is_persistent]
           ]
           ^if(^storage.updateSession[$lSession;$lNewSession]){
             $lSession[^hash::create[$lNewSession]]
             ^_saveSession[$lSession]
           }
         }

         $_isUserLogin(true)
         $_session[$lSession]
         $_user[$lUser]
         $_user.ip[$env:REMOTE_ADDR]
       }{
          $_isUserLogin(false)
          $_user[^hash::create[]]
          $_session[^hash::create[]]
        }
     }{
#@TODO: Возможно стоит вставить guest'а
        $_isUserLogin(false)
        $_user[^hash::create[]]
        $_session[^hash::create[]]
      }

     $result($_isUserLogin)
   }

@login[aOptions][lUser;lSession]
## Принудительный логин. Текущие сессии игнорируются
  ^cleanMethodArgument[]
  $result(false)

# Пробуем найти пользователя по имени
  $lUser[^storage.getUser[$aOptions.[${_formPrefix}login]]]

  ^if($lUser && ($_debugMode || ^storage.isValidPassword[$aOptions.[${_formPrefix}password];$lUser.password])
     ){
#   Если пароль верен, то логиним
    $lSession[
      $.uid[^_makeUID[]]
      $.sid[^_makeUID[]]
      $.login[$aOptions.[${_formPrefix}login]]
      $.is_persistent[^if(def $aOptions.[${_formPrefix}persistent]){1}{0}]
    ]

    ^if(^storage.addSession[$lSession]){
      ^_saveSession[$lSession]
      $_isUserLogin(true)
      $_session[$lSession]
      $_user[$lUser]
      $_user.ip[$env:REMOTE_ADDR]
      $result(true)
    }
  }{
    $_session[^hash::create[]]
    $_user[^hash::create[]]
    $_isUserLogin(false)
  }

@logout[aOptions]
## Принудительный логаут пользователя
  ^cleanMethodArgument[]
  ^if(^storage.deleteSession[^storage.getSession[
                     $.uid[$cookie:[${_formPrefix}uid]]
                     $.sid[$cookie:[${_formPrefix}sid]]
           ]]){
     ^_clearSession[]
  }

  $_session[^hash::create[]]
  $_user[^hash::create[]]
  $_isUserLogin(false)

  $result(true)

@checkLoginAndPassword[aLogin;aPassword]
## Проверяет логин и пароль.
  $result(^storage.isValidPassword[$aLogin;$aPassword])

@_makeUID[]
  $result[^math:uid64[]^math:uid64[]]

@_saveSession[aSession]
# Сохраняет данные сессии в куках
  ^_saveParam[${_formPrefix}uid;$aSession.uid;$_UIDLifetime]
  ^_saveParam[${_formPrefix}sid;$aSession.sid;^if(^aSession.is_persistent.int(0)){$_persistentSessionLifetime}{0}]

@_saveParam[aName;aValue;aExpires]
## Метод, через который пишем пользователю куки. если нужно писать это куда-то еще, перекрываем.
^if(def $aName){
  $cookie:[$aName][
    $.value[$aValue]
    ^if($aExpires){
      $.expires($aExpires)
    }{
      $.expires[session]
    }
    ^if($_secureCookie){
      $.secure(true)
    }
    $.httponly(true)
  ]
}

@_clearSession[]
  ^_deleteParam[${_formPrefix}uid]
  ^_deleteParam[${_formPrefix}sid]

@_deleteParam[aName]
  ^if(def $aName){
    $cookie:[$aName][
      $.value[]
      $.expires[session]
      $.httponly(true)
    ]
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfAuthDBStorage

## Хранилище данных аутентификации в базе данных.

@BASE
pfAuthStorage

@create[aOptions]
## aOptions.sql - объект для доступа к БД
## aOptions.usersTable[users] - имя таблицы с пользователем
## aOptions.sessionsTable[sessions] - имя таблицы сессий
## aOptions.cryptType[crypt|md5|sha1|mysql|old_mysql] - тип хеширования пароля (default: crypt)
## aOptions.salt
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aOptions.sql)[Не передан объект для соединения с базой данных.]

  ^BASE:create[$aOptions]

  $_sql[$aOptions.sql]
  $_usersTable[^if(def $aOptions.usersTable){$aOptions.usersTable}{users}]
  $_sessionsTable[^if(def $aOptions.sessionsTable){$aOptions.sessionsTable}{sessions}]

  $_cryptType[$aOptions.cryptType]
  $_salt[^if(def $aOptions.salt){$aOptions.salt}{^$apr1^$}]

  $_extraFields[^hash::create[]]

@GET_CSQL[]
  $result[$_sql]

@addUserExtraField[aField;aDBField]
## Определяет дополнительное поле, которое надо достать из таблицы с пользователями
## aField - имя поля, которое будет в хеше с пользователем.
## aDBField - имя поля в БД.
  ^pfAssert:isTrue(def $aField)[Не задано имя дополительного поля.]
  $_extraFields.[$aField][$aDBField]

@getUser[aID;aOptions][k;v]
## Загрузить данные о пользователе по ID (по-умолчанию логину)
## aOptions.active[active|inactive|any]
## aOptions.idType[login|id]
  ^cleanMethodArgument[]
  $result[^CSQL.table{select id, login, password
                             ^if($_extraFields){
                               , ^_extraFields.foreach[k;v]{^if(def $v){$v}{$k} as $k}[, ]
                             }
                        from $_usersTable
                       where ^switch[$aOptions.idType]{
                               ^case[login;DEFAULT]{login = "$aID"}
                               ^case[id]{id = "$aID"}
                             }
                             ^switch[$aOptions.active]{
                               ^case[DEFAULT;active]{and is_active = "1"}
                               ^case[inactive]{and is_active = "0"}
                               ^case[any]{}
                             }
                   }[][$.isForce(true)]]
  $result[^if($result){$result.fields}{^hash::create[]}]

@getSession[aOptions]
## Загрузить сессию
## aOptions.uid - первый идентификатор сессии (пользовательский)
## aOptions.sid - второй идентификатор сессии (сессионный)
  ^cleanMethodArgument[]
  ^if(def $aOptions.uid && def $aOptions.sid){
    $result[^CSQL.table{select uid, sid, login, is_persistent, dt_create, dt_access, dt_close
                          from $_sessionsTable
                         where uid = "$aOptions.uid"
                               and sid = "$aOptions.sid"
                               and is_active = "1"
    }[][$.isForce(true)]]
    $result[^if($result){$result.fields}{^hash::create[]}]
  }{
    $result[^hash::create[]]
  }

@addSession[aSession]
## Добавляем сессию в хранилище
  ^CSQL.void{insert into $_sessionsTable (uid, sid, login, dt_access, dt_create, is_persistent, ip)
             values ("$aSession.uid", "$aSession.sid", "$aSession.login",
                      ^if(def $aSession.dt_access){"$aSession.dt_create"}{"^_now.sql-string[]"},
                      ^if(def $aSession.dt_login){"$aSession.dt_login"}{"^_now.sql-string[]"},
                      ^if(def $aSession.is_persistent && $aSession.is_persistent){"1"}{"0"},
                      inet_aton("$env:REMOTE_ADDR")
                     )
  }
  $result(true)

@updateSession[aSession;aNewSession]
## Обновить данные о сессии в хранилище
  ^CSQL.void{update $_sessionsTable
                set uid = "$aNewSession.uid",
                    sid = "$aNewSession.sid",
                    ^if(def $aNewSession.is_persistent){is_persistent = "$aNewSession.is_persistent",}
                    dt_access = ^if(def $aNewSession.dt_access){"$aNewSession.dt_access"}{"^_now.sql-string[]"}
              where uid = "$aSession.uid"
                    and sid = "$aSession.sid"
  }
  $result(true)

@deleteSession[aSession]
## Удалить сессию из хранилища
  ^CSQL.void{update $_sessionsTable
             set is_active = "0",
                 dt_close = "^_now.sql-string[]"
           where uid = "$aSession.uid"
                 and sid = "$aSession.sid"
  }
  $result(true)

@isValidPassword[aPassword;aCrypted]
  $result(false)
  ^if(def $aPassword && def $aCrypted){
    ^switch[^_cryptType.lower[]]{
      ^case[crypt;DEFAULT]{$result(^math:crypt[$aPassword;$aCrypted] eq $aCrypted)}
      ^case[md5]{$result(^math:md5[$aPassword] eq $aCrypted)}
      ^case[sha1]{$result(^math:sha1[$aPassword] eq $aCrypted)}
      ^case[mysql]{$result(^CSQL.int{select "$aCrypted" = PASSWORD("$aPassword")})}
      ^case[old_mysql]{$result(^CSQL.int{select "$aCrypted" = OLD_PASSWORD("$aPassword")})}
    }
  }

@passwordHash[aPassword;aOptions]
## aOptions.type - перекрывает тип, заданный в классе
## aOptions.salt[$apr1$] - salt для метода crypt
  ^cleanMethodArgument[]
  ^switch[^if(def $aOptions.type){$aOptions.type}{^_cryptType.lower[]}]{
    ^case[crypt;DEFAULT]{
      $result[^math:crypt[$aPassword;^if(def $aOptions.salt){$aOptions.salt}{$_salt}]]
    }
    ^case[md5]{$result[^math:md5[$aPassword]]}
    ^case[sha1]{$result[^math:sha1[$aPassword]]}
    ^case[mysql]{$result[^CSQL.string{select PASSWORD("$aPassword")}]}
    ^case[mysql_old]{$result[^CSQL.string{select OLD_PASSWORD("$aPassword")}]}
  }

@clearSessionsForLogin[aLogin;aOptions]
## aOptions.ignoreSession[session]
  ^cleanMethodArgument[]
  $result[]
  ^CSQL.void{
     delete from $_sessionsTable
      where login = "$aLogin"
      ^if($aOptions.ignoreSession){
        and uid != "^taint[$aOptions.ignoreSession.uid]"
      }
  }

@userAdd[aOptions][k;v]
## Добавляет пользователя
## aOptions.login
## aOptions.password
## aOptions.isActive
## aOptions.<> - поля из _extraFields
## result[id пользователя]
  $result[]
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aOptions.login)[Не задан login.]
  ^CSQL.safeInsert{
    ^CSQL.void{
      insert into $_usersTable (^_extraFields.foreach[k;v]{^if(^aOptions.contains[$k]){`^if(def $v){$v}{$k}`, }} login, password, is_active)
      values (^_extraFields.foreach[k;v]{^if(^aOptions.contains[$k]){"$aOptions.[$k]", }} "^taint[$aOptions.login]", "^taint[^passwordHash[$aOptions.password]]", "^aOptions.isActive.int(1)")
    }
    $result[^CSQL.lastInsertId[]]
  }{
     ^throw[pfAuth.user.exists;Пользователь "$aOptions.login" уже есть в системе.]
   }

@userModify[aUserID;aOptions][k;v]
## Изменяет данные пользователя
## aOptions.login
## aOptions.password
## aOptions.isActive
## aOptions.<> - поля из _extraFields
  $result[]
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(^aUserID.int(0) > 0)[Не задан userID.]
  ^CSQL.void{
    update $_usersTable
       set ^if(^aOptions.contains[login]){login = "^taint[$aOptions.login]",}
           ^if(^aOptions.contains[password]){password = "^taint[^passwordHash[$aOptions.password]]",}
           ^if(^aOptions.contains[isActive]){is_active = "^aOptions.isActive.int(1)",}
           ^_extraFields.foreach[k;v]{^if(^aOptions.contains[$k]){ `^if(def $v){$v}{$k}` = ^if(def $aOptions.[$k]){"^taint[$aOptions.[$k]]"}{null}, }}
           id = id
     where id = "^aUserID.int(0)"
  }

@userDelete[aUserID;aOptions]
## Удаляет пользователя
## По-умолчанию делает пользователя неактивным
## aOptions.force(false) - удаляет запись и сессии
## aOptions.cleanSessions(false) - удалить сессии
  $result[]
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(^aUserID.int(0) > 0)[Не задан userID.]

  ^if(^aOptions.force.bool(false)){
    ^CSQL.void{delete from $_usersTable where id = "^aUserID.int(0)"}
  }{
     ^CSQL.void{update $_usersTable set is_active = "0" where id = "^aUserID.int(0)"}
   }

  ^if(^aOptions.cleanSessions.bool(false) || ^aOptions.force.bool(false)){
    ^CSQL.void{delete from s
                     using $_sessionsTable as s
                           join $_usersTable as u
                     where s.login = u.login
                           and u.id = "^aUserID.int(0)"
              }
  }

@allUsers[aOptions][k;v]
## Таблица со всеми пользователями
## aOptions.active[active|inactive|any]
## aOptions.limit
## aOptions.offset
## aOptions.sort[id|login]
  ^cleanMethodArgument[]
  $result[^CSQL.table{select id, login, password, is_active as isActive
                             ^if($_extraFields){
                               , ^_extraFields.foreach[k;v]{^if(def $v){$v}{$k} as $k}[, ]
                             }
                        from $_usersTable
                       where 1=1
                             ^switch[$aOptions.active]{
                               ^case[DEFAULT;active]{and is_active = "1"}
                               ^case[inactive]{and is_active = "0"}
                               ^case[any]{}
                             }
                   order by ^switch[$aOptions.sort]{
                               ^case[DEFAULT;id]{id asc}
                               ^case[login]{login asc}
                            }
  }[
     ^if(^aOptions.contains[limit]){$.limit($aOptions.limit)}
     ^if(^aOptions.contains[offset]){$.offset($aOptions.offset)}
   ][$.isForce(true)]]

#--------------------------------------------------------------------------------------------------

@CLASS
pfAuthDBRolesStorage

## Хранилище пользователей и ролей в базе данных.

@BASE
pfAuthDBStorage

@create[aOptions]
## aOptions.sql - объект для доступа к БД
## aOptions.rolesTable[roles] - имя таблицы с пользователем
## aOptions.rolesToUsersTable[roles_to_users] - имя таблицы сессий
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aOptions.sql)[Не передан объект для соединения с базой данных.]

  ^BASE:create[$aOptions]

  $_sql[$aOptions.sql]
  $_rolesTable[^if(def $aOptions.rolesTable){$aOptions.rolesTable}{roles}]
  $_rolesToUsersTable[^if(def $aOptions.rolesToUsersTable){$aOptions.rolesToUsersTable}{roles_to_users}]

  $_roleExtraFields[^hash::create[]]

@addRoleExtraField[aField;aDBField]
## Определяет дополнительное поле, которое надо достать из таблицы с ролями
## aField - имя поля, которое будет в хеше с пользователем.
## aDBField - имя поля в БД.
  ^pfAssert:isTrue(def $aField)[Не задано имя дополительного поля.]
  $_roleExtraFields.[$aField][$aDBField]

@allRoles[aOptions][k;v]
## Хеш со всеми ролями.
## aOptions.active[active|inactive|any]
## aOptions.limit
## aOptions.offset
## aOptions.roleID[]
## aOptions.sort[order|id|name]
## result[hash[$.roleID[fields $.permissions[hash]]]]
  ^cleanMethodArgument[]
  $result[^CSQL.hash{select role_id,
                            role_id as roleID,
                            name,
                            permissions,
                            description,
                            is_active as isActive,
                            sort_order as sortOrder
                            ^if($_roleExtraFields){
                              , ^_roleExtraFields.foreach[k;v]{^if(def $v){$v}{$k} as $k}[, ]
                            }
                       from $_rolesTable
                      where 1=1
                            ^switch[$aOptions.active]{
                              ^case[DEFAULT;active]{and is_active = "1"}
                              ^case[inactive]{and is_active = "0"}
                              ^case[any]{}
                            }
                            ^if(def $aOptions.roleID){
                              and role_id = "^aOptions.roleID.int(0)"
                            }
                  order by ^switch[$aOptions.sort]{
                              ^case[DEFAULT;order]{sort_order asc, name asc}
                              ^case[name]{name asc}
                              ^case[id]{id asc}
                           }
  }[
     $.type[hash]
     ^if(^aOptions.contains[limit]){$.limit($aOptions.limit)}
     ^if(^aOptions.contains[offset]){$.offset($aOptions.offset)}
   ]]

# Преобразовываем поле с ролями в хеш
  ^result.foreach[k;v]{
    $v.permissions[^_parsePermissions[$v.permissions]]
  }

@getRole[aRoleID;aOptions]
## Возвращает роль с aRoleID
  ^cleanMethodArgument[]
  $aRoleID[^aRoleID.int(0)]
  ^if($aRoleID){
    $result[^allRoles[$.roleID[$aRoleID] $.active[$aOptions.active]]]
    ^if(^result.contains[$aRoleID]){
      $result[$result.[$aRoleID]]
    }
  }{
     $result[^hash::create[]]
   }

@rolesForUsers[aUsers;aOptions][k;v;lColName]
## Возвращает все роли для пользователей.
## aUsers[string|table|hash]
## aOptions.columnName[roleID]
## aOptions.active[active|inactive|any]
## aOptions.sort[order|id|name]
## result[hash of tables]
  ^cleanMethodArgument[]
  $result[^CSQL.hash{
    select ru.user_id as userID,
           ru.role_id as roleID
      from $_rolesToUsersTable as ru
           join $_rolesTable as r using (role_id)
     where 1=1
           ^if(def $aUsers){
             ^switch[$aUsers.CLASS_NAME]{
               ^case[string]{
                   and user_id = "^aUsers.int(-1)"
               }
               ^case[table]{
                 $lColName[^if(def $aOptions.columnName){$aOptions.columnName}{roleID}]
                 and user_id in (^aUsers.menu{"^aUsers.[$lColName].int(-1)", } -1)
               }
               ^case[hash]{
                 and user_id in (^aUsers.foreach[k;v]{"^k.int(-1)", } -1)
               }
             }
           }
           ^switch[$aOptions.active]{
             ^case[DEFAULT;active]{and r.is_active = "1"}
             ^case[inactive]{and r.is_active = "0"}
             ^case[any]{}
           }
  order by ^switch[$aOptions.sort]{
              ^case[DEFAULT;order]{r.sort_order asc, r.name asc}
              ^case[name]{r.name asc}
              ^case[id]{r.id asc}
           }
  }[$.type[table] $.distinct(true)]]

@permissionsForUser[aUserID;aOptions][lRaw]
## Возвращает хеш со всеми провами из всех ролей пользователя.
## aOptions.active[active|inactive|any]
## result[hash[$.permission_name(1)]]
  ^cleanMethodArgument[]
  $lRaw[^CSQL.string{
    select group_concat(r.permissions separator "\n")
      from $_rolesTable as r
           join $_rolesToUsersTable as ru using (role_id)
     where ru.user_id = "^aUserID.int(-1)"
           ^switch[$aOptions.active]{
             ^case[DEFAULT;active]{and r.is_active = "1"}
             ^case[inactive]{and r.is_active = "0"}
             ^case[any]{}
           }
  group by ru.user_id
  }[$.default{}]]
  $result[^_parsePermissions[$lRaw]]

@assignRoles[aUserID;aRoles;aOptions][lUserID;k;v]
## Прописывает пользователю aUserID роли aRoles.
## Все старые роли удаляются.
## aOptions.columnName[roleID]
  $result[]
  ^cleanMethodArgument[]
  $lUserID[^aUserID.int(0)]
  ^if($lUserID){
    ^CSQL.naturalTransaction{
      ^CSQL.void{delete from $_rolesToUsersTable where user_id = "$lUserID"}
      ^if($aRoles){
        ^CSQL.void{
           insert ignore into $_rolesToUsersTable (user_id, role_id)
                values
                ^switch[$aRoles.CLASS_NAME]{
                  ^case[string]{
                    ("$lUserID", "^aRoles.int(0)")
                  }
                  ^case[table]{
                    $lColName[^if(def $aOptions.columnName){$aOptions.columnName}{roleID}]
                    ^aRoles.menu{("$lUserID", "^aRoles.[$lColName].int(-1)")}[, ]
                  }
                  ^case[hash]{
                    ^aRoles.foreach[k;v]{("$lUserID", "^k.int(-1)")}[, ]
                  }
                }
        }
      }
    }
  }

@roleAdd[aOptions][k;v]
## Добавляет роль
## aOptions.name
## aOptions.permissions
## aOptions.permissionsColumn
## aOptions.description
## aOptions.isActive
## aOptions.sortOrder
## aOptions.<> - поля из _extraFields
## result[id роли]
  $result[]
  ^cleanMethodArgument[]
  ^CSQL.void{
    insert into $_rolesTable (
      ^_roleExtraFields.foreach[k;v]{^if(^aOptions.contains[$k]){`^if(def $v){$v}{$k}`, }}
      name, description, permissions, is_active, sort_order)
    values (
      ^_roleExtraFields.foreach[k;v]{^if(^aOptions.contains[$k]){"$aOptions.[$k]", }}
      "^taint[^if(def ^aOptions.name.trim[both]){$aOptions.name}{Новая роль}]",
      "^taint[$aOptions.description]",
      "^taint[^_permissionsToString[$aOptions.permissions;$.column[$aOptions.permissionsColumn]]]",
      "^aOptions.isActive.int(1)",
      "^aOptions.sortOrder.int(0)"
    )
  }
  $result[^CSQL.lastInsertId[]]

@roleModify[aRoleID;aOptions][k;v]
## Изменяет данные роли
## aOptions.name
## aOptions.permissions
## aOptions.permissionsColumn
## aOptions.description
## aOptions.isActive
## aOptions.sortOrder
## aOptions.<> - поля из _extraFields
  $result[]
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(^aRoleID.int(0) > 0)[Не задан roleID.]
  ^CSQL.void{
    update $_rolesTable
       set ^if(^aOptions.contains[name]){name = "^taint[$aOptions.name]",}
           ^if(^aOptions.contains[permissions]){permissions = "^taint[^_permissionsToString[$aOptions.permissions;$.column[$aOptions.permissionsColumn]]]",}
           ^if(^aOptions.contains[description]){description = "^taint[$aOptions.description]",}
           ^if(^aOptions.contains[isActive]){is_active = "^aOptions.isActive.int(1)",}
           ^if(^aOptions.contains[sortOrder]){sort_order = "^aOptions.sortOrder.int(0)",}
           ^_roleExtraFields.foreach[k;v]{^if(^aOptions.contains[$k]){ `^if(def $v){$v}{$k}` = ^if(def $aOptions.[$k]){"^taint[$aOptions.[$k]]"}{null}, }}
           role_id = role_id
     where role_id = "^aRoleID.int(0)"
  }

@roleDelete[aRoleID]
## Удаляет роль и все привязки к пользователям
  $result[]
  ^if($aRoleID){
    ^CSQL.naturalTransaction{
      ^CSQL.void{delete from $_rolesToUsersTable where role_id = "^aRoleID.int(-1)"}
      ^CSQL.void{delete from $_rolesTable where role_id = "^aRoleID.int(-1)"}
    }
  }

@userModify[aUserID;aOptions]
## aOptions.roles
## aOptions.rolesColumn[roleID]
  $result[]
  ^cleanMethodArgument[]
  ^BASE:userModify[$aUserID;$aOptions]

  ^if(^aOptions.contains[roles]){
    ^assignRoles[$aUserID;$aOptions.roles;$.columnName[$aOptions.rolesColumn]]
  }

@userAdd[aOptions][k;v]
## aOptions.roles
## aOptions.rolesColumn[roleID]
  ^cleanMethodArgument[]
  $result[^BASE:userAdd[$aOptions]]

  ^if($result && ^aOptions.contains[roles]){
    ^assignRoles[$result;$aOptions.roles;$.columnName[$aOptions.rolesColumn]]
  }

@_parsePermissions[aRawPermissions][lParsed]
  $result[^hash::create[]]
  $lParsed[^aRawPermissions.match[^^\+(.+)^$][gm]]
  ^lParsed.menu{$result.[$lParsed.1][1]}

@_permissionsToString[aPermissions;aOptions][lColumn;k;v]
## aPermissions[string|table|hash]
## aOptions.column[permission]
  ^switch[$aPermissions.CLASS_NAME]{
    ^case[DEFAULT;string]{$result[$aPermissions]}
    ^case[table]{
      $lColumn[^if(def $aOptions.column){$aOptions.column}{permission}]
      $result[^aPermissions.menu{+$aPermissions.[$lColumn]^#0A}]
    }
    ^case[hash]{
      $result[^aPermissions.foreach[k;v]{+${k}^#0A}]
    }
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfAuthDBRolesSecurity

@BASE
pfAuthSecurity

@create[aOptions]
  ^BASE:create[$aOptions]
  ^pfAssert:isTrue($_storage is pfAuthStorage)[Не задан storage-класс.]

  $_loadedUsersPermissions[^hash::create[]]

@can[aUser;aPermission;aOptions]
  ^pfAssert:isTrue(def $aUser.id)[Не задан id пользователя.]
  ^if(!^_loadedUsersPermissions.contains[$aUser.id]){
    ^_appendPermissionsFor[$aUser]
  }
  $result(^BASE:can[$aUser;$aPermission;$aOptions])

@_appendPermissionsFor[aUser][lPermissions;k;v]
  $result[]
  $lPermissions[^_storage.permissionsForUser[$aUser.id]]
  ^if($lPermissions){
    ^lPermissions.foreach[k;v]{
      ^grant[$aUser;$k]
    }
  }
  $_loadedUsersPermissions.[$aUser.id][1]

