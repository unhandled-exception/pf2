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

