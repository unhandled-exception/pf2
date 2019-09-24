@USE
pf2/lib/common.p


@CLASS
pfTelegramBotAPI

@OPTIONS
locals

@BASE
pfClass

@create[aBotToken;aOptions]
## aOptions.proxy — proxy-server URL
## aOptions.timeout(20) — http-timeout
  ^BASE:create[]
  ^self.assert(def $aBotToken)[Bot token is not defined]
  $self._botToken[$aBotToken]
  $self._apiURL[https://api.telegram.org/bot${self._apiPrefix}${self._botToken}]
  $self._proxy[$aOptions.proxy]
  $self._exceptionPrefix[telegram.api.]
  $self._timeout(^aOptions.timeout.int(20))

@getMe[]
  $result[^self._request[getMe]]

@sendMessage[aChatID;aText;aOptions]
## aOptions.parseMode[Markdown|HTML] — Send Markdown or HTML, if you want Telegram apps to show bold,
##                                     italic, fixed-width text or inline URLs in your bot's message.
## aOptions.disableWebPagePreview(false) — Disables link previews for links in this message
## aOptions.disableNotification(false) — Sends the message silently. iOS users will not receive a notification,
##                                       Android users will receive a notification with no sound.
## aOptions.replyToMessageID — If the message is a reply, ID of the original message
  ^cleanMethodArgument[]
  $result[^self._request[sendMessage][
    $.chat_id[$aChatID]
    $.text[$aText]
    $.parse_mode[$aOptions.parseMode]
    $.disable_web_page_preview(^aOptions.disableWebPagePreview.int(0))
    $.disable_notifications(^aOptions.disableNotification.int(0))
    $.repy_to_message_id[$aOptions.replyToMessageID]
  ]]

@getUpdates[aOptions]
## aOptions.offset — Identifier of the first update to be returned. Must be greater by one than the
##                   highest among the identifiers of previously received updates. By default,
##                   updates starting with the earliest unconfirmed update are returned.
##                   An update is considered confirmed as soon as getUpdates is called with an offset
##                   higher than its update_id. The negative offset can be specified to retrieve updates
##                   starting from -offset update from the end of the updates queue. All previous updates
##                   will forgotten.
## aOptions.limit — Limits the number of updates to be retrieved. Values between 1—100 are accepted. Defaults to 100.
  $result[^self._request[getUpdates][
    $.offset[$aOptions.offset]
    $.limit[$aOptions.limit]
  ]]

@setWebhook[aURL;aOptions]
## aOptions.certificate
  $result[^self._request[setWebhook][
    $.url[$aURL]
    $.certificate[$aOptions.certificate]
  ]]

@getWebhookInfo[aURL]
  $result[^self._request[getWebhookInfo][
    $.url[$aURL]
  ]]

@_request[aMethod;aForm]
  $result[^pfCFile::load[text;$self._apiURL/$aMethod;
    $.method[POST]
    $.any-status(true)
    $.timeout($self._timeout)
    $.form[$aForm]
    ^if(def $self._proxy){
      $.proxy-host[$self._proxy]
    }
  ]]
  ^if($result.status >= 200 && $result.status <= 299){
    ^return[
      ^json:parse[^taint[as-is][$result.text]]
    ]
  }

  ^throw[${self._exceptionPrefix}.failed;Telegram Bot API failed with code $result.status;
    ^unsafe{
      ^json:string[
        ^json:parse[^taint[as-is][$result.text]]
      ][
        $.indent(true)
      ]
    }{
      $result.text
    }
  ]
