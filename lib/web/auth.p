@USE
pf2/lib/web/controllers.p
pf2/lib/sql/models/structs.p

## Пакет с классами для авторизации

@CLASS
pfAuthBase

## Прототип класса мидлваре и класса авторизации.
##
## Наследоваться от него необязательно. Достаточно, чтобы наследник реализовывал инетрефейс мидлваре
## и добавлял в объект запроса поле с объектом пользователя.

@OPTIONS
locals

@BASE
pfMiddleware

@create[aOptions]
## aOptions.userFieldName[currentUser] — имя поля с объектом user в объекте запроса
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]

  $self._userFieldName[^ifdef[$aOptions.userFieldName]{currentUser}]
  $self._request[]

## Объект для хранения данных авторизации
## Содержит минимально-необходимый набор полей, которые любой класс авторизации должен писать в объект пользователя.
  $self._currentUser[
    $.id[]
    $.isAuthenticated(false) # Аутентифицирован
    $.isAnonymous(true) # Анонимный пользователь
    $.isActive(false) # Активный. Устанавливаем в false, если надо разлогинить
    $.data[]
    $.can[$self.can] # Ссылка на функцию првоерки прав
  ]

@GET_currentUser[]
  $result[$self._currentUser]

@processRequest[aAction;aRequest;aController;aProcessOptions] -> []
  $result[]
  $self._request[$aRequest]
  ^self.authenticate[$aRequest]
  ^aRequest.assign[$self._userFieldName;$self._currentUser]

@authenticate[aRequest]
  $result[]

@can[aPermisson] -> [bool]
  $result(false)

#--------------------------------------------------------------------------------------------------

@CLASS
pfRemoteUserAuth

## Авторизация на основе поля REMOTE_USER.
## Подходит для basic-auth в Apache.
##
## В наследнике можно перекрыть метод getUser, чтобы загружить из базы данных данные пользователя по логину.

@OPTIONS
locals

@BASE
pfAuthBase

@create[aOptions]
  ^self.cleanMethodArgument[]
  ^BASE:create[$aOptions]

@authenticate[aRequest]
  $result[]
  $self._currentUser.id[^ifdef[$aRequest.ENV.REMOTE_USER]{$aRequest.ENV.REDIRECT_REMOTE_USER}]
  $self._currentUser.isAuthenticated(true)
  $self._currentUser.isAnonymous(false)
  $self._currentUser.isActive(true)
  ^if(def $self._currentUser.id){
    $self._currentUser.data[^self.getUser[$self._currentUser.id]]
  }

@getUser[aID;aOptions]
  $result[$.login[$aID]]

#--------------------------------------------------------------------------------------------------

@CLASS
pfUserRolesAuth

## Авторизация на основе кук с поддержкй ролей пользователей.
## Реализует интерфейс мидлваре. Данные хранит в СУБД.

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
## aOptions.sql
## aOptions.cryptoProvider — объект для шифрования токенов и паролей (например, pfSQLSecurityCrypt)
## aOptions.userFieldName[currentUser] — имя поля с объектом user в объекте запроса
## aOptions.usersTableName
## aOptions.rolesTableName
## aOptions.rolesToUsersTableName
## aOptions.usersModel[pfUsersModel]
## aOptions.authCookieName[auth_token] — имя куки для хранения сессий.
## aOptions.authCookieDomain — домен для куки сессии
## aOptions.authCookiePath — путь для куки сессии
## aOptions.authCookieSecure(true) — ставим куку только на https
## aOptions.expires[days(365)|date|session] — срок жизни куки. По-умолчанию ставим ограничение куку на год.
  ^self.cleanMethodArgument[]
  $self.CSQL[$aOptions.sql]

  $self._cryptoProvider[$aOptions.cryptoProvider]
  ^self.assert(def $self._cryptoProvider){Не передан объект с криптовровайдером.}

  $self._userFieldName[^ifdef[$aOptions.userFieldName]{currentUser}]
  $self._request[]

  $self._authCookieName[^ifdef[$aOptions.authCookieName]{auth_token}]
  $self._authCookieDomain[$aOptions.authCookieDomain]
  $self._authCookiePath[$aOptions.authCookiePath]
  $self._authCookieSecure(^aOptions.authCookieSecure.bool(false))

  $self._expires[^ifdef[$aOptions.expires]{365}]

  $self._usersTableName[^ifdef[$aOptions.usersTableName]{auth_users}]
  $self._rolesTableName[^ifdef[$aOptions.rolesTableName]{auth_roles}]
  $self._rolesToUsersTableName[^ifdef[$aOptions.rolesToUsersTableName]{auth_roles_to_users}]

  $self.users[^ifdef[$aOptions.usersModel]{^self._createUsersModel[]}]

  $self._currentUser[^self._makeUser[]]
  $self._hasAuthCookie(false)

