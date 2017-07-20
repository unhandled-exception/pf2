#!/usr/bin/env parser3

@USE
pf2/lib/api/pdf/pdfkit.p

@main[][locals]
  Test an axcel table generator.

  $pdfkit[^pfPDFKit::create[]]
  $f[^pdfkit.toPDF[<html><head><meta name="pdfkit-page_size" content="A4"></head><body><p>Hello, world!</body></html>]]
  PDF file length is $f.size bytes.

  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }


