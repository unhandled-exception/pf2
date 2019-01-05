# PF2 Library

@CLASS
pfZagruzkaSMSGate

# Интерфейс для sms-шлюза компании «Связной Загрузка» — http://www.zagruzka.com/

@OPTIONS
locals

@USE
pf2/lib/common.p

@BASE
pfClass

@create[aOptions]
## aOptions.serviceID[] — service_id
## aOptions.password[]
## aOptions.url[https://smsinfo.zagruzka.com/aggrweb]
## aOptions.shortNumber[]
## aOptions.timeout(15)
  ^self.cleanMethodArgument[]
  ^self.assert(def $aOptions.serviceID)[Не задано имя пользователя (serviceID).]

  ^BASE:create[$aOptions]
  $self._serviceID[$aOptions.serviceID]
  $self._password[$aOptions.password]
  $self._url[^if(def $aOptions.url){$aOptions.url}{https://smsinfo.zagruzka.com/aggrweb}]
  $self._shortNumber[$aOptions.shortNumber]

  $self._timeout(^aOptions.timeout.int(15))

  $self._requestCharset[utf-8]
  $self._responseCharset[utf-8]

@send[aPhone;aMessage;aOptions]
## aPhone - номер телефона (для России номер должен быть в формате 7xxxxxxxxxx)
## aMessage
## result[$.status[bool] $.smsID[table] $.comment[] <$.badPhone(bool)>] - результат операции
  ^self.cleanMethodArgument[]
  ^self.assert(def $aMessage)[Не задан текст сообщения.]
  ^self.assert(def $aPhone)[Не задан получатель сообщения.]
  ^self.assert(^aPhone.length[] <= 11)[Неверный номер телефона "$aPhone".]
  $result[]
  ^try{
    $lResp[^pfCFile:load[text;$self._url;
      $.method[post]
      $.charset[$self._requestCharset]
      $.response-charset[$self._responseCharset]
      $.any-status(true)
      $.timeout($self._timeout)
      $.form[
        $.clientId[^if(^aPhone.length[] <= 11){7^aPhone.match[^^(.*?)(\d{10})^$][]{$match.2}}{$aPhone}]
        $.message[$aMessage]
        $.serviceId[$self._serviceID]
        $.pass[$self._password]
        ^if(def $self._shortNumber){
          $.source[$self._shortNumber]
        }
      ]
    ]]
    ^switch[$lResp.status]{
      ^case[200;DEFAULT]{
        $result[
          $.status(true)
          $.smsID[^lResp.text.match[^^(\d+)^$][gm]]
        ]
      }
      ^case[406]{
        $result[
          $.status(false)
          $.comment[Невозможно отправить сообщение на номер "$aOptions.phone"]
          $.badPhone(true)
        ]
      }
      ^case[400;401;403]{^throw[sms.gate.fail;Доступ к серису запрещен (неверные serviceID и/или password).;Статус - $lResp.status]}
      ^case[500;408]{^throw[sms.gate.fail;Ошибка на шлюзе.;Статус - $lResp.status]}
    }
  }{
     ^if(^exception.type.match[^^(?:http|cfile)\.][n]){
       ^throw[sms.gate.fail;Ошибка при работе с смс-шлюзом.;${exception.type}: $exception.comment]
     }
   }

@session[aCode]
## Организует единую сессию для работы с сервисом.
## Нужно только для массовой работы.
  $result[^pfCFile:session{$aCode}]