# _tokenData парсится из токена и кладется в токен обратно при записи в куку
  $self._tokenData[^hash::create[]]

@GET_currentUser[]
  $result[$self._currentUser]

@_createUsersModel[aOptions]
  $result[^pfUsersModel::create[
    $.sql[$CSQL]
    $.cryptoProvider[$self._cryptoProvider]
    $.tableName[$self._usersTableName]
    $.rolesTableName[$self._rolesTableName]
    $.rolesToUsersTableName[$self._rolesToUsersTableName]
  ]]

@processRequest[aAction;aRequest;aController;aProcessOptions] -> []
  $result[]
  ^if(def $aRequest.cookie.[$self._authCookieName]){
    ^self.authenticate[$aRequest]
    $self._hasAuthCookie(true)
  }
  ^aRequest.assign[$self._userFieldName][$self.currentUser]

@processResponse[aAction;aRequest;aResponse;aController;aProcessOptions] -> [response]
  $result[$aResponse]
  ^if($self.currentUser.isActive && $self.currentUser.isAuthenticated){
    $result.cookie.[$self._authCookieName][
      $.value[^self._makeAuthToken[]]
      $.httponly(true)
      $.expires[$self._expires]
      ^if(def $self._authCookieDomain){$.domain[$self._authCookieDomain]}
      ^if(def $self._authCookiePath){$.path[$self._authCookiePath]}
      $.secure($self._authCookieSecure)
    ]
  }{
#    Если у нас неактивный пользователь и у нас была авторизационная кука, то удаляем ее.
     ^if($self._hasAuthCookie){
       $result.cookie.[$self._authCookieName][]
     }
   }

@authenticate[aRequest;aOptions] -> []
  $result[]
  ^try{
    $self._tokenData[^self._parseAuthToken[$aRequest.cookie.[$self._authCookieName]]]
    $lUser[^self.users.fetch[
      $.userID[$self._tokenData.id]
      $.secureToken[$self._tokenData.token]
      $.isActive(true)
    ][
      $.log[-- Fetch user for authenticate (userID == $self._tokenData.id)]
    ]]
    ^if($lUser){
      ^self._currentUser.delete[]
      ^self._currentUser.add[^self._makeUser[
        $.id[$lUser.userID]
        $.data[$lUser]
        $.isActive(true)
        $.isAnonymous(false)
        $.isAuthenticated(true)
      ]]
    }
  }{
     ^if($exception.type eq "security.invalid.token"){
       $exception.handled(true)
     }
   }

@_parseAuthToken[aToken;aOptions]
  $result[^self._cryptoProvider.parseAndValidateToken[$aToken;
    $.log[-- Decrypt an auth cookie ($self._authCookieName).]
  ]]

@_makeAuthToken[aOptions] -> [serialized binary string]
  $result[]
  ^if($self._currentUser.isAuthenticated){
    $result[^self._cryptoProvider.makeToken[
      ^hash::create[$self._tokenData]
      $.id[$self._currentUser.id]
      $.token[$self._currentUser.data.secureToken]
    ][
      $.log[-- Encrypt an auth cookie ($self._authCookieName).]
    ]]
  }

