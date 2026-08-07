# AWS provider 6.x does not expose a native Lambda Network Connector resource.
# CloudFormation supports AWS::Lambda::NetworkConnector and returns its ARN and
# current state, so the generic stack resource provides declarative lifecycle
# without introducing the awscc provider.
#
# The identity applying this stack must have iam:PassRole for the regional
# operator role with iam:PassedToService restricted to lambda.amazonaws.com.
resource "aws_cloudformation_stack" "connector" {
  #checkov:skip=CKV_AWS_124:The stack owns one connector resource and CloudFormation event history plus CloudTrail provide deployment auditability; a dedicated SNS topic would expand this helper's contract without an operational subscriber.
  for_each = var.network_connectors

  name = local.connector_stack_names[each.key]

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "Forge Lambda MicroVM VPC egress connector ${each.value.name}"
    Resources = {
      Connector = {
        Type = "AWS::Lambda::NetworkConnector"
        Properties = {
          Name         = each.value.name
          OperatorRole = aws_iam_role.operator.arn
          Configuration = {
            VpcEgressConfiguration = {
              SubnetIds                      = sort(tolist(each.value.subnet_ids))
              SecurityGroupIds               = [aws_security_group.connector[each.key].id]
              NetworkProtocol                = each.value.network_protocol
              AssociatedComputeResourceTypes = ["MicroVm"]
            }
          }
          Tags = [
            for key in sort(keys(local.all_security_tags)) : {
              Key   = key
              Value = local.all_security_tags[key]
            }
          ]
        }
      }
    }
    Outputs = {
      ConnectorArn = {
        Description = "Lambda Network Connector ARN"
        Value       = { Ref = "Connector" }
      }
      ConnectorState = {
        Description = "Lambda Network Connector state"
        Value       = { "Fn::GetAtt" = ["Connector", "State"] }
      }
    }
  })

  timeout_in_minutes = 30
  tags               = local.all_security_tags

  lifecycle {
    precondition {
      condition = alltrue([
        for subnet_id in each.value.subnet_ids :
        data.aws_subnet.selected["${each.key}/${subnet_id}"].vpc_id == each.value.vpc_id
      ])
      error_message = "Every subnet in network_connectors[${each.key}] must belong to its configured vpc_id."
    }
  }

  depends_on = [
    time_sleep.operator_role_propagation,
    aws_vpc_security_group_egress_rule.ipv4,
    aws_vpc_security_group_egress_rule.ipv6,
  ]
}
