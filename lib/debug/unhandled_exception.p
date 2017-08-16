# PF2 Library

@CLASS
pfUnhandledExceptionDebug

@OPTIONS
locals

@auto[aFileSpec]
  $self.PF_UNHANDLED_EXCEPTION_FOLDER[^file:dirname[$aFileSpec]]

@create[aOptions]
## aOptions.templateFolder — папка с шаблонами. Если не задана, определяем сами
## aOptions.maxSnippetLines(20) — количество строк в снипете. Если 0, то не показываем снипеты
  $aOptions[^hash::create[$aOptions]]
  $self._docRootRegex[^regex::create[^^(?:^taint[regex][$request:document-root])(.+?)^$][]]

  ^if(^aOptions.contains[templateFolder]){
    $self.templateFolder[$aOptions.templateFolder]
  }{
    $self.templateFolder[^self._normalizePath[$self.PF_UNHANDLED_EXCEPTION_FOLDER]/templates]
   }

  $self.template[$self.templateFolder/ue_debug.pt]

  $self._maxSnippetLines(^aOptions.maxSnippetLines.int(20))

# Кешик для файлов с кодом
  $self._snippetFiles[^hash::create[]]

@render[aException;aStack;aOptions]
  $lOptions[
    $.request[^self._getRequest[]]
    $.resources[^self._getResources[]]
  ]
  $lTemplateText[^file::load[text;$self.template]]
  ^process[$self]{^taint[as-is][$lTemplateText.text]}[
    $.main[__main__]
  ]
  $result[^self.__main__[$aException;$aStack;
    $lOptions
  ]]

@_normalizePath[aPath]
## Отрeзает от пути document-root
  $result[$aPath]
  ^result.match[$self._docRootRegex][]{$result[$match.1]}

@_getSnippet[aFile;aLine;aOptions] -> [$.firstLine $.lines]
  $result[]
  ^if($self._maxSnippetLines <= 0){^return[]}
  $lCode[^self._loadFile[$aFile]]
  ^if($lCode is table){
    $aLine(^aLine.int(1))
    $lFrom($aLine - ($self._maxSnippetLines \ 2))
    $lTo($aLine + ($self._maxSnippetLines \ 2))
    $result[
      $.lines[^lCode.select(^lCode.line[] >= $lFrom && ^lCode.line[] <= $lTo)]
      $.firstLine(^if($lFrom < 1){1}{$lFrom})
      $.line($aLine)
    ]
  }

@_loadFile[aFile]
  $result[]
  $aFile[^self._normalizePath[$aFile]]
  ^if(^self._snippetFiles.contains[$aFile]){
    $result[$self._snippetFiles.[$aFile]]
  }(-f $aFile){
    $result[^file::load[text;$aFile]]
    $result[^result.text.split[^#0A;v;line]]
    $self._snippetFiles.[$aFile][$result]
  }

@_getRequest[] -> [hash]
  $result[^hash::create[]]
  $result.host[$env:SERVER_NAME]
  $result.uri[$request:uri]
  $result.scheme[http^if(^env:HTTPS.lower[] eq "on"){s}]
  $result.url[${result.scheme}://${result.host}${result.uri}]
  $result.method[^request:method.upper[]]

  $result.parserVersion[$env:PARSER_VERSION]
  $result.remoteIP[$env:REMOTE_ADDR]
  $result.userAgent[$env:HTTP_USER_AGENT]

@_getResources[]
## Возвращает хеш с информацией о времени и памяти, затраченных на данный момент
  $result[
    $.time($status:rusage.tv_sec + $status:rusage.tv_usec/1000000.0)
    $.utime($status:rusage.utime)
    $.stime($status:rusage.stime)
    $.allocated($status:memory.ever_allocated_since_start)
    $.allocatedSinceCompact($status:memory.ever_allocated_since_start)
    $.used($status:memory.used)
    $.free($status:memory.free)
    $.memoryLimit($self.memoryLimit)
  ]