@login[aRequest;aOptions] -> [bool]
## aOptions.loginField[login]
## aOptions.passwordField[password]
  ^self.cleanMethodArgument[]
  $result(false)
  $lLoginField[^self.ifdef[$aOptions.loginField]{login}]
  $lPasswordField[^self.ifdef[$aOptions.passwordField]{password}]

  $lUser[^self.users.fetch[
    $.login[$aRequest.[$lLoginField]]
    $.isActive(true)
  ][
    $.log[-- Fetch user for login (login == $lLoginField)]
  ]]
  ^if($lUser){
    $lPasswordHash[^self.users.makePasswordHash[$aRequest.[$lPasswordField];$lUser.passwordHash]]
    ^if($lUser.passwordHash eq $lPasswordHash){
      ^self._currentUser.delete[]
      ^self._currentUser.add[^self._makeUser[
        $.id[$lUser.userID]
        $.data[$lUser]
        $.isActive(true)
        $.isAnonymous(false)
        $.isAuthenticated(true)
      ]]
      ^aRequest.assign[
        $.csrfCookieNeedsReset(true)
      ]
      $result(true)
    }
  }

@logout[aRequest;aOptions] -> []
  $result[]
  ^self._currentUser.delete[]
  ^self._tokenData.delete[]
  ^self._currentUser.add[^self._makeUser[
    $.isActive(false)
  ]]
  ^aRequest.assign[
    $.csrfCookieNeedsReset(true)
  ]

@can[aPermission;*aCode] -> [bool | *aCode result]
## Варианта вызова метода:
## — ^if(^aRequest.currentUser.can[...]){__code__}
## — ^aRequest.currentUser.can[...]{__true code__}
## — ^aRequest.currentUser.can[...]{__true code__}{__false code__}
  $result(
    $self._currentUser.isAuthenticated
    && ^self.users.can[$self._currentUser.data;$aPermission]
  )
  ^if($aCode){
    ^if($result){
      $result[$aCode.0]
    }{
       $result[$aCode.1]
     }
  }

@_makeUser[aOptions] -> [hash]
  $result[
    $.id[]
    $.isAuthenticated(false) # Аутентифицирован
    $.isAnonymous(true) # Анонимный пользователь
    $.isActive(false) # Активный. Устанавливаем в false, если надо разлогинить
    $.data[]
    $.MANAGER[$self]
    $.can[$self.can]
  ]
  ^result.add[$aOptions]

#--------------------------------------------------------------------------------------------------

@CLASS
pfUsersModel

## Базовая модель для хранения пользователей

@OPTIONS
locals

@BASE
pfModelTable

@create[aOptions]
## aOptions.tableName[auth_users]
## aOptions.cryptoProvider — объект для шифрования токенов и паролей (например, pfSQLSecurityCrypt)
## aOptions.rolesTableName
## aOptions.rolesModel[pfRolesModel[$.tableName[$aOptions.rolesTableName]]]
## aOptions.rolesToUsersTableName
## aOptions.rolesToUsersModel[pfRolesToUsersModel[$.tableName[$aOptions.rolesToUsersTableName]]]
  ^BASE:create[^hash::create[$aOptions]
    $.tableName[^ifdef[$aOptions.tableName]{auth_users}]
  ]

  $self._cryptoProvider[$aOptions.cryptoProvider]
  ^self.assert(def $self._cryptoProvider){Не передан объект с криптовровайдером.}

  ^self.addFields[
    $.userID[$.dbField[user_id] $.processor[int] $.primary(true) $.widget[none]]
    $.login[$.label[] $.processor[lower_trim]]
    $.passwordHash[$.dbField[password_hash] $.label[] $.widget[none]]
    $.secureToken[$.dbField[secure_token] $.label[] $.widget[none]]
    $.isAdmin[$.dbField[is_admin] $.processor[bool] $.default(false) $.label[]]
    $.isActive[$.dbField[is_active] $.processor[bool] $.default(true) $.widget[none]]
    $.createdAt[$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true) $.widget[none]]
    $.updatedAt[$.dbField[updated_at] $.processor[auto_now] $.widget[none]]
  ]

  $self.permissions[^pfUsersPermissions::create[]]
  $self._grants[^hash::create[]]

  $self.roles[^ifdef[$aOptions.roles]{
    ^pfRolesModel::create[
      $.tableName[$aOptions.rolesTableName]
      $.sql[$CSQL]
      $.usersModel[$self]
    ]
  }]
  $self.rolesToUsers[^ifdef[$aOptions.rolesToUsersModel]{
    ^pfRolesToUsersModel::create[
      $.tableName[$aOptions.rolesToUsersTableName]
      $.sql[$CSQL]
      $.usersModel[$self]
    ]
  }]

