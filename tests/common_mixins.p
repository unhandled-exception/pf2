#!../../../cgi-bin/parser3.cgi

@USE
pf2/lib/common.p

@main[][locals]
  ^test_hash_mixin[]

  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }

@test_hash_mixin[][locals]
  Hash mixin test:
  $o[^hash_mixin_class::create[]]
#  ^print_fields[$o]
  ^o.foreach[k;v]{
    $k -> $v.CLASS_NAME
  }

@CLASS
hash_mixin_class

@BASE
pfClass

@create[]
  ^BASE:create[]
  ^pfHashMixin:mixin[$self;$.includeJunctionFields(true)]
  $field[value]

