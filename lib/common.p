# PF2 Library
# Module: common.p

@auto[aFilespec]
  $MAIN:[__PFROOT__][^aFilespec.match[^^(?:^taint[regex][$request:document-root])(.*?)(/lib/common.p)^$][]{$match.1}]


@CLASS
pfClass

## Базовый предок классов библиотеки

@create[aOptions]
## Empty constructor
  $result[]

#----- Properties -----

@GET_isDynamic[]
## Возвращает true, если класс создан динамически
  $result(^reflection:dynamical[])

@GET_isStatic[]
## Возвращает true, если класс создан статически
  $result(!^reflection:dynamical[])

#----- Public -----

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

@equals[aObject]
## Возвращает true, если текущий объект равен aObject.
  $result(false)

@typeOf[aValue][lDone]
## Возвращает строку с типом переменной aValue
  ^unsafe{
    ^if(def $aValue.CLASS_NAME){
      $result[$aValue.CLASS_NAME]
    }
  }

  ^if(!def $result){
	  $result[^switch(true){
      ^case($aValue is "string"){string}
      ^case($aValue is "int"){int}
      ^case($aValue is "double"){double}
      ^case($aValue is "date"){date}
      ^case($aValue is "hash"){hash}
      ^case($aValue is "table"){table}
      ^case($aValue is "bool"){bool}
      ^case($aValue is "image"){image}
      ^case($aValue is "file"){file}
      ^case($aValue is "xnode"){xnode}
      ^case($aValue is "xdoc"){xdoc}
      ^case($aValue is "pfClass"){pfClass}
      ^case[DEFAULT]{}
    }]
  }

@int[aDefault]
## Перобразует объект в int.
  $result(^unsafe{^GET[int]}{^if(def $aDefault){$aDefault}{^throw[$CLASS_NAME;Невозможно преобразовать объект класса $CLASS_NAME в int.]}})

@double[aDefault]
## Перобразует объект в double.
  $result(^unsafe{^GET[double]}{^if(def $aDefault){$aDefault}{^throw[$CLASS_NAME;Невозможно преобразовать объект класса $CLASS_NAME в double.]}})

@bool[aDefault]
## Перобразует объект в bool.
  $result(^unsafe{^GET[bool]}{^if(def $aDefault){$aDefault}{^throw[$CLASS_NAME;Невозможно преобразовать объект класса $CLASS_NAME в bool.]}})

@contains[aName][lFields]
## Проверяет есть ли у объекта поле с именем aName.
  $lFields[^reflection:fields[^if(^reflection:dynamical[]){$self}{$CLASS}]]
  $result(^lFields.contains[$aName])

@foreach[aKeyName;aValueName;aCode;aSeparator][lFields;lKey;lValue]
## Обходит все поля объекта.
  $lFields[^reflection:fields[^if(^reflection:dynamical[]){$self}{$CLASS}]]
  $result[^lFields.foreach[lKey;lValue]{$caller.[$aKeyName][$lKey]$caller.[$aValueName][$lValue]$aCode}[$aSeparator]]

@alias[aName;aMethod]
## Создает алиас для метода.
  ^pfAssert:isTrue($aMethod is junction)[Переменная aMethod должна содержать ссылку на функцию.]
  $self.[$aName][$aMethod]
  $result[]

@try-finally[aCode;aCatchCode;aFinallyCode][lFinallyProcessed]
## Оператор try-catch-finally. Гарантированно выполняет блок
## finally даже если в коде или обработчике ошибок произошло исключение.
## Блок finally можно опустить.
  $lFinallyProcessed(false)
  $result[^try{^try{$aCode}{$aCatchCode}}{$lFinallyProcessed(true)$aFinallyCode}^if(!$lFinallyProcessed){$aFinallyCode}]

@unsafe[aCode;aCatchCode]
## Выполняет код и принудительно обрабатывает все exceptions.
## В случае ошибки может дополнительно выполнить aCatchCode.
  $result[^try{$aCode}{$exception.handled(true)$aCatchCode}]

@unless[aCond;aFalseCode;aTrueCode]
## if наоборот.
  $result[^if(!$aCond){$aFalseCode}{$aTrueCode}]

#----- Декораторы -----

@decorateMethod[aFunctionName;aDecoratorFunction;aObject][locals]
## Назначает декоратор для метода/функции
## aFunctionName — имя функции, которую мы декорируем
## aDecoratorFunction — ссылка на функцию-декоратор (junction, а не строка с именем)
##   Сигнатура функции-декоратора:
##     @wrap_function[aFunction;aArgs;aOptions]
##       aFunction — ссылка на оригинальную функцию
##       aArgs — аргументы с которыми фнукцию вызвали (аналогично *aArgs)
##       aOptions.object — ссылка на объект, содержащий задекорированную функцию
##       aOptions.functionName — имя задекорированной функции
## aObject — контекст функции, которую мы декорируем (объект или класс; если не задан, то $self)
  $result[]
  $obj[^if(def $aObject){$aObject}{$self}]
  ^if(!($obj.[$aFunctionName] is junction)){^throw[pfClass.decorate.fail;Функция $aFunctionName не найдена.]}
  ^if(!($aDecoratorFunction is junction)){^throw[pfClass.decorate.fail;Фукция-декоратор для $aFunctionName имеет тип $aDecoratroFunction.CLASS_NAME]}
  $wrapperName[DECORATOR_$aFunctionName_^math:uid64[]]
  $obj.[${wrapperName}_FUNCTION][$aDecoratorFunction]
  $obj.[${wrapperName}_ORIGINAL][^reflection:method[$obj;$aFunctionName]]
  ^process[$obj]{@${aFunctionName}[*args]
    ^$result[^^self.[${wrapperName}_FUNCTION][^$self.[${wrapperName}_ORIGINAL]^;^$args^;^$.object[^$self] ^$.functionName[$aFunctionName]]]
  }

@regexpDecorateMethod[aFunctionRegexp;aDecoratorFunction;aObject][locals]
## Декорирует все функции, подпадающие под регулярное выражение.
## aFunctionRegexp — регулярное выражение для поиска функций.
## Остальные параметры аналогично decorateMethod.
  $result[]
  $obj[^if(def $aObject){$aObject}{$self}]
  $m[^reflection:methods[$obj.CLASS_NAME]]
  $lForeach[^reflection:method[$m;foreach]]
  ^lForeach[k;v]{
    ^if(^k.match[$aFunctionRegexp]){
      ^obj.decorateMethod[$k;$aDecoratorFunction;$obj]
    }
  }

#----- Private -----

@_abstractMethod[]
  ^pfAssert:fail[Не реализовано. Вызов абстрактного метода.]

#----- Serialize -----

## Подробности в файле pf/TECHNOTES

#@__asString[]
#@__fromString[aString]
#@__asXML[aOptions]
#@__fromXML[aXML;aOptions]



@CLASS
pfAssert

@OPTIONS
static

#----- Static constructor -----

@auto[]
  $_isEnabled(true)
  $_exceptionName[assert.fail]
  $_passExceptionName[assert.pass]

#----- Properties -----

@GET_enabled[]
  $result($_isEnabled)

@SET_enabled[aValue]
  $_isEnabled($aValue)

#----- Public -----

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

