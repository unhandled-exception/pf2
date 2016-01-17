@USE
pf2/lib/web/controllers2.p
pf2/lib/sql/models/structs.p

## Пакет с классами для авторизации

@CLASS
pfAuthBase

## Прототип класса мидлваре и класса авторизации.
##
## Наследоваться от него необязательно. Достаточно, чтобы наследник реализовывал инетрефейс мидлваре
## и добавлял в объект запроса поле с объектом пользователя.

@BASE
pfMiddleware

@OPTIONS
locals

@create[aOptions]
## aOptions.userFieldName[currentUser] — имя поля с объектом user в объекте запроса
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]

  $self._userFieldName[^ifdef[$aOptions.userFieldName]{currentUser}]
  $self._request[]

## Объект для хранения данных авторизации
## Содержит минимально-необходимый набор полей, которые любой класс авторизации должен писать в объект пользователя.
  $self._user[
    $.id[]
    $.isAuthenticated(false) # Аутентифицирован
    $.isAnonymous(true) # Анонимный пользователь
    $.isActive(false) # Активный. Устанавливаем в false, если надо разлогинить
    $.data[]
    $.can[$self.can] # Ссылка на функцию првоерки прав
  ]

@GET_user[]
  $result[$self._user]

@processRequest[aAction;aRequest;aController;aProcessOptions] -> []
  $result[]
  $self._request[$aRequest]
  ^authenticate[$aRequest]
  ^aRequest.assign[$self._userFieldName;$self._user]

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

@BASE
pfAuthBase

@OPTIONS
locals

@create[aOptions]
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]

@authenticate[aRequest]
  $result[]
  $self._user.id[^ifdef[$aRequest.ENV.REMOTE_USER]{$aRequest.ENV.REDIRECT_REMOTE_USER}]
  $self._user.isAuthenticated(true)
  $self._user.isAnonymous(false)
  $self._user.isActive(true)
  ^if(def $self._user.id){
    $self._user.data[^getUser[$self._user.id]]
  }

@getUser[aID;aOptions]
  $result[^hash::create[]]

#--------------------------------------------------------------------------------------------------

@CLASS
pfUserRolesAuth

## Авторизация на основе кук с поддержкй ролей пользователей.
## Реализует интерфейс мидлваре. Данные хранит в СУБД.

@BASE
pfClass

@OPTIONS
locals

@create[aOptions]
## aOptions.sql
## aOptions.cryptoProvider
## aOptions.userFieldName[currentUser] — имя поля с объектом user в объекте запроса
## aOptions.usersTableName
## aOptions.usersModel[default]
## aOptions.authCookieName[auth_token] — имя куки для хранения сессий.
## aOptions.authCookieDomain — домен для куки сессии
## aOptions.authCookiePath — путь для куки сессии
## aOptions.expires[days(365)|date|session] — срок жизни куки. По-умолчанию ставим ограничение куку на год.
  ^cleanMethodArgument[]
  $self.CSQL[$aOptions.sql]
  $self._cryptoProvider[$aOptions.cryptoProvider]

  $self._userFieldName[^ifdef[$aOptions.userFieldName]{currentUser}]
  $self._request[]

  $self._authCookieName[^ifdef[$aOptions.authCookieName]{auth_token}]
  $self._authCookieDomain[$aOptions.authCookieDomain]
  $self._authCookiePath[$aOptions.authCookiePath]
  $self._expires[^ifdef[$aOptions.expires]{365}]

  $self._usersTableName[^ifdef[$aOptions.usersTableName]{auth_users}]
  $self.users[^ifdef[$aOptions.usersModel]{^self._createUsersModel[]}]

  $self._anonymousUser[
    $.id[]
    $.isAuthenticated(false) # Аутентифицирован
    $.isAnonymous(true) # Анонимный пользователь
    $.isActive(false) # Активный. Устанавливаем в false, если надо разлогинить
    $.data[]
    $.MANAGER[$self]
    $.can[$self.can]
  ]
  $self._currentUser[$self._anonymousUser]
  $self._hasAuthCookie(false)

  $self._tokenData[^hash::create[]]

@GET_currentUser[]
  $result[$self._currentUser]

@_createUsersModel[aOptions]
  $result[^pfUsersModel::create[
    $.sql[$CSQL]
    $.tableName[$self._usersTableName]]
  ]

@processRequest[aAction;aRequest;aController;aProcessOptions] -> []
  $result[]
  ^if(def $aRequest.cookie.[$self._authCookieName]){
    ^authenticate[]
    $self._hasAuthCookie(true)
  }
  ^aRequest.assign[$self._userFieldName][$self.currentUser]

@processResponse[aAction;aRequest;aResponse;aController;aProcessOptions] -> [response]
  $result[$aResponse]
  ^if($self.currentUser.isActive){
    $result.cookie.[$self._authCookieName][
      $.value[^self._makeAuthToken[]]
      $.httponly(true)
      $.expires[$self._expires]
      ^if(def $self._authCookieDomain){$.domain[$self._authCookieDomain]}
      ^if(def $self._authCookiePath){$.path[$self._authCookiePath]}
    ]
  }{
#    Если у нас неактивный пользователь и у нас была авторизационная кука, то удаляем ее.
     ^if($self._hasAuthCookie){
       $result.cookie.[$self.authCookieName][]
     }
   }

@authenticate[aRequest;aOptions]
  $result[]

@_makeAuthToken[aOptions]
  $result[]
  ^if($self._currentUser.isAuthenticated){
    $result[^self._cryptoProvider.makeToken[
      $.id[$self._currentUser.id]
      $.token[$self._currentUser.data.secureToken]
    ]]
  }

@login[aRequest;aOptions]
  $result(false)
  $lUser[^self.users.one[$.login[$aRequest.login]]]
  ^if($lUser){
    ^self._currentUser.delete[]
    ^self._currentUser.add[^self._makeUser[
      $.id[$lUser.userID]
      $.data[$lUser]
    ]]
    $result(true)
  }

@_makeUser[aOptions]
  $result[
    $.id[]
    $.isAuthenticated(true) # Аутентифицирован
    $.isAnonymous(false) # Анонимный пользователь
    $.isActive(true) # Активный. Устанавливаем в false, если надо разлогинить
    $.data[]
    $.MANAGER[$self]
    $.can[$self.can]
  ]
  ^result.add[$aOptions]

@logout[aRequest;aOptions]
  $result(false)

@can[aPermission;*aArgs]
  $result(false)

#--------------------------------------------------------------------------------------------------

@CLASS
pfUsersModel

## Базовая модель для хранения пользователей

@BASE
pfModelTable

@OPTIONS
locals

@create[aOptions]
## aOptions.tableName[auth_users]
  ^BASE:create[^hash::create[$aOptions]
    $.tableName[^ifdef[$aOptions.tableName]{auth_users}]
  ]

  ^addFields[
    $.userID[$.dbField[user_id] $.processor[uint] $.primary(true) $.widget[none]]
    $.login[$.label[]]
    $.password[$.label[]]
    $.secureToken[$.dbField[secure_token] $.label[]]
    $.createdAt[$.dbField[created_at] $.processor[auto_now] $.skipOnUpdate(true) $.widget[none]]
    $.updatedAt[$.dbField[updated_at] $.processor[auto_now] $.widget[none]]
  ]

@makePasswordHash[aPassword;aSalt]
  $result[^math::crypt[$aPassword;^ifdef[$aSalt]{^$apr1^$}]]
