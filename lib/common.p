# PF2 Library
# Module: common.p

@auto[aFilespec]
  $MAIN:[__PF_ROOT__][^aFilespec.match[^^(?:^taint[regex][$request:document-root])(.*?)(/lib/common.p)^$][]{$match.1}]


@CLASS
pfClass

## Базовый предок классов библиотеки

@create[aOptions]


@cleanMethodArgument[aName1;aName2;aName3;aName4;aName5;aName6;aName7;aName8;aName9;aName10][i;lName]
## Метод проверяет пришел ли вызывающему методу параметр с именем aName[1-10].
## Если пришел пустой параметр или строка, то записываем в него пустой хеш.
  $result[]
  ^for[i](1;10){
    $lName[aName$i]
    $lName[$$lName]
    ^if(!def $lName){$lName[aOptions]}
    ^if(!def $caller.[$lName] || ($caller.[$lName] is string && !def ^caller.[$lName].trim[])){$caller.[$lName][^hash::create[]]}
  }

@defProperty[aPropertyName;aVarName;aType][lVarName]
## Добавляет в объект свойство с именем aPropertyName
## ссылающееся на переменную $aVarName[_$aPropertyName].
## aType[read] - тип свойства (read|full: только для чтения|чтение/запись)
  ^pfAssert:isTrue(def $aPropertyName)[Не определено имя свойства]
  $lVarName[^if(def $aVarName){$aVarName}{_$aPropertyName}]

  ^process[$self]{@GET_$aPropertyName^[^]
    ^^switch[^$self.[$lVarName].CLASS_NAME]{
      ^^case[bool^;int^;double]{^$result(^$self.[$lVarName])}
      ^^case[DEFAULT]{^$result[^$self.[$lVarName]]}
    }
  }

  ^if($aType eq "full"){
    ^process[$self]{@SET_$aPropertyName^[aValue^]
      ^^switch[^$self.[$lVarName].CLASS_NAME]{
        ^^case[bool^;int^;double]{^$self.[$lVarName](^$aValue)}
        ^^case[DEFAULT]{^$self.[$lVarName][^$aValue]}
      }
    }
  }
  $result[]

@defReadProperty[aPropertyName;aVarName]
# Добавляет свойство только для чтения.
  ^defProperty[$aPropertyName;$aVarName]
  $result[]

@defReadWriteProperty[aPropertyName;aVarName]
# Добавляет свойство для чтения/записи.
  ^defProperty[$aPropertyName;$aVarName;full]
  $result[]

@alias[aAliasName;aMethod]
## Создает алиас aAliasName для метода aMethod.
## aMethod — ссылка на функцию.
  ^pfAssert:isTrue($aMethod is junction)[Переменная aMethod должна содержать ссылку на функцию.]
  $self.[$aName][$aMethod]
  $result[]

@unsafe[aCode;aCatchCode]
## Выполняет код и принудительно обрабатывает все exceptions.
## В случае ошибки может дополнительно выполнить aCatchCode.
  $result[^try{$aCode}{$exception.handled(true)$aCatchCode}]

@_abstractMethod[]
  ^pfAssert:fail[Не реализовано. Вызов абстрактного метода.]


#--------------------------------------------------------------------------------------------------

@CLASS
pfMixin

## Базовый класс миксина.
## Объект донор доступен через переменную this миксина.

@static:mixin[aContainer;aOptions][obj]
## aContainer[$caller.self] — если передали миксиним в объект, иначе берем self из caller'а.
## aOptions — параметры, которые передаются инициалищатору миксина
  $result[]
  $obj[^reflection:create[$CLASS_NAME;__init__;^if(def $aContainer){$aContainer}{$caller.self};$aOptions]]

