locals {

  resource_tags = [
    for k, v in local.all_security_tags : {
      Key   = k
      Value = v
    }
  ]

}
