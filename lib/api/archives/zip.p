# PF2 Library

@CLASS
pfZipArchiver

## Класс для работы с zip-архивом.
## Обертка над консольными утилитами zip и unzip.
## Умеет получать список файлов в архиве, доставать единичный файл и упаковывать в архив несколько файлов.

@USE
pf2/lib/common.p

@BASE
pfClass

@auto[aFilespec]
  $[__PFZIPARCHIVER_FILESPEC__][^aFilespec.match[^^(^taint[regex][$request:document-root])][][]]

@create[aOptions]
## aOptions.unzipPath[] - путь к unzip
## aOptions.zipPath[] - путь к zip
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]

  $_unzipPath[^if(def $aOptions.unzipPath){$aOptions.unzipPath}{^file:dirname[$__PFZIPARCHIVER_FILESPEC__]/bin/unzip}]
  $_zipPath[^if(def $aOptions.zipPath){$aOptions.zipPath}{^file:dirname[$__PFZIPARCHIVER_FILESPEC__]/bin/zip}]
  ^_cleanLastError[]

@list[aZipFile;aOptions][lExec]
## aOptions.charset[$request:charset]
  ^cleanMethodArgument[]
  ^_cleanLastError[]
  $lExec[^file::exec[$_unzipPath;$.charset[^if(def $aOptions.charset){$aOptions.charset}{$request:charset}];-Z1;^pfOS:absolutePath[$aZipFile]]]
  ^if($lExec.status){
    ^_error(true)[$lExec.status;$lExec.text;$lExec.stderr]
  }
  $result[^table::create[nameless]{$lExec.text}]

@load[aZipFile;aFileName;aOptions]
## aOptions.mode[text]
## aOptions.convertLF(false)
## aOptions.charset[$request:charset]
## aOptions.ignoreCase(false)
  ^cleanMethodArgument[]
  ^_cleanLastError[]
  $lExec[^file::exec[^if($aOptions.mode eq "binary"){binary}{text};$_unzipPath;$.charset[^if(def $aOptions.charset){$aOptions.charset}{$request:charset}];-p;^if(^aOptions.convertLF.bool(false)){-a};^if(^aOptions.ignoreCase.bool(false)){-C};^pfOS:absolutePath[$aZipFile];$aFileName]]
  ^if($lExec.status){
    ^_error(true)[$lExec.status;$lExec.text;$lExec.stderr]
  }
  $result[$lExec]

@test[aZipFile;aOptions]
  ^_cleanLastError[]
  $lExec[^file::exec[$_unzipPath;;-t;^pfOS:absolutePath[$aZipFile]]]
  $result(!$lExec.status)
  ^if(!$result){
    ^_error(false)[$lExec.status;$lExec.text;$lExec.stderr]
  }

@pack[aZipFile;aFiles;aOptions][lFiles;lFullPath;lColumn;lOpt]
## aFiles[string|table]
## aOptions.column[name] - название колонки для тиблицы в aFiles
## aOptions.fullPath(false) - пути к файлам в aFile заданы в формате «от корня»
## aOptions.junkPaths(false) - сохраянть в архиве только имена файлов, без папок
## aOptions.withFolders(false) - создавать в архиве записи для директорий
  ^cleanMethodArgument[]
  ^_cleanLastError[]
  $result[]
  $lFullPath(^aOptions.fullPath.bool(false))
  $lColumn[^if(def $aOptions.column){$aOptions.column}{name}]

  ^switch[$aFiles.CLASS_NAME]{
    ^case[string]{$lFiles[^if($lFullPath){$aFiles}{^pfOS:absolutePath[$aFiles]}]}
    ^case[table]{
      $lFiles[^table::create{file}]
      ^aFiles.menu{
        ^lFiles.append{^if($lFullPath){$aFiles.[$lColumn]}{^pfOS:absolutePath[$aFiles.[$lColumn]]}}
      }
    }
    ^case[DEFAULT]{^throw[pfZipArchiver.create;Список файлов должен быть таблицей или строкой.]}
  }

  $lOpt[^table::create{param}]
  ^if(^aOptions.junkPaths.bool(false)){^lOpt.append{-j}}
  ^if(!^aOptions.withFolders.bool(false)){^lOpt.append{-D}}

  $lExec[^file::exec[$_zipPath;;-q;$lOpt;^pfOS:absolutePath[$aZipFile];$lFiles]]
  ^if($lExec.status){
    ^_error(true)[$lExec.status;$lExec.text;$lExec.stderr]
  }

@unpack[aZipFile;aOptions]
  ^_cleanLastError[]
  $result[]
  ^throw[mega.fail;Не реализовано!]

#----- Private -----

@_cleanLastError[]
  $lastErrorCode[]
  $lastErrorMessage[]

@_error[aThrowException;aCode;aScriptResult;aStdErr]
  $lastErrorCode[$aCode]
  $lastErrorMessage[^if(def $aStdErr){$aStdErr}{$aScriptResult}]
  ^if($aThrowException){
    ^throw[pfZipArchiver.fail;Ошибка при выполнении скрипта ($lastErrorCode);$lastErrorMessage]
  }