# Кеш с айдишниками пользователей для которых мы уже загрузили роли
  $self._usersHasLoadedRoles[$.default(false)]

@fetch[aOptions;aSQLOptions]
## Перекрыть в наследниеке, если надо достать еще какие-то данные о пользователе
  $result[^self.one[$aOptions;$aSQLOptions]]

@new[aData;aSQLOptions] -> [userID]
## aData.password
  $aData[^self._makeCredentials[$aData]]
  $result[^BASE:new[$aData;$aSQLOptions]]

@modify[aUserID;aData] -> []
## aData.password
  $aData[^self._makeCredentials[$aData]]
  $result[^BASE:modify[$aUserID;$aData]]

@_makeCredentials[aData]
## aData.password
## Генерируем хеш пароля и secureToken, если нам передали aData.password и не передали хеш пароля и токен.
  $result[^hash::create[$aData]]
  ^if(def $aData.password && !def $aData.passwordHash && !def $aData.secureToken){
    $lPasswordHash[^self.makePasswordHash[$aData.password]]
    $result.passwordHash[$lPasswordHash]
    $result.secureToken[^self._cryptoProvider.digest[$lPasswordHash|^math:uuid[]]]
  }

@delete[aUserID]
  $result[^self.modify[$aUserID;$.isActive(false)]]

@restore[aUserID]
  $result[^self.modify[$aUserID;$.isActive(true)]]

@makePasswordHash[aPassword;aSalt] -> [string]
  $result[^math:crypt[$aPassword;^ifdef[$aSalt]{^$apr1^$}]]

@can[aUser;aPermission] -> [bool]
  $result(false)
  ^if($aUser){
    $result($aUser.isAdmin)
    ^if(!$result && $self.permissions){
      ^self._fetchPermissionsFor[$aUser]
      $result($self._grants.[$aUser.userID] && $self._grants.[$aUser.userID].[$aPermission])
    }
  }

@grant[aUser;aPermission;aOptions] -> []
## Разрешает пользователю воспользоваться правом aPermission.
## aOptions.ignoreNonExists(false) - не выдает ошибку, если права нет в системе
  $result[]
  ^self.assert(def $aUser.userID)[Не задан userID.]
  $aPermisson[^permissions.processName[$aPermission]]
  $lHasPermission(^permissions.contains[$aPermission])
  $lIgnoreNonExists(^aOptions.ignoreNonExists.bool(false))
  ^self.assert(!$lIgnoreNonExists || $lHasPermission)[Неизвестное право "$aPermission".]
  ^if($lHasPermission){
    ^if(!^_grants.contains[$aUser.userID]){
      $self._grants.[$aUser.userID][^hash::create[]]
    }
    $self._grants.[$aUser.userID].[$aPermission](true)
  }

@revoke[aUser;aPermission;aOptions] -> []
## Запрещает пользователю воспользоваться правом aPermission.
## aOptions.ignoreNonExists(false) - не выдает ошибку, если права нет в системе
  $result[]
  ^self.assert(def $aUser.userID)[Не задан userID.]
  $aPermisson[^permissions.processName[$aPermission]]
  $lHasPermission(^permissions.contains[$aPermission])
  $lIgnoreNonExists(^aOptions.ignoreNonExists.bool(false))
  ^self.assert(!$lIgnoreNonExists || $lHasPermission)[Неизвестное право "$aPermission".]
  $lUserGrants[$self._grants.[$aUser.userID]]
  ^if($lUserGrants && def $aPermission){
    ^lUserGrants.delete[$aPermission]
  }

