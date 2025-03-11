# PF2 Library
# Module: common.p

@auto[aFilespec]
  ^aFilespec.match[^^(?:^taint[regex][$request:document-root])(.+?)(?:/common.p)^$][]{$MAIN:[__PF_ROOT__][$match.1]}

@CLASS
pfClass

@OPTIONS
locals

## Базовый предок классов библиотеки

@auto[]
  $self._now[^date::now[]]
  $self._today[^date::today[]]

@create[aOptions]

@A[*aValues] -> array[aValues...]
## Создаёт массив c элементами из параметров методов.
## Аналог ^array::create[...], но с коротким именем
  $result[^array::copy[$aValues]]

@assert[aCondition;aComment] -> [] | throws: assert.fail
  $result[]
  ^if(!$aCondition){
    ^throw[assert.fail;An incorrect assertion;^self.ifdef[$aComment]{Assertion failed exception.}]
  }

@cleanMethodArgument[aName1;aName2;aName3;aName4;aName5;aName6;aName7;aName8;aName9;aName10]
## Метод проверяет пришел ли вызывающему методу параметр с именем aName[1-10].
## Если пришел пустой параметр или строка, то записываем в него пустой хеш.
  $result[]
  ^for[i](1;10){
    $lName[aName$i]
    $lName[$$lName]
    ^if(!def $lName){$lName[aOptions]}
    ^if(!def $caller.[$lName] || ($caller.[$lName] is string && !def ^caller.[$lName].trim[])){$caller.[$lName][^hash::create[]]}
  }

@defProperty[aPropertyName;aVarName;aType] -> []
## Добавляет в объект свойство с именем aPropertyName
## ссылающееся на переменную $aVarName[_$aPropertyName].
## aType[read] — тип свойства (read|full: только для чтения|чтение/запись)
  $result[]
  ^self.assert(def $aPropertyName)[Не определено имя свойства]
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

@defReadProperty[aPropertyName;aVarName] -> []
# Добавляет свойство только для чтения.
  $result[]
  ^self.defProperty[$aPropertyName;$aVarName]

@defReadWriteProperty[aPropertyName;aVarName] -> []
# Добавляет свойство для чтения/записи.
  $result[]
  ^self.defProperty[$aPropertyName;$aVarName;full]

@alias[aAliasName;aMethod] -> []
## Создает алиас aAliasName для метода aMethod.
## aMethod — ссылка на функцию.
  $result[]
  ^self.assert($aMethod is junction)[Переменная aMethod должна содержать ссылку на функцию.]
  ^if(!($self.[$aAliasName] is junction)){
    $self.[$aAliasName][$aMethod]
  }

@unsafe[aCode;aCatchCode]
## Выполняет код и принудительно обрабатывает все exceptions.
## В случае ошибки может дополнительно выполнить aCatchCode.
  $result[^try{$aCode}{$exception.handled(true)$aCatchCode}]

@ifdef[aValue;aDefaultValue]
## Возвращает значение aValue, если переменная определена (def) или возвращает aDefaultValue.
## Лучше передавать значение по-умолчанию как код:
## ^ifdef[value]{default}
## ^ifdef[value](expression)
  $result[^if(def $aValue){$aValue}{$aDefaultValue}]

@firstdef[*aArgs]
## Возвращает первый попавшийся определенный (def) аргумент.
## Аналог coalesce из sql.
  $result[$__VOID__]
  ^aArgs.foreach[_;v]{
    ^if(def $v){
      $result[$v]
      ^break[]
    }
  }

@ifcontains[aObject;aName;aDefaultValue]
## Возвращает значение поля aObject.[aName], если поле в объекте есть или aDefaultValue если нет.
## Для проверки поля вызывает метод contains объекта.
## aDefaultValue лучше вызывать как код:
## ^ifcontains[$hash;key]{default}
## ^ifcontains[$hash;key](expression))
  $result[^if(^aObject.contains[$aName]){$aObject.[$aName]}{$aDefaultValue}]

@enumerateForeach[aObject;aNumVar;aKeyVar;aValueVar;aCode;aSeparator]
  $result[$lNum(0)^aObject.foreach[k;v]{$caller.[$aNumVar][$lNum]$caller.[$aKeyVar][$k]$caller.[$aValueVar][$v]$aCode^lNum.inc[]}{$aSeparator}]

#--------------------------------------------------------------------------------------------------

@CLASS
pfMixin

## Базовый класс миксина.
## Объект донор доступен через переменную this миксина.

@BASE
pfClass

@OPTIONS
locals

@static:mixin[aContainer;aOptions]
## aContainer[$caller.self] — если передали миксиним в объект, иначе берем self из caller'а.
## aOptions — параметры, которые передаются инициализатору миксина
  $result[]
  $obj[^reflection:create[$self.CLASS_NAME;__init__;^if(def $aContainer){$aContainer}{$caller.self};$aOptions]]

