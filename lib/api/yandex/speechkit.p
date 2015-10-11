# PF2 Library

@CLASS
pfYandexSpeechKit

## Класс для генерации звуковых файлов через Яндексовский Спичкит.
## SpeechKit Cloud API - https://tech.yandex.ru/speechkit/cloud/doc/dg/concepts/About-docpage/

@USE
pf2/lib/common.p

@BASE
pfClass

@create[aKey;aOptions]
## aOptions.apiURL — адрес API
## aOptions.timeout(10)
  ^cleanMethodArgument[]
  ^BASE:create[]

  ^pfAssert:isTrue(def $aKey)[Не задан ключ для Yandex SpeechKit API.]
  $_apiKey[$aKey]
  $_apiURL[^if(def $aOptions.apiURL){$aOptions.apiURL}{https://tts.voicetech.yandex.net/generate}]
  $_timeout(^aOptions.timeout.int(10))

  $_generatorDefaults[
    $.format[mp3]
    $.lang[ru-RU]
    $.speaker[jane]
  ]

@generate[aText;aOptions][locals]
## Генерирует звуковой файл для текста aText.
## Описание параметров смотри в
## aOptions.foramt[wav|mp3]
## aOptions.lang[ru-RU]
## aOptions.speaker[jane|zahar]
## aOptions.emotion[good|neutral|evil|mixed]
## aOptions.drunk(false)
## aOptions.ill(false)
## aOptions.robot(false)
  ^cleanMethodArgument[]
  ^pfAssert:isTrue(def $aText)[Не задан текст для генерации голоса.]
  $lForm[
    ^_makeAPIOptions[$aOptions;$_generatorDefaults]
    $.key[$_apiKey]
    $.text[$aText]
  ]
  $result[^pfCFile:load[binary;$_apiURL;
    $.form[$lForm]
    $.timeout($_timeout)
    $.any-status(true)
    $.name[speech_audio.$lForm.format]
  ]]
  ^if($result.status != 200){
    ^throw[pfYandexSpeechKit.fail;Сервис вернул ошибку $result.status;$result.text]
  }

@_makeAPIOptions[aOptions;aDefaults][locals]
  $result[^hash::create[$aDefaults]]
  ^result.add[$aOptions]
  ^result.foreach[k;v]{
    ^if($v is bool){
      $result.[$k][^if($v){true}{false}]
    }
  }