@assignRoles[aUser;aRoles;aOptions] -> []
## Присваиваем пользователю роли
## Все старые роли удаляем
## aRoles[string|table|hash] — список ролей
## aOptions.columnName[roleID] — имя колонки в таблице с ролями
  $result[]
  $lUserID[^aUser.userID.int(0)]
  ^if($lUserID){
    ^CSQL.transaction{
      ^rolesToUsers.deleteAll[$.userID[$lUserID]]
      ^switch[$aRoles.CLASS_NAME]{
        ^case[string;int;double]{
          $lRoleID[^aRoles.int(0)]
          ^if($lRoleID){
            ^rolesToUsers.new[$.userID[$lUserID] $.roleID[$lRoleID]]
          }
        }
        ^case[table]{
          $lColumnName[^ifdef[$aOptions.columnName]{roleID}]
          ^aRoles.foreach[_;v]{
            $lRoleID[^v.[$lColumnName].int(0)]
            ^if($lRoleID){
              ^rolesToUsers.new[$.userID[$lUserID] $.roleID[$lRoleID]]
            }
          }
        }
        ^case[hash]{
          ^aRoles.foreach[lRoleID;_]{
            $lRoleID[^lRoleID.int(0)]
            ^if($lRoleID){
              ^rolesToUsers.new[$.userID[$lUserID] $.roleID[$lRoleID]]
            }
          }
        }
      }
    }
  }

