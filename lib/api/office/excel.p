# PF library
@CLASS
pfTableToXLS

## Класс для генерации xml-таблицы для Экселя.

@USE
pf2/lib/common.p

@BASE
pfClass

@create[aOptions]
## aOptions.charset[$response:charset]
  ^cleanMethodArgument[]
  ^BASE:create[$aOptions]
  $_charset[^if(def $aOptions.charset){$aOptions.charset}{$response:charset}]

@GET_contentType[]
  $result[application/vnd.ms-excel]

@convert[aData;aOptions][locals]
## aData[table]
## aOptions.fields[$.field[name]] — список полей из таблицы с названием колонок.
##                                  Если не задан берем из таблицы.
## aOptions.skipHeader(false) — не генерировать заголовок.
## aOptions.charset[$_charset]
  ^cleanMethodArgument[]
  ^pfAssert:isTrue($aData is table)[Параметр aData должен быть таблицей.]
  $lCharset[^if(def $aOptions.charset){$aOptions.charset}{$_charset}]
  $lFields[^if(^aOptions.contains[fields]){$aOptions.fields}{^_makeFields[$aData]}]

  $result[^_template[$lCharset]{
    $i(1)
    ^lFields.foreach[k;v]{
      <Column ss:Index="$i" ss:AutoFitWidth="1" ss:Width="110" />
      ^i.inc[]
    }
    ^if(!^aOptions.skipHeader.bool(false)){
      <Row>
      ^lFields.foreach[k;v]{
        <Cell><Data ss:Type="String">^taint[$v]</Data></Cell>
      }
      </Row>
    }
    ^aData.foreach[k;v]{
      <Row>
        ^lFields.foreach[n;m]{
          <Cell><Data ss:Type="String">^taint[$v.[$n]]</Data></Cell>
        }
      </Row>
      ^pfRuntime:compact[]
    }
  }]

@_makeFields[aData][locals]
  $result[^hash::create[]]
  $lFields[^aData.columns[field]]
  ^lFields.foreach[k;v]{
    $result.[$v.field][$v.field]
  }

@_template[aCharset;aCode][locals]
$result[<?xml version="1.0" encoding="^taint[$aCharset]"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
xmlns:o="urn:schemas-microsoft-com:office:office"
xmlns:x="urn:schemas-microsoft-com:office:excel"
xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
xmlns:html="http://www.w3.org/TR/REC-html40">
<Worksheet ss:Name="Table1">
<Table>
  $aCode
</Table>
</Worksheet>
</Workbook>
]