@__init__[aThis;aOptions][locals]
## Инициализатор миксина. Используется вместо конструктора.
## aOptions.export[$.method1[] $.method2[]]
  $aOptions[^hash::create[$aOptions]]
  $self.this[$aThis]
  $self.mixinName[__${CLASS_NAME}__]
  $self.this.[$mixinName][$self]
  $lMethods[^if($aOptions.export){$aOptions.export}{^reflection:methods[$CLASS_NAME]}]
  $lForeach[^reflection:method[$lMethods;foreach]]
  ^lForeach[m;_]{
    ^if(!def $aOptions.export && (^m.left(1) eq "_" || $m eq "mixin")){^continue[]}
    ^if(!($this.[$m] is junction)){$this.[$m][^reflection:method[$self;$m]]}
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfHashMixin

## Добавляет объекту интерфейс хеша

@BASE
pfMixin

@__init__[aThis;aOptions]
## aOptions.includeJunctionFields.bool(false) — включать junction-поля.
  ^BASE:__init__[$aThis;$aOptions]
  $self._includeJunctionFields(^aOptions.includeJunctionFields.bool(false))

@contains[aName][locals]
## Проверяет есть ли у объекта поле с именем aName.
  $lFields[^reflection:fields[$this]]
  $result(^lFields.contains[$aName])
  ^if($result && !$_includeJunctionFields && $lFields.[$aName] is junction){
    $result(false)
  }

@foreach[aKeyName;aValueName;aCode;aSeparator][locals]
## Обходит все поля объекта.
  $lFields[^reflection:fields[$this]]
  $lForeach[^reflection:method[$lFields;foreach]]
  $result[^lForeach[lKey;lValue]{^if(!$_includeJunctionFields && $lValue is junction){^continue[]}$caller.[$aKeyName][$lKey]$caller.[$aValueName][$lValue]$aCode}[$aSeparator]]

#--------------------------------------------------------------------------------------------------

@CLASS
pfAssert

## Ассерты. Статический класс.

@OPTIONS
static

@auto[]
  $_isEnabled(true)
  $_exceptionName[assert.fail]
  $_passExceptionName[assert.pass]

@GET_enabled[]
  $result($_isEnabled)

@SET_enabled[aValue]
  $_isEnabled($aValue)

@isTrue[aCondition;aComment][result]
  ^if($enabled && !$aCondition){
    ^throw[$_exceptionName;isTrue;^if(def $aComment){$aComment}{Assertion failed exception.}]
  }

@isFalse[aCondition;aComment][result]
  ^if($enabled && $aCondition){
    ^throw[$_exceptionName;isFalse;^if(def $aComment){$aComment}{Assertion failed exception.}]
  }

@fail[aComment][result]
  ^if($enabled){
    $aComment[^switch[$aComment.CLASS_NAME]{
      ^case[int;double;string]{$aComment}
      ^case[date]{^aComment.sql-string[]}
      ^case[DEFAULT]{^json:string[$aComment;$.indent(true)]}
    }]
    ^throw[$_exceptionName;Fail;^if(def $aComment){$aComment}{Assertion failed exception.}]
  }

@pass[aComment][result]
  ^if($enabled){
    ^throw[$_passExceptionName;Pass;^if(def $aComment){$aComment}{Assertion pass exception.}]
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfString

## Функции обработки строк/

@trim[aString;aSide;aSymbols]
## Обертка над стандартным парсеровским trim'ом, которая проверяет существование строки.
  $result[^if(def $aString){^aString.trim[$aSide;$aSymbols]}]

@changeCase[str;type]
## Меняет регистр на СТРОЧНЫЙ/прописной/Первый Символ строчный/Только первый символ строчный
## и отрезает все пробельные символы в начале строки.
## type[upper/lower/first/first-upper]
  $result[^switch[^type.lower[]]{
    ^case[upper]{^str.upper[]}
    ^case[lower]{^str.lower[]}
    ^case[first]{^str.match[^^\s*(\pL)(.*?)^$][i]{^if(def $match.1){^match.1.upper[]}^if(def $match.2){^match.2.lower[]}}}
    ^case[first-upper]{^str.match[^^\s*(\pL)][]{^match.1.upper[]}}
    ^case[DEFAULT]{$str}
  }]

@rsplit[text;regex;options][table_split]
## Разбивает строку по регулярным выражениям
## options:    l - разбить слева направо (по-умолчанию);
##             r - разбить справа налево;
##             h - сформировать безымянную таблицу где части исходной строки
##                 помещаются горизонтально;
##             v - сформировать таблицу со столбцом piece, где части исходной строки
##                 помещаются вертикально (по-умолчанию).
  ^if(def $regex){
    $table_split[^table::create{piece}]
    ^if(def $text){
      $result[^text.match[(.*?)(?:$regex)][g]{^if(def $match.1){^table_split.append{$match.1}}}]
      ^if(def $result){^table_split.append{$result}}
    }
      ^if(!def $options){$options[lv]}
      ^switch[^options.lower[]]{
        ^case[r;rv;vr]{$result[^table::create[$table_split;$.reverse(1)]]}
        ^case[rh;hr]{$result[^table::create[$table_split;$.reverse(1)]]$result[^result.flip[]]}
        ^case[h;lh;hl]{$result[^table_split.flip[]]}
        ^case[DEFAULT]{$result[$table_split]}
      }
  }{
    ^throw[parser.runtime;rsplit;parameters ^$regex must be defined]
  }

@left[str;substr]
## substr - символ или набор символов до которого нужно отрезать строку слева
  $substr[^taint[regex][$substr]]
  ^if(def $str && def $substr && ^str.match[$substr]){
    $result[^str.match[^^(.*?)${substr}.*?^$][]{$match.1}]
  }{
    $result[$str]
  }

@right[str;substr]
## substr - символ или набор символов до которого нужно отрезать строку слева
  $substr[^taint[regex][$substr]]
  ^if(def $str && def $substr && ^str.match[$substr]){
    $result[^str.match[^^.*?${substr}(.*?)^$][]{$match.1}]
  }{
    $result[$str]
  }

@middle[str;left;right]
  ^if(def $str && def $left && def $right){
    $result[^left[$str;$left]]
    $result[^right[$str;$right]]
  }{
    $result[$str]
  }

@numberFormat[sNumber;sThousandDivider;sDecimalDivider;iFracLength][iTriadCount;iSign;tPart;sIntegerPart;sMantissa;sNumberOut;iMantLength;tIncomplTriad;iZeroCount;sZero]
## Форматирует число и вставляет правильные десятичные разделители
  $iSign(^math:sign($sNumber))
  $tPart[^sNumber.split[.][lh]]
  $sIntegerPart[^eval(^math:abs($tPart.0))[%.0f]]
  $sMantissa[$tPart.1]
  $iMantLength(^sMantissa.length[])
  $iFracLength(^iFracLength.int($iMantLength))
  ^if(!def $sThousandDivider){
    $sThousandDivider[ ]
  }

  ^if(^sIntegerPart.length[] > 3){
    $iIncomplTriadLength(^sIntegerPart.length[] % 3)
    ^if($iIncomplTriadLength){
      $tIncomplTriad[^sIntegerPart.match[^^(\d{$iIncomplTriadLength})(\d*)]]
      $sNumberOut[$tIncomplTriad.1]
      $sIntegerPart[$tIncomplTriad.2]
      $iTriadCount(1)
    }{
      $sNumberOut[]
      $iTriadCount(0)
    }
    $sNumberOut[$sNumberOut^sIntegerPart.match[(\d{3})][g]{^if($iTriadCount){$sThousandDivider}$match.1^iTriadCount.inc(1)}]
  }{
    $sNumberOut[$sIntegerPart]
  }

  $result[^if($iSign < 0){-}$sNumberOut^if($iFracLength > 0){^if(def $sDecimalDivider){$sDecimalDivider}{,}^sMantissa.left($iFracLength)$iZeroCount($iFracLength-^if(def $sMantissa)($iMantLength)(0))^if($iZeroCount > 0){$sZero[0]^sZero.format[%0${iZeroCount}d]}}]

@numberDecline[num;nominative;genitive_singular;genitive_plural]
## Склоняет существительные, стоящие после числительных, и позволяет избегать
## в результатах работы ваших скриптов сообщений вида: «найдено 2 записей».
## ^num_decline[натуральное число или ноль;именительный падеж;родительный падеж, ед. число;родительный падеж, мн. число]
  ^if($num > 10 && (($num % 100) \ 10) == 1){
          $result[$genitive_plural]
  }{
          ^switch($num % 10){
                  ^case(1){$result[$nominative]}
                  ^case(2;3;4){$result[$genitive_singular]}
                  ^case(5;6;7;8;9;0){$result[$genitive_plural]}
          }
  }

@parseURL[aURL][lMatches;lPos]
## Разбирает url
## result[$.protocol $.user $.password $.host $.port $.path $.options $.nameless $.url $.hash]
## result.options - таблица со столбцом piece
  $result[^hash::create[]]
  ^if(def $aURL){
    $lMatches[^aURL.match[
       ^^
       (?:([a-zA-Z\-0-9]+?)\:(?://)?)?   # 1 - protocol
       (?:(\S+?)(?:\:(\S+))?@)?          # 2 - user, 3 - password
       (?:([a-z0-9\-\.]*?[a-z0-9]))      # 4 - host
       (?:\:(\d+))?                      # 5 - port
       (/[^^\s\?]*)?                     # 6 - path
       (?:\?(\S*?))?                     # 7 - options
       (?:\#(\S*))?                      # 8 - hash (#)
       ^$
          ][xi]]
   ^if($lMatches){
      $result.protocol[$lMatches.1]
      $result.user[$lMatches.2]
      $result.password[$lMatches.3]
      $result.host[$lMatches.4]
      $result.port[$lMatches.5]
      $result.path[$lMatches.6]

      $lPos(^lMatches.7.pos[?])
      $result.nameless[^if($lPos >= 0){^lMatches.7.mid($lPos+1)}]
      $result.options[^if($lPos >= 0){^lMatches.7.left($lPos)}{$lMatches.7}]
      $result.options[^if(def $result.options){^result.options.split[&;lv]}{^table::create{piece}}]

      $result.hash[$lMatches.8]
      $result.url[$aURL]
    }
  }

@format[aString;aValues]
## Форматирует строку, заменяя макропоследовательности %(имя)Длина.ТочночтьТип значениями из хеша aValues.
## В дополнение к парсеровским типам форматирования понимает тип "s" - строковое представление значения.
## Если тип не указан, то он соответствует строковому.
   $result[^aString.match[(?<!\\)(%\((\S+?)\)((?:\d+(?:\.\d+)?)?([sudfxXo]{1})?))][g]{^if(^aValues.contains[$match.2]){^if(!def $match.4 || $match.4 eq "s"){$aValues.[$match.2]}{^eval($aValues.[$match.2])[%$match.3]}}{}}]
   $result[^result.match[\\(.)][g]{^_processEscapedSymbol[$match.1]}]

@_processEscapedSymbol[aSymbol]
## Возвращает символ, соответствующий букве в заэскейпленой конструкции.
   ^switch[$aSymbol]{
     ^case[n]{$result[^taint[^#0A]]}
     ^case[t]{$result[^taint[^#09]]}
     ^case[b;r;f]{$result[]}
     ^case[DEFAULT]{$result[$aSymbol]}
   }

@stripHTMLTags[aText]
## Удаляет из текста все HTML-теги.
  $result[^aText.match[<\/?[a-z0-9]+(?:\s+(?:[a-z0-9\_\-]+\s*(?:=(?:(?:\'[^^\']*\')|(?:\"[^^\"]*\")|(?:[0-9@\-_a-z:\/?&=\.]+)))?)?)*\/?>][gi][]]

@dec2bin[iNum;iLength][i]
## Преобразует число в двоичную строку. 5 -> '101'
  $i(1 << (^iLength.int(24)-1))
  $result[^while($i>=1){^if($iNum & $i){1}{0}$i($i >> 1)}]

@levenshteinDistance[aStr1;aStr2][locals]
## Вычисляет расстояние Левенштейна между двумя строками.
## Алгоритм потребляет очень много памяти, поэтому его лучше использовать
## на коротких строках (до 15-20 символов).
  $result(0)

  ^if(^aStr1.length[] > ^aStr2.length[]){
#   Make sure n <= m, to use O(min(n,m)) space
    $lStr1[$aStr2]
    $lStr2[$aStr1]
  }{
     $lStr1[$aStr1]
     $lStr2[$aStr2]
   }
  $n(^lStr1.length[])
  $m(^lStr2.length[])

  ^if($n > 0 && $m > 0){
#   Keep current and previous row, not entire matrix
    $current_row[^hash::create[]]
    ^for[i](0;$n){
      $current_row.[$i]($i)
    }
    ^for[i](1;$m){
      $previous_row[$current_row]
      $current_row[^hash::create[]]
      $current_row.0($i)
      ^for[j](1;$n){
        $add($previous_row.[$j] + 1)
        $delete($current_row.[^eval($j - 1)] + 1)
        $change($previous_row.[^eval($j - 1)])
        ^if(^lStr1.mid($j - 1;1) ne ^lStr2.mid($i - 1;1)){
          ^change.inc[]
        }
        $lTemp(^if($add < $delete){$add}{$delete})
        $current_row.[$j](^if($lTemp < $change){$lTemp}{$change})
      }
    }
    $result($current_row.[$n])
  }{
     $result(^math:abs($n - $m))
   }

#--------------------------------------------------------------------------------------------------

@CLASS
pfValidate

## Класс для проверки данных на различные условия.

@auto[]
  $emptyStringRegex[\s+]
  $alphaNumericRegexp[[\p{L}\p{Nd}_]+]
  $slugRegex[[\p{L}\p{Nd}_-]+]
  $onlyLettersRegex[\p{L}+]
  $onlyDigitsRegex[\p{Nd}+]
  $hexDecimalRegex[(?:[0-9A-Fa-f]{2})+]
  $ipAddressRegex[(25[0-5]|2[0-4]\d|[0-1]?\d?\d)(\.(25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3}]
  $validEmailRegex[(?:[-!\#^$%&'*+/=?^^_`{}|~0-9A-Za-z]+(?:\.[-!\#^$%&'*+/=?^^_`{}|~0-9A-Za-z]+)*|"(?:[\001-\010\013\014\016-\037!\#-\[\]-\177]|\\[\001-011\013\014\016-\177])*")@(?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,6}]
  $validURLRegex[(?:[a-zA-Z\-0-9]+?\:(?://)?)(?:\S+?(?:\:\S+)?@)?(?:[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,5}|$ipAddressRegex)(?:\:\d+)?(?:(?:/|\?)\S*)?]

@create[]
  $result[]

@isEmpty[aString]
## Строка пустая или содержит только пробельные символы.
  $result(!def $aString || ^aString.match[^^$emptyStringRegex^$][n])

@isNotEmpty[aString]
## Строка не пустая.
  $result(!^isEmpty[$aString])

@isAlphaNumeric[aString]
## Строка содержит только буквы, цифры и знак подчеркивания.
  $result(def $aString && ^aString.match[^^$alphaNumericRegexp^$][n])

@isSlug[aString]
## Строка содержит только буквы, цифры, знак подчеркивания и дефис.
  $result(def $aString && ^aString.match[^^$slugRegex^$][n])

@isLowerCase[aString]
## Строка содержит буквы только нижнего регистра.
  $result(def $aString && ^aString.lower[] eq $aString)

@isUpperCase[aString]
## Строка содержит буквы только верхнего регистра.
  $result(def $aString && ^aString.upper[] eq $aString)

@isOnlyLetters[aString]
## Строка содержит только буквы.
## Проверяются только буквы.
  $result(def $aString && ^aString.match[^^$onlyLettersRegex^$][n])

@isOnlyDigits[aString]
## Строка содержжит только цифры.
  $result(def $aString && ^aString.match[^^$onlyDigitsRegex^$][n])

@isHEXDecimal[aString]
## Строка содержит шестнадцатиричное число (парами!).
## Пары символов [0-9A-F] (без учета регистра).
  $result(def $aString && ^aString.match[^^$hexDecimalRegex^$][n])

@isValidDecimal[aString;aMaxDigits;aDecimalPlaces]
## Число содежит вещественное число.
## aMaxDigits(12) - максимальное количество цифр в числе
## aDecimalPlaces(2) - Максимальное количество символов после точки
  $result(def $aString && ^aString.match[^^[+\-]?\d{1,^eval(^aMaxDigits.int(12)-^aDecimalPlaces.int(2))}(?:\.\d{^aDecimalPlaces.int(2)})?^$][n])

@isValidIPV4Address[aString]
## Строка содержит корректный ip-адрес
  $result(def $aString && ^aString.match[^^$ipAddressRegex^$][n])

@isValidEmail[aString]
## Строка содержит корректный e-mail.
  $result(def $aString
     && ^aString.match[^^$validEmailRegex^$])
  )

@isValidURL[aString;aOptions]
## Строка содержит синтаксически-правильный URL.
## aOptions.onlyHTTP(false) - строка может содержать только URL с протоколом http
  $result(def $aString && ^aString.match[^^$validURLRegex^$][n])
  ^if($result && ^aOptions.onlyHTTP.bool(false)){
    $result(^aString.match[^^http://])
  }

@isExistingURL[aString][locals]
## Строка содержит работающий http-url.
  $result(false)
  ^if(^isValidURL[$aString]){
    ^try{
      $lFile[^curl:load[
        $.url[^untaint[as-is]{$aString}]
        $.charset[utf-8]
        $.ssl_verifypeer(0)
#       HEAD
        $.nobody(1)
      ]]
      $result($lFile.status eq "200" || $lFile.status eq "401" || $lFile.status eq "301" || $lFile.status eq "302")
    }{
        $exception.handled(true)
     }
  }

@isWellFormedXML[aString][locals]
## Строка содержит валидный XML.
  $result(false)
  ^if(def $aString){
    ^try{
      $lDoc[^xdoc::create{$aString}]
      $result(true)
    }{
       $exception.handled(true)
     }
  }

@isWellFormedXMLFragment[aString]
## Строка содержит валидный кусок XML'я.
  $result(def $aString && ^isWellFormedXML[<?xml version="1.0" encoding="$request:charset" ?>
    <root>$aString</root>
  ])

@isValidANSIDatetime[aString][locals]
## Строка содержит дату в ANSI-формате, допустимую в Парсере.
  $result(false)
  ^if(def $aString){
    ^try{
      $lDate[^date::create[$aString]]
      $result(true)
    }{
       $exception.handled(true)
     }
  }

#--------------------------------------------------------------------------------------------------