@_fetchPermissionsFor[aUser] -> []
## Загружает роли и достает права для пользователя
  $result[]
  ^if(!$self._usersHasLoadedRoles.[$aUser.userID]){
    $lRoles[^rolesToUsers.all[
      $.userID[$aUser.userID]
      $.isActive[1]
    ]]
    ^if($lRoles){
      $lRoles[^roles.aggregate[_fields(permissions);
        $.[roleID in][$lRoles]
      ]]
      ^if($lRoles){
        $lPermissions[^roles.parsePermissions[^lRoles.foreach[_;v]{$v.permissions}[#0A]]]
        ^lPermissions.foreach[k;_v]{
          ^self.grant[$aUser;$k]
        }
      }
    }
    $self._usersHasLoadedRoles.[$aUser.userID](true)
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfUsersPermissions

## Вспомогательный класс для хранеия групп и прав пользователей.

@OPTIONS
locals

@BASE
pfClass

@create[aOptions]
  ^BASE:create[$aOptions]

  $self._permissions[^hash::create[]]
  $self._groups[
    $.DEFAULT[$.title[] $.permissions[^hash::create[]]]
  ]

  $self._pnRegex1[^regex::create[\s*:\s+][]]
  $self._pnRegex2[^regex::create[\s+][g]]

@GET[aContext]
  $result($self._permissions)

@GET_all[]
  $result[$self._permissions]

@GET_groups[]
  $result[$self._groups]

@new[aName;aTitle;aOptions] -> []
## Добавляет право в систему
## aPermission[[group:]permission]
  $result[]
  $aName[^self.processName[$aName]]
  ^self.assert(def $aName)[Не задано имя права.]
  ^self.assert(!^self._permissions.contains[$aName])[Право "$aName" уже создано.]

  $lPermission[^self.parsePermisson[$aName]]
  $self._permissions.[$aName][$.title[^ifdef[$aTitle]{$aName}]]

  ^self.assert(!def $lPermission.group || ^self._groups.contains[$lPermission.group])[Неизвестная группа прав "$lPermission.group".]
  $self._groups.[^ifdef[$lPermission.group]{DEFAULT}].permissions.[$aName][1]

@group[aName;aTitle;aOptions] -> []
## Добавляет в систему группу
  $result[]
  $aName[^self.processName[$aName]]
  ^self.assert(def $aName)[Не задано имя группы прав.]
  ^self.assert(!^self._groups.contains[$aName])[Группа прав "$aName" уже создана.]

  $self._groups.[$aName][$.title[^ifdef[$aTitle]{$aName}] $.permissions[^hash::create[]]]

@contains[aName]
  $result(^self._permissions.contains[$aName])

@processName[aName] -> [string]
  $result[^aName.trim[both]]
  $result[^result.lower[]]
  $result[^result.match[$_pnRegex1][][:]]
  $result[^result.match[$_pnRegex2][][_]]

@parsePermisson[aName] -> [$.permission $.group]
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
pfRolesModel

## Модель для ролей.
## Права храним в поле permissions. Одна строка — одно право. Строка с правом начинается с плюса.

@BASE
pfModelTable

@OPTIONS
locals

@create[aOptions]
## aOptions.tableName
## aOptions.usersModel
  ^BASE:create[^hash::create[$aOptions]
    $.tableName[^ifdef[$aOptions.tableName]{auth_roles}]
    $.allAsTable(true)
  ]

  ^self.addFields[
    $.roleID[$.dbField[role_id] $.plural[roles] $.processor[int] $.primary(true) $.widget[none]]
    $.name[$.label[]]
    $.description[$.label[]]
    $.permissions[$.label[]]
    $.isActive[$.dbField[is_active] $.processor[bool] $.default(true) $.widget[none]]
    $.createdAt[$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true) $.widget[none]]
    $.updatedAt[$.dbField[updated_at] $.processor[auto_now] $.widget[none]]
  ]
  $self._defaultOrderBy[$.name[asc] $.roleID[asc]]

  $self.usersModel[$aOptions.usersModel]

@delete[aRoleID;aOptions]
## aOptions.force(false) — удалить запись из таблиц
  ^self.cleanMethodArgument[]
  $lForce(^aOptions.force.bool(false))
  ^CSQL.transaction{
    ^if($lForce){
      $result[^BASE:delete[$aRoleID]]
      ^self.usersModel.rolesToUsers.deleteAll[$.roleID[$aRoleID]]
    }{
       $result[^self.modify[$aRoleID;$.isActive(false)]]
     }
  }

@restore[aRoleID]
  $result[^self.modify[$aRoleID;$.isActive(true)]]

@fieldValue[aField;aValue]
## Обрабатывает поле permission. Вызывается автоматически методами модели
## Если нам передали таблицу или хеш, то сериализуем права в строку
  ^if($aField is string){$aField[$_fields.[$aField]]}
  ^switch[$aField.name]{
    ^case[permissions]{
      $result[^BASE:fieldValue[$aField;^self.permissionsToString[$aValue]]]
    }
    ^case[DEFAULT]{$result[^BASE:fieldValue[$aField;$aValue]]}
  }

@permissionsToString[aPermissions;aOptions]
## Сериализует права в строку
## aPermissions[string|table|hash]
## aOptions.column[permission]
  ^switch[$aPermissions.CLASS_NAME]{
    ^case[DEFAULT;string]{$result[$aPermissions]}
    ^case[table]{
      $lColumn[^ifdef[$aOptions.column]{permission}]
      $result[^aPermissions.menu{+$aPermissions.[$lColumn]^#0A}]
    }
    ^case[hash]{
      $result[^aPermissions.foreach[k;v]{+${k}^#0A}]
    }
  }

@parsePermissions[aRawPermissions]
## Достаем права из строки в хеш
  $result[^hash::create[]]
  $lParsed[^aRawPermissions.match[^^\+(.+)^$][gm]]
  ^lParsed.foreach[_;v]{$result.[$v.1](true)}

#--------------------------------------------------------------------------------------------------

@CLASS
pfRolesToUsersModel

@OPTIONS
locals

@BASE
pfModelTable

@create[aOptions]
## aOptions.tableName
  ^BASE:create[^hash::create[$aOptions]
    $.tableName[^ifdef[$aOptions.tableName]{auth_roles_to_users}]
    $.allAsTable(true)
  ]

  ^self.addFields[
    $.userID[$.dbField[user_id] $.plural[users] $.processor[int] $.label[]]
    $.roleID[$.dbField[role_id] $.plural[roles] $.processor[int] $.label[]]
    $.createdAt[$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true) $.widget[none]]
  ]

  $self.usersModel[$aOptions.usersModel]

  ^self.addFields[
#   Виртуальное поле. Связь активна, если роль активна.
    $.isActive[
      $.expression[(case when $usersModel.roles.isActive = 1 then 1 else 0 end)]
      $.processor[bool]
    ]
  ]

@_allJoin[aOptions]
  $result[
    join $usersModel.TABLE_EXPRESSION on ($usersModel.userID = $self.userID)
    join $usersModel.roles.TABLE_EXPRESSION on ($usersModel.roles.roleID = $self.roleID)
  ]