@__init__[aThis;aOptions]
## Инициализатор миксина. Используется вместо конструктора.
## aOptions.export[$.method1[] $.method2[]]
  $aOptions[^hash::create[$aOptions]]
  $self.this[$aThis]
  $self.mixinName[__${self.CLASS_NAME}__]
  ^if(def $self.this.[$self.mixinName]){
    ^throw[mixin.already.applied;Миксин $self.CLASS_NAME уже применен к объекту.]
  }
  $self.this.[$self.mixinName][$self]
  $lMethods[^if($aOptions.export){$aOptions.export}{^reflection:methods[$self.CLASS_NAME]}]
  $lForeach[^reflection:method[$lMethods;foreach]]
  ^lForeach[m;_]{
    ^if(!def $aOptions.export && (^m.left(1) eq "_" || $m eq "mixin" || $m eq "auto")){^continue[]}
    ^if(!($this.[$m] is junction)){$this.[$m][^reflection:method[$self;$m]]}
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfHashMixin

## Добавляет объекту интерфейс хеша

@OPTIONS
locals

@BASE
pfMixin

@__init__[aThis;aOptions]
## aOptions.includeJunctionFields.bool(false) — включать junction-поля.
  ^BASE:__init__[$aThis;$aOptions]
  $self._includeJunctionFields(^aOptions.includeJunctionFields.bool(false))

@contains[aName]
## Проверяет есть ли у объекта поле с именем aName.
  $lFields[^reflection:fields[$this]]
  $result(^lFields.contains[$aName])
  ^if($result && !$_includeJunctionFields && $lFields.[$aName] is junction){
    $result(false)
  }

@foreach[aKeyName;aValueName;aCode;aSeparator]
## Обходит все поля объекта.
  $lFields[^reflection:fields[$this]]
  $lForeach[^reflection:method[$lFields;foreach]]
  $result[^lForeach[lKey;lValue]{^if(!$_includeJunctionFields && $lValue is junction){^continue[]}$caller.[$aKeyName][$lKey]$caller.[$aValueName][$lValue]$aCode}[$aSeparator]]

#--------------------------------------------------------------------------------------------------

@CLASS
pfChainMixin

## Добавляет в класс интерфейс для поддержки цепочек модулей с поздним связыванием.
## ^assignModule[name;package.p@Class::create]
## @GET_name[]: $result[^getModule[name]]
## Подключение пакета и создание объекта произойдет только при первом обращении к свойству name.

@OPTIONS
locals

@BASE
pfMixin

@auto[]
  $self.__pfChainMixin__[
    $.classDefRegex[^regex::create[^^([^^@:]*)(?:@([^^:]+))?(?::+(.+))?^$]]
  ]

@__init__[aThis;aOptions]
## aOptions.exportFields[$.name1[] $.name2[var_name]] — список полей объекта, которые надо передать параметрами модулую.
## aOptions.exportModulesProperty(false)
  ^BASE:__init__[$aThis;$aOptions]

  $self.modules[^hash::create[]]
  $self._exportFields[^hash::create[$aOptions.exportFields]]

  ^if(^aOptions.exportModulesProperty.bool(false)){
    ^process[$aThis]{@GET_MODULES[]
      ^$result[^$self.${self.mixinName}.modules]
    }
  }

@containsModule[aName]
  $result[^self.modules.contains[$aName]]

@assignModule[aName;aClassDef;aArgs]
## aName — имя свойства со ссылкой на модуль.
## aClassDef[path/to/package.p@className::constructor] — минимально надо указать имя класса или имя файла с классом (во втором случае имя класса берется из имени пакета без расширения).
  ^pfAssert:isTrue(def $aName){Не задано имя свойства модуля.}
  ^pfAssert:isTrue(def $aClassDef){Не задано имя класса модуля.}
  $result[]
  ^if(^self.modules.contains[$aName]){^throw[model.chain.module.exists;Модуль "$aName" уже привязан в объекте класса "$this.CLASS_NAME"]}
  $self.modules.[$aName][
    ^pfString:parseClassDef[$aClassDef]
    $.object[]
    $.args[^hash::create[$aArgs]]
    $.name[$aName]
  ]

  ^process[$this]{@GET_${aName}[]
    ^$result[^^self.${self.mixinName}.getModule[$aName]]
  }

@getModule[aName]
  ^if(^self.modules.contains[$aName]){
    ^if(!def $self.modules.[$aName].object){
    ^self._compileModule[$aName]
    }
    $result[$self.modules.[$aName].object]
  }{
     ^throw[model.chain.module.not.found;Не найден модуль "$aName" в объекте класса "$this.CLASS_NAME".]
   }

@_compileModule[aName]
  $lModule[$self.modules.[$aName]]
  ^if(def $lModule.package){
    ^use[$lModule.package]
  }
  $lModule.object[^reflection:create[$lModule.className;$lModule.constructor;^self._makeModuleArgs[$lModule.args]]]

@_makeModuleArgs[aArgs]
  $result[^hash::create[$aArgs]]
  ^self._exportFields.foreach[lField;lVarName]{
    ^if(!^result.contains[$lField]){
      $result.[$lField][^if(def $lVarName){$this.[$lVarName]}{$this.[$lField]}]
    }
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfAssert

## Ассерты. Статический класс.

@OPTIONS
locals
static

@auto[]
  $self._isEnabled(true)
  $self._exceptionName[assert.fail]
  $self._passExceptionName[assert.pass]

@GET_enabled[]
  $result($self._isEnabled)

@SET_enabled[aValue]
  $self._isEnabled($aValue)

@isTrue[aCondition;aComment][result]
  ^if($enabled && !$aCondition){
    ^throw[$self._exceptionName;isTrue;^if(def $aComment){$aComment}{Assertion failed exception.}]
  }

@isFalse[aCondition;aComment][result]
  ^if($enabled && $aCondition){
    ^throw[$self._exceptionName;isFalse;^if(def $aComment){$aComment}{Assertion failed exception.}]
  }

@fail[aComment][result]
  ^if($enabled){
    $aComment[^switch[$aComment.CLASS_NAME]{
      ^case[int;double;string]{$aComment}
      ^case[date]{^aComment.sql-string[]}
      ^case[DEFAULT]{^json:string[$aComment;$.indent(true)]}
    }]
    ^throw[$self._exceptionName;Fail;^if(def $aComment){$aComment}{Assertion failed exception.}]
  }

@failIf[aCondition;aComment]
  $result[^if($aCondition){^self.fail[$aComment]}]

@pass[aComment][result]
  ^if($enabled){
    ^throw[$self._passExceptionName;Pass;^if(def $aComment){$aComment}{Assertion pass exception.}]
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfString

## Функции обработки строк.

@OPTIONS
locals
static

@auto[]
  $self.__pfString__[
    $.classDefRegex[^regex::create[^^([^^@:]*)(?:@([^^:]+))?(?::+(.+))?^$]]
  ]

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

@rsplit[text;regex;options]
## Разбивает строку по регулярным выражениям
## options:    l — разбить слева направо (по-умолчанию);
##             r — разбить справа налево;
##             h — сформировать безымянную таблицу где части исходной строки
##                 помещаются горизонтально;
##             v — сформировать таблицу со столбцом piece, где части исходной строки
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
## substr — символ или набор символов до которого нужно отрезать строку слева
  $substr[^taint[regex][$substr]]
  ^if(def $str && def $substr && ^str.match[$substr]){
    $result[^str.match[^^(.*?)${substr}.*?^$][]{$match.1}]
  }{
    $result[$str]
  }

@right[str;substr]
## substr — символ или набор символов до которого нужно отрезать строку слева
  $substr[^taint[regex][$substr]]
  ^if(def $str && def $substr && ^str.match[$substr]){
    $result[^str.match[^^.*?${substr}(.*?)^$][]{$match.1}]
  }{
    $result[$str]
  }

@middle[str;left;right]
  ^if(def $str && def $left && def $right){
    $result[^self.left[$str;$left]]
    $result[^self.right[$str;$right]]
  }{
    $result[$str]
  }

@numberFormat[sNumber;sThousandDivider;sDecimalDivider;iFracLength]
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
## ^pfString:numberDecline[натуральное число или ноль;именительный падеж;родительный падеж, ед. число;родительный падеж, мн. число]
  ^if($num > 10 && (($num % 100) \ 10) == 1){
    $result[$genitive_plural]
  }{
    ^switch($num % 10){
      ^case(1){$result[$nominative]}
      ^case(2;3;4){$result[$genitive_singular]}
      ^case(5;6;7;8;9;0){$result[$genitive_plural]}
    }
  }

@parseURL[aURL;aOptions]
## Разбирает url
## aOptions.skipAuth(false) — не парсить юзернейм и пароль. Хак, для случая,
## когда в get-параметрах передадут имейл.
## TODO: Примитивный разбор url регулярками в parseURL надо менять!
## result[$.protocol $.user $.password $.host $.port $.path $.options $.nameless $.url $.hash]
## result.options — таблица со столбцом piece
  $result[^hash::create[]]
  ^if(def $aURL){
    $lMatches[^aURL.match[
       ^^
       (?:([a-zA-Z\-0-9]+?)\:(?://)?)?   # 1 — protocol
       ^if(!^aOptions.skipAuth.bool(false)){
         (?:(\S+?)(?:\:(\S+?))?@)?       # 2 — user, 3 — password
       }{
         ()()
       }
       (?:([a-z0-9\-\.]*?[a-z0-9]))      # 4 — host
       (?:\:(\d+))?                      # 5 — port
       (/[^^\s\?]*)?                     # 6 — path
       (?:\?(\S*?))?                     # 7 — options
       (?:\#(\S*))?                      # 8 — hash (#)
       ^$
    ][xi]]
    ^if($lMatches){
      $result.protocol[$lMatches.1]
      $result.user[$lMatches.2]
      $result.password[$lMatches.3]

      $result.host[$lMatches.4]
      $result.port[$lMatches.5]
      $result.netloc[$lMatches.4^if(def $lMatches.5){:$lMatches.5}]
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
## В дополнение к парсеровским типам форматирования понимает тип "s" — строковое представление значения.
## Если тип не указан, то он соответствует строковому.
   $result[^aString.match[(?<!\\)(%\((\S+?)\)((?:\d+(?:\.\d+)?)?([sudfxXo]{1})?))][g]{^if(^aValues.contains[$match.2]){^if(!def $match.4 || $match.4 eq "s"){$aValues.[$match.2]}{^eval($aValues.[$match.2])[%$match.3]}}{}}]
   $result[^result.match[\\(.)][g]{^self._processEscapedSymbol[$match.1]}]

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

@dec2bin[iNum;iLength]
## Преобразует число в двоичную строку. 5 -> '101'
  $i(1 << (^iLength.int(24)-1))
  $result[^while($i>=1){^if($iNum & $i){1}{0}$i($i >> 1)}]

@levenshteinDistance[aStr1;aStr2]
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


@parseClassDef[aClassDef] -> [$.className $.constructor $.package $.classDef]
## Метод может быть вызван из других классов для разбора пути к пакетам.
  $aClassDef[^aClassDef.trim[]]
  $result[$.classDef[$aClassDef]]
  ^aClassDef.match[$self.__pfString__.classDefRegex][]{
    $result.constructor[^if(def $match.3){$match.3}{create}]
    ^if(def $match.2){
      $result.className[$match.2]
    }{
       $result.className[^file:justname[$match.1]]
     }
    $result.package[^if($match.1 ne $result.className){$match.1}]
  }

#--------------------------------------------------------------------------------------------------

@CLASS
pfValidate

## Класс для проверки данных на различные условия.

@OPTIONS
locals

@auto[]
  $self.emptyStringRegex[\s+]
  $self.alphaNumericRegexp[[\p{L}\p{Nd}_]+]
  $self.slugRegex[[\p{L}\p{Nd}_-]+]
  $self.onlyLettersRegex[\p{L}+]
  $self.onlyDigitsRegex[\p{Nd}+]
  $self.hexDecimalRegex[(?:[0-9A-Fa-f]{2})+]
# https://www.icann.org/en/system/files/files/idna-protocol-2003-2008.txt
# 0030-2a6d6
  $self.unicodeLetters[\x{00a1}-\x{ffff}]

  $self.ip4AddressRegex[(25[0-5]|2[0-4]\d|[0-1]?\d?\d)(\.(25[0-5]|2[0-4]\d|[0-1]?\d?\d)){3}]
  $self.ip6AddressRegex[\[[0-9a-f:.]+\]]
  $self.hostnameRegex[[a-z0-9$self.unicodeLetters](?:[a-z0-9${self.unicodeLetters}-]{0,61}[a-z0-9$self.unicodeLetters])?]
  $self.domainRegex[(?:\.(?!-)[a-z0-9${self.unicodeLetters}-]{1,63}(?<!-))*]
  $self.TLDRegex[^regex::create[
    \.                                       # dot
    (?!-)                                    # can't start with a dash
    (?:[a-z0-9${self.unicodeLetters}-]{2,63} # domain label
    |xn--[a-z0-9]{1,59})                     # or punycode label
    (?<!-)                                   # can't end with a dash
    \.?                                      # may have a trailing dot
  ][x]]
  $self.TLDRegex[^taint[as-is;$self.TLDRegex.pattern]]
  $self.hostRegex[(?:${self.hostnameRegex}${self.domainRegex}${self.TLDRegex}|localhost)]

  $self.validURLRegex[^regex::create[
    (?:(?:[a-z0-9.+-]*):)?// # scheme
    (
      (?:\S+(?::\S*)?@)?     # user:pass authentication
      (?:$self.ip4AddressRegex|$self.ip6AddressRegex|$self.hostRegex)
      (?::\d{2,5})?          # port
    )
    (?:[/?#][^^\s]*)?        # resource path
  ][x]]
  $self.validEmailRegex[^regex::create[
    (?:
      [-!\#^$%&'*+/=?^^_`{}|~0-9A-Za-z$self.unicodeLetters]+(?:\.[-!\#^$%&'*+/=?^^_`{}|~0-9A-Za-z$self.unicodeLetters]+)*
      |"(?:[\001-\010\013\014\016-\037!\#-\[\]-\177]|\\[\001-011\013\014\016-\177])*" # quoted-string
    )
    @(?i:$self.ip4AddressRegex|$self.ip6AddressRegex|$self.hostRegex)                 # domain
  ][x]]
  $self.validURLRegex[^taint[as-is;$self.validURLRegex.pattern]]
  $self.validEmailRegex[^taint[as-is;$self.validEmailRegex.pattern]]

@create[]
  $result[]

@isEmpty[aString]
## Строка пустая или содержит только пробельные символы.
  $result(!def $aString || ^aString.match[^^$self.emptyStringRegex^$][n])

@isNotEmpty[aString]
## Строка не пустая.
  $result(!^self.isEmpty[$aString])

@isAlphaNumeric[aString]
## Строка содержит только буквы, цифры и знак подчеркивания.
  $result(def $aString && ^aString.match[^^$self.alphaNumericRegexp^$][n])

@isSlug[aString]
## Строка содержит только буквы, цифры, знак подчеркивания и дефис.
  $result(def $aString && ^aString.match[^^$self.slugRegex^$][n])

@isLowerCase[aString]
## Строка содержит буквы только нижнего регистра.
  $result(def $aString && ^aString.lower[] eq $aString)

@isUpperCase[aString]
## Строка содержит буквы только верхнего регистра.
  $result(def $aString && ^aString.upper[] eq $aString)

@isOnlyLetters[aString]
## Строка содержит только буквы.
## Проверяются только буквы.
  $result(def $aString && ^aString.match[^^$self.onlyLettersRegex^$][n])

@isOnlyDigits[aString]
## Строка содержжит только цифры.
  $result(def $aString && ^aString.match[^^$self.onlyDigitsRegex^$][n])

@isHEXDecimal[aString]
## Строка содержит шестнадцатиричное число (парами!).
## Пары символов [0-9A-F] (без учета регистра).
  $result(def $aString && ^aString.match[^^$self.hexDecimalRegex^$][n])

@isValidDecimal[aString;aMaxDigits;aDecimalPlaces]
## Число содежит вещественное число.
## aMaxDigits(12) — максимальное количество цифр в числе
## aDecimalPlaces(2) — Максимальное количество символов после точки
  $result(def $aString && ^aString.match[^^[+\-]?\d{1,^eval(^aMaxDigits.int(12)-^aDecimalPlaces.int(2))}(?:\.\d{^aDecimalPlaces.int(2)})?^$][n])

@isValidIPV4Address[aString]
## Строка содержит корректный ip-адрес
  $result(def $aString && ^aString.match[^^$self.ip4AddressRegex^$][n])

@isValidEmail[aString]
## Строка содержит корректный e-mail.
  $result(def $aString && ^aString.match[^^$self.validEmailRegex^$][xn])

@isValidURL[aString;aOptions]
## Строка содержит синтаксически-правильный URL.
## aOptions.onlyHTTP(false) — строка может содержать только URL с протоколом HTTP
  $lMatch[^aString.match[^^$self.validURLRegex^$][xi]]
  $result(def $aString && $lMatch && ^lMatch.1.length[] <= 253)
  ^if($result && ^aOptions.onlyHTTP.bool(false)){
    $result(^aString.left(7) eq 'http://')
  }

@isExistingURL[aString]
## Строка содержит работающий http-url.
  $result(false)
  ^if(^self.isValidURL[$aString]){
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

@isWellFormedXML[aString]
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
  $result(def $aString && ^self.isWellFormedXML[<?xml version="1.0" encoding="$request:charset" ?>
    <root>$aString</root>
  ])

@isValidANSIDatetime[aString]
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

@CLASS
pfCFile

## Реализует обертку вокруг класса curl с интерфейсом, близким к встроенному классу file.

@OPTIONS
locals


@auto[]
  $self._curlSessionsCnt(0)

  $self._baseVars[
    $.name[]
    $.content-type[]
    $.charset[]
    $.response-charset[]

    $.verbose[$.option[verbose] $.type[int] $.default(0)]
    $.stderr[$.option[stderr]]

#   Connection
    $.follow-location[$.option[followlocation] $.type[int] $.default(0)]
    $.max-redirs[$.option[maxredirs] $.type[int] $.default(-1)]
    $.post-redir[$.option[postredir]]
    $.autoreferer[$.option[autoreferer] $.type[int] $.default(0)]
    $.unrestricted-auth[$.option[unrestricted_auth] $.type[int] $.default(0)]
    $.encoding[$.option[encoding]]

#   Proxies
    $.proxy-host[$.option[proxy]]
    $.proxy-port[$.option[proxyport]]
    $.proxy-type[$.option[proxytype] $.type[int] $.default(0)]

#   Headers
    $.headers[$.option[httpheader]]
    $.cookiesession[$.option[cookiesession] $.type[int] $.default(1)]
    $.user-agent[$.option[useragent]]
    $.referer[$.option[referer]]

#   POST body
    $.body[$.option[postfields]]

#   SSL options
    $.ssl-cert[$.option[sslcert]]
    $.ssl-certtype[$.option[sslcerttype]]
    $.ssl-key[$.option[sslkey]]
    $.ssl-keytype[$.option[sslkeytype]]
    $.ssl-keypasswd[$.option[keypasswd]]
    $.ssl-issuercert[$.option[issuercert]]
    $.ssl-crlfile[$.option[crlfile]]
    $.ssl-cainfo[$.option[cainfo]]
    $.ssl-capath[$.option[capath]]
    $.ssl-cipher-list[$.option[ssl_cipher_list]]
    $.ssl-sessionid-cache[$.option[ssl_sessionid_cache] $.type[int] $.default(0)]
  ]

@GET_version[]
  $result[^curl:version[]]

@load[aMode;aURL;aOptions]
  ^if(!def $aOptions || $aOptions is string){$aOptions[^hash::create[]]}
    ^try{
      $result[^curl:load[^self._makeCurlOptions[$aMode;$aURL;$aOptions]]]
    }{
       ^switch[$exception.type]{
         ^case[curl.host]{$exception.handled(true) ^throw[http.host;$exception.source;$exception.comment]}
         ^case[curl.timeout]{$exception.handled(true) ^throw[http.timeout;$exception.source;$exception.comment]}
         ^case[curl.connect]{$exception.handled(true) ^throw[http.connect;$exception.source;$exception.comment]}
         ^case[curl.status]{$exception.handled(true) ^throw[http.status;$exception.source;$exception.comment]}
       }
     }

@static:session[aCode]
## Организует сессию для запроса
  ^self._curlSessionsCnt.inc[]
  $result[^curl:session{$aCode}]
  ^self._curlSessionsCnt.dec[]

@static:options[aOptions]
## Задает опции для libcurl, но в формате, поддерживаемом функцией load (вызов curl:options)
## Можно вызывать только внутри сессии
  ^if(!$self._curlSessionsCnt){^throw[cfile.options;Вызов метода options вне session.]}
  ^curl:options[^self._makeCurlOptions[;;$aOptions]]
  $result[]

@_makeCurlOptions[aMode;aURL;aOptions]
## Формирует параметры для curl:load (curl:options)
  $result[^hash::create[]]
  ^if(!def $aOptions || $aOptions is string){$aOptions[^hash::create[]]}

  ^if(def $aURL){$result.url[$aURL]}
  ^if(def $aMode){
    ^if(!($aMode eq "text" || $aMode eq "binary")){^throw[cfile.mode;Mode must be "text" or "binary".]}
    $result.mode[$aMode]
  }

# Connection
  $result.timeout(^aOptions.timeout.int(2))
  ^if(!^aOptions.compressed.bool(true)){$result.encoding[identity]}{$result.encoding[]}

  $result.failonerror(!^aOptions.any-status.int(false))

# Задаем "простые" опции.
  ^self._baseVars.foreach[k;v]{
    ^if(^aOptions.contains[$k]){
      ^if($v is hash){
        ^switch[$v.type]{
          ^case[DEFAULT]{
            $result.[$v.option][^if(def $aOptions.[$k]){$aOptions.[$k]}{$v.default}]
          }
          ^case[int;double]{
            $result.[$v.option](^if(def $aOptions.[$k])($aOptions.[$k])($v.default))
          }
        }
      }{
         $result.[$k][$aOptions.[$k]]
       }
    }
  }

# Auth (Basic)
  ^if(def $aOptions.user){
    $result.httpauth(1)
    $result.userpwd[${aOptions.user}:$aOptions.password]
  }

# Method
  ^if(^aOptions.contains[method]){
    ^switch[^aOptions.method.upper[]]{
      ^case[;GET]{$result.httpget(1)}
      ^case[POST]{$result.post(1)}
      ^case[HEAD]{$result.nobody(1)}
      ^case[DEFAULT]{$result.customrequest[^aOptions.method.upper[]]}
    }
  }

# Headers
  ^if(def $aOptions.cookies && $aOptions.cookies is hash){
    $result.cookie[^aOptions.cookies.foreach[k;v]{^taint[uri][$k]=^taint[uri][$v]^;}]
  }

# Form's
  ^if(^aOptions.contains[form]){
    $lForm[^hash::create[$aOptions.form]]
    ^if($lForm){
      ^switch[$aOptions.enctype]{
        ^case[;application/x-www-form-urlencoded]{
          ^switch[^aOptions.method.upper[]]{
            ^case[;GET;HEAD;DELETE]{
              $result.url[$result.url^if(^result.url.pos[?] >= 0){&}{?}^self._formUrlencode[$lForm]]
            }
            ^case[POST]{
              $result.postfields[^self._formUrlencode[$lForm]]
            }
          }
        }
        ^case[multipart/form-data]{
          $result.httppost[$lForm]
        }
        ^case[DEFAULT]{
          ^throw[cfile.options;Неизвестный enctype: "$aOptions.enctype".]
        }
      }
    }{
       $result.postfields[]
       $result.httppost[]
     }
  }

# Ranges
  ^if(def $aOptions.limit || def $aOptions.offset){
    $result.range[^aOptions.offset.int(0)-^if(def $aOptions.limit){^eval(^aOptions.offset.int(0) + ^aOptions.limit.int[] - 1)}]
  }

# SSL options
  ^if(^aOptions.contains[ssl-verifypeer]){
    $result.ssl_verifypeer(^aOptions.ssl-verifypeer.int(0))
  }
  ^if(^aOptions.contains[ssl-verifyhost]){
    $result.ssl_verifyhost(^aOptions.ssl-verifyhost.int(0))
  }

@_formUrlencode[aForm;aSeparator]
  $result[^aForm.foreach[k;v]{^switch[$v.CLASS_NAME]{
      ^case[table]{^self._tableUrlencode[^taint[uri][$k];$v;$aSeparator]}
      ^case[file]{^taint[uri][$k]=^taint[uri][$v.text]}
      ^case[string;int;double;void]{^taint[uri][$k]=^taint[uri][$v]}
      ^case[bool]{^taint[uri][$k]=^v.int[]}
      ^case[date]{^taint[uri][$k]=^taint[uri][^v.sql-string[]]}
      ^case[DEFAULT]{^throw[cfile.options;Невозможно закодировать параметр $k типа ${v.CLASS_NAME}.]}
    }}[^if(def $aSeparator){$aSeparator}{&}]]

@_tableUrlencode[aName;aTable;aSeparator]
  $lFields[^aTable.columns[]]
  $lFieldName[^if($lFields){$lFields.column}{0}]
  $result[^aTable.menu{$aName=^taint[uri][$aTable.[$lFieldName]]}[^if(def $aSeparator){$aSeparator}{&}]]

#--------------------------------------------------------------------------------------------------

@CLASS
pfRuntime

## Статический класс для управления памятью, отладки и профилирования кода.

@OPTIONS
locals
static

@auto[]
  $self._memoryLimit(4096)
  $self._lastMemorySize($status:memory.used)
  $self._compactsCount(0)
  $self._maxMemoryUsage(0)

  $self._profiled[$.last[] $.all[^hash::create[]]]
# Нужно ли накапливать статистику профилировщика
  $self._enableProfilerLog(true)

@GET_memoryLimit[]
  $result($self._memoryLimit)

@SET_memoryLimit[aMemoryLimit]
  $self._memoryLimit($aMemoryLimit)

@GET_compactsCount[]
  $result($self._compactsCount)

@GET_maxMemoryUsage[]
  $result(^if($self._maxMemoryUsage > $status:memory.used){$self._maxMemoryUsage}{$status:memory.used})

@GET_profiled[]
  $result[$self._profiled]

@GET_enableProfilerLog[]
  $result($self._enableProfilerLog)

@SET_enableProfilerLog[aCond]
  $self._enableProfilerLog($aCond)

@compact[aOptions]
## Выполняет сборку мусора, если c момента последней сборки мусора было выделено
## больше $memoryLimit килобайт.
## aOptions.isForce(false)
  $result[]
  ^if($self._maxMemoryUsage < $status:memory.used){
    $self._maxMemoryUsage($status:memory.used)
  }
  ^if(!($aOptions is hash)){$aOptions[^hash::create[]]}
  ^if(^aOptions.isForce.bool(false) || ($status:memory.used - $self._lastMemorySize) > $memoryLimit){
     ^memory:compact[]
     $self._lastMemorySize($status:memory.used)
     ^self._compactsCount.inc[]
  }

@resources[]
## Возвращает хеш с информацией о времени и памяти, затраченных на данный момент
  ^if($self._maxMemoryUsage < $status:memory.used){
    $self._maxMemoryUsage($status:memory.used)
  }
  $result[
    $.time($status:rusage.tv_sec + $status:rusage.tv_usec/1000000.0)
    $.utime($status:rusage.utime)
    $.stime($status:rusage.stime)

    $.allocated($status:memory.ever_allocated_since_start)
    $.allocatedSinceCompact($status:memory.ever_allocated_since_start)
    $.used($status:memory.used)
    $.free($status:memory.free)
    $.maxMemoryUsage($self._maxMemoryUsage)

    $.compacts($self.compactsCount)
    $.memoryLimit($self.memoryLimit)
  ]

@profile[aCode;aComment]
## Выполняет код и сохраняет ресурсы, затраченные на его исполнение.
  $lResult[$.before[^self.resources[]] $.comment[$aComment]]
  ^try{
    $result[$aCode]
  }{
#   pass exceptions
  }{
     $lResult.after[^self.resources[]]
     $lResult.time($lResult.after.time - $lResult.before.time)
     $lResult.utime($lResult.after.utime - $lResult.before.utime)
     $lResult.stime($lResult.after.stime - $lResult.before.stime)

     $lResult.allocated($lResult.after.allocated - $lResult.before.allocated)
     $lResult.compacts($lResult.after.compacts - $lResult.before.compacts)
     $lResult.used($lResult.after.used - $lResult.before.used)
     $lResult.free($lResult.after.free - $lResult.before.free)

     $self._profiled.last[$lResult]
     ^if($enableProfilerLog){
       $self._profiled.all.[^self._profiled.all._count[]][$lResult]
     }
   }

#--------------------------------------------------------------------------------------------------

@CLASS
pfOS

##  Класс с функциями для работы с ОС (файловые системы и т. п.).

@OPTIONS
locals

@create[]
## Конструктор. Если кому-то понадобится использовать класс динамически.

@getMimeType[aFileName;aDefaultValue]
## Возвращает mime-тип для файла
  $result[^if(def $aDefaultValue){$aDefaultValue}{text/plain}]
  ^if(^MAIN:MIME-TYPES.locate[ext;^file:justext[^aFileName.lower[]]]){
    $result[$MAIN:MIME-TYPES.mime-type]
  }

@tempFile[aPath;aVarName;aCode;aFinallyCode]
## Формирует на время выполнения кода aCode уникальное имя для временного
## файла в папке aPath. После работы кода удаляет временный файл, если он создан.
## Если задан параметр aFinallyCode, то он запускается, даже если произошла ошибка.
  ^pfAssert:isTrue(def $aVarName)[Не задано имя переменной для названия временного файла.]
  ^try{
    $lTempFileName[^aPath.trim[end;/\]/${status:pid}_^math:uid64[].tmp]
    $caller.[$aVarName][$lTempFileName]
    $result[$aCode]
  }{}{
     $aFinallyCode
     ^if(-f $lTempFileName){
       ^file:delete[$lTempFileName]
     }
  }

@hashFile[aFileName;aVarName;aCode]
## Открывает хешфайл с имененм aFileName и выполняет код для работы с этим файлом.
## Файл доступен коду в переменной с именем aVarName.
## После работы выполняет release хешфайла.
  ^pfAssert:isTrue(def $aVarName)[Не задано имя переменной для хешфайла.]
  $lHashfile[^hashfile::open[$aFileName]]
  ^try{
    $caller.[$aVarName][$lHashfile]
    $result[$aCode]
  }{}{
    ^lHashfile.release[]
  }

@absolutePath[aPath;aBasePath]
## Возвращает полный путь к файлу относительно aBasePath[$request:document-root].
  $aPath[^file:fullpath[$aPath]]
  $aPath[^aPath.trim[both;/\]]

  $aBasePath[^if(def $aBasePath){$aBasePath}{$request:document-root}]
  $aBasePath[^aBasePath.trim[both;/\]]

  $lParts[^aPath.split[/]]

# Вычисляем число уровней на которые нам надо подняться
  $lStep(0)
  ^for[i](1;$lParts){
    ^lParts.offset[set]($i - 1)
    ^if($lParts.piece eq ".."){^lStep.inc[]}{^break[]}
  }

  ^if($lStep){
    $lBaseParts[^aBasePath.split[/]]
    $result[/^for[i](1;$lBaseParts-$lStep){^lBaseParts.offset[set]($i - 1)$lBaseParts.piece}[/]/^for[i]($lStep+1;$lParts){^lParts.offset[set]($i - 1)$lParts.piece}[/]]
  }{
     $result[/$aBasePath/$aPath]
   }

@walk[aPath;aVarName;aCode;aSeparator]
## Обходит дерево файлов начиная с aPath и выполняет для каждого найденного файла aCode.
## Имя файла c путем попадает в переменную с именем из aVarName.
## Файлы сортируются по именам.
## Между вызовами aCode вставляется aSeparator.
  ^pfAssert:isTrue(def $aVarName)[Не задано имя переменной для имени файлов.]
  $aPath[^aPath.trim[right;/\]]
  $lFiles[^file:list[$aPath]]
  ^lFiles.sort{$lFiles.name}[asc]
  $result[^if($lFiles && ^aVarName.left(7) eq "caller."){$aSeparator}^lFiles.menu{^process{^$caller.caller.$aVarName^[$aPath/$lFiles.name^]}$aCode^if(-d "$aPath/$lFiles.name"){^self.walk[$aPath/$lFiles.name;caller.$aVarName]{$aCode}[$aSeparator]}}[$aSeparator]]
  ^if(^aVarName.left(7) ne "caller."){$caller.$aVarName[]}

#--------------------------------------------------------------------------------------------------

@CLASS
pfRetry

# Класс для ретраев

@BASE
pfClass

@create[aOptions]
## aOptions.maxAttempts(3) — максимальное число повторов
## aOptions.maxDelay(0) — время задержки между повтороами в секундах. Допустимы дробные значения
## aOptions.retryOnException[string] — ретраить при определенном типе эксепшна
  $self.maxAttempts(^aOptions.maxAttempts.int(3))
  $self.maxDelay(^aOptions.maxDelay.double(0.0))
  $self.retryOnException[$aOptions.retryOnException]

@process[aCode]
  ^for[i](1;$self.maxAttempts){
    ^try{
      ^return[$aCode]
    }{
      ^if($i < $self.maxAttempts && $self.retryOnException is string && def $self.retryOnException){
        ^if($exception.type eq $self.retryOnException){
          $exception.handled(true)
        }
      }($i < $self.maxAttempts){
        $exception.handled(true)
      }
      ^if($exception.handled){
        ^sleep($self.maxDelay)
      }
    }
  }
