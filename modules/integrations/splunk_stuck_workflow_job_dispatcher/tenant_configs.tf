resource "aws_ssm_parameter" "tenant_configs" {
  for_each = {
    for index, chunk in local.redelivery_tenant_config_chunks :
    tostring(index) => chunk
  }

  name  = "${local.redelivery_tenant_config_parameter_prefix}/${each.key}"
  type  = "String"
  value = each.value
  tags  = local.all_security_tags
}
