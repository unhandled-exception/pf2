# PF2 Library

@CLASS
pfPDFKit

## Класс-обертка для генерации pdf-файлов через wkhtmltopdf.

@USE
pf2/lib/common.p

@BASE
pfClass

@auto[aFilespec]
  $[__PFPDFKIT_FILESPEC__][^aFilespec.match[^^(^taint[regex][$request:document-root])][][]]

@create[aOptions]
## aOptions.binPath[CLASS_FILESPEC/bin/wkhtmltopdf] — путь к wkhtmltopdf
  ^cleanMethodArgument[]
  ^BASE:create[]

  $_binPath[^if(def $aOptions.binPath){$aOptions.binPath}{^file:dirname[$__PFPDFKIT_FILESPEC__]/bin/wkhtmltopdf}]
  ^pfAssert:isTrue(-f $_binPath){Не найден исполнимый файл "$_binPath".}

  $_stylesheets[^hash::create[]]

  $_options[
    $.quiet(true)
    $.disable_smart_shrinking(false)
    $.page_size[A4]
    $.orientation[Portrait]
    $.margin_top[1.5cm]
    $.margin_right[1.5cm]
    $.margin_bottom[1.5cm]
    $.margin_left[2.5cm]
    $.encoding[$response:charset]
  ]
  ^defProperty[options]

  $_metaPrefix[pdfkit-]
  ^defProperty[metaPrefix]

@toPDF[aSource;aOptions][locals]
## aSource[string|file|hash] — строка, файл или хеш
##    hash: $.fileName[] или $.url
## aOptions.toFile[] — записать результат в файл.
## result[file] — возвращает файл или пустую строку, если задан aOptions.toFile
  $result[]
  ^cleanMethodArgument[]

  ^switch[$aSource.CLASS_NAME]{
    ^case[string]{
      $lText[$aSource]
    }
    ^case[file]{
      $lText[$aSource.text]
    }
    ^case[hash]{
      ^if(def $aSource.fileName){
        $lSourceFile[$aSource.fileName]
        ^pfAssert:isTrue(-f $lSourceFile){${CLASS_NAME}: Не найден файл "$lSourceFile".}
        $lSourceFile[file://${request:document-root}/$lSourceFile]
      }{
         $lSourceFile[$aSource.url]
       }
      ^pfAssert:isTrue(def $lSourceFile){Не задано имя html-файла или адрес страницы.}
    }
  }

  $lDestFile[$aOptions.toFile]
  ^pfAssert:isTrue(-d ^file:dirname[$lDestFile]){${CLASS_NAME}: Необходимо создать папку "^file:dirname[$lDestFile]".}

  $lArgs[^hash::create[$_options]]
  ^if(def $lText){
    ^lArgs.add[^_findOptionsInMeta[$lText]]
    $lText[^_appendStylesheets[$lText]]
  }

  $result[^_exec[^if(def $lSourceFile){$lSourceFile}{-};^if(def $lDestFile){${request:document-root}/$lDestFile}{-};$lArgs;$lText]]
  ^if(def $lDestFile){$result[]}

@appendStylesheet[aStylesheet]
  ^pfAssert:isTrue(-f $aStylesheet){${CLASS_NAME}: Не найдена таблица стилей "$aStylesheet".}
  $_stylesheets.[^eval($_stylesheets + 1)][$aStylesheet]

#----- Private -----

@_exec[aInpFile;aOutFile;aArgs;aStdin][locals]
  $result[^file::exec[binary;$_binPath;$.stdin[$aStdin] $.charset[$aArgs.encoding];^_makeArgs[$aArgs];$aInpFile;$aOutFile]]
  ^if($result.status > 0){
    ^throw[pdfkit.fail;Ошибка в wkhtmltopdf ($result.status);$result.stderr]
  }

@_findOptionsInMeta[aContent][locals]
  $result[^hash::create[]]
# Выкусываем мета-теги
  $lMetas[^aContent.match[
    <\s*(?:meta)\s+(?:
        (?:name\s*(?:=\s*((?:\'[^^\']*\')|(?:\"[^^\"]*\")))?)
        .+?
        (?:content\s*(?:=\s*((?:\'[^^\']*\')|(?:\"[^^\"]*\")))?)
        .+?
    )\/?>
  ][gix]]
# Отбираем только те, которые начинаются с _metaPrefix.
  $lNameRegex[^regex::create[^^['"]^taint[regex][$_metaPrefix]^(.+?)['"]^$][n]]
  ^lMetas.menu{
    ^if(!def $lMetas.1){^continue[]}
    ^lMetas.1.match[$lNameRegex][]{
      $lKey[$match.1]
      $lValue[^lMetas.2.trim[both;'"]]
      $result.[$lKey][$lValue]
    }
  }

@_appendStylesheets[aContent][loclals]
  $result[$aContent]
  ^if($_stylesheets){
    $result[^result.match[(<\/head>)][i]{
      <style>
        ^_stylesheets.foreach[k;v]{
          $lStylesheet[^file::load[text;$v]]
          ^taint[as-is][$lStylesheet.text]
        }
      </style>
      $match.1
    }]
  }

@_makeArgs[aArgs][locals]
  $result[^table::create{arg}]
  $lArgRegex[^regex::create[[^^a-z0-9]][gi]]
  ^aArgs.foreach[k;v]{
    $lKey[^k.match[$lArgRegex][][-]]
    $lVal[^switch[$v.CLASS_NAME]{
      ^case[bool]{^if(!$v){$lKey[]}}
      ^case[DEFAULT]{$v}
    }]
    ^if(def $lKey){
      ^result.append{--$lKey}
      ^if(def $lVal){
        ^result.append{$lVal}
      }
    }
  }
