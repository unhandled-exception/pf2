#!/usr/bin/env parser3

@USE
pf2/lib/api/office/excel.p

@main[][locals]
  Test an axcel table generator.
  $t[^table::create{one	two
value 1	value2
value 3	value4}]

  $e[^pfTableToXLS::create[]]
  ^e.convert[$t]

  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }


