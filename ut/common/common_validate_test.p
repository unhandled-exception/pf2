@USE
pf2/lib/common.p

@CLASS
TestPFCommonValidate

@BASE
pfTestCase

@OPTIONS
locals

@testIsValidURL_valid[]
  $lURLs[^table::load[nameless;common/testdata/validation/valid_urls.txt]]
  ^lURLs.menu{
    $lURL[$lURLs.0]
    ^self.assertTrue(^pfValidate:isValidURL[$lURL]){A valid url ($lURL) was invalidated}
  }

@testIsValidURL_invalid[]
  $lURLs[^table::load[nameless;common/testdata/validation/invalid_urls.txt]]
  ^lURLs.menu{
    $lURL[$lURLs.0]
    ^self.assertFalse(^pfValidate:isValidURL[$lURL]){An invalid ($lURL) was validated}
  }

@testIsValidEmail_valid[]
  $lEmails[^table::load[nameless;common/testdata/validation/valid_emails.txt]]
  ^lEmails.menu{
    $lEmail[$lEmails.0]
    ^self.assertTrue(^pfValidate:isValidEmail[$lEmail]){A valid email ($lEmail) was invalidated}
  }

@testIsValidEmail_invalid[]
  $lEmails[^table::load[nameless;common/testdata/validation/invalid_emails.txt]]
  ^lEmails.menu{
    $lEmail[$lEmails.0]
    ^self.assertFalse(^pfValidate:isValidEmail[$lEmail]){A invalid email ($lEmail) was validated}
  }
