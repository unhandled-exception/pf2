#!/usr/bin/env parser3

@USE
pf2/lib/common.p

@main[][locals]
  Test!

  ^curl:session{
    ^curl:options[
      $.verbose(true)
    ]

    $lURL[http://google.com]
    $lURL is ^if(^pfValidate:isValidURL[$lURL]){a valid}{an invalid} URL.
    $lURL is ^if(^pfValidate:isExistingURL[$lURL]){an exist}{a not exist} URL.

    $lURL[https://google.com]
    $lURL is ^if(^pfValidate:isValidURL[$lURL]){a valid}{an invalid} URL.
    $lURL is ^if(^pfValidate:isExistingURL[$lURL]){an exists}{a non exist} URL.

    $lURL is ^if(^pfValidate:isValidURL[$lURL;$.onlyHTTP(true)]){a valid}{an invalid} HTTP URL.
  }

  $lValidURLs[^table::load[nameless;assets/validation/valid_urls.txt]]
  $lInvalidURLs[^table::load[nameless;assets/validation/invalid_urls.txt]]
  $lValidEmails[^table::load[nameless;assets/validation/valid_emails.txt]]
  $lInvalidEmails[^table::load[nameless;assets/validation/invalid_emails.txt]]

  ^lValidURLs.menu{
    $lURL[$lValidURLs.0]
    $lURL is ^if(^pfValidate:isValidURL[$lURL]){a valid URL [OK]}{an invalid URL [error]}.
  }
  ^lInvalidURLs.menu{
    $lURL[$lInvalidURLs.0]
    $lURL is ^if(!^pfValidate:isValidURL[$lURL]){an invalid URL [OK]}{a valid URL [error]}.
  }
  ^lValidEmails.menu{
    $lEmail[$lValidEmails.0]
    $lEmail is ^if(^pfValidate:isValidEmail[$lEmail]){a valid e-mail [OK]}{an invalid e-mail [error]}.
  }
  ^lInvalidEmails.menu{
    $lEmail[$lInvalidEmails.0]
    $lEmail is ^if(!^pfValidate:isValidEmail[$lEmail]){an invalid e-mail [OK]}{a valid e-mail [error]}.
  }

  Finish tests.^#0A

@print_fields[aObj][locals]
  $f[^reflection:fields[$aObj]]
  ^f.foreach[k;v]{
    $k - $v.CLASS_NAME ^if($v is string){— $v}
  }


