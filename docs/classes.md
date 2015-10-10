Список классов библиотеки
=========================

Автоматически получаем командой в папке lib:
````
find . -name "*.p" -exec grep "@CLASS" -A 1 -H {} \; | awk '$0 !~ /(--|@CLASS)/{split($0, m, "-"); if(mod != m[1]){printf("\n### %s\n", m[1])} print "*", m[2]; mod = m[1]}'
````

### ./common.p
* pfClass
* pfMixin
* pfHashMixin
* pfAssert
* pfString
* pfValidate
* pfCFile
* pfRuntime
* pfOS

### ./net/curl_file.p
* pfCurlFile

### ./api/archives/zip.p
* pfZipArchiver

### ./api/mobile/sms/zagruzka.p
* pfZagruzkaSMSGate

### ./api/office/excel.p
* pfTableToXLS

### ./api/pdf/pdfkit.p
* pfPDFKit

### ./api/qiwi/wallet.p
* pfQiwiWallet

### ./console/console.p
* pfConsole
