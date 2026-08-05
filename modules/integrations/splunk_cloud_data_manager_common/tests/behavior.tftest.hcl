mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "test"
    }
  }

  mock_data "aws_secretsmanager_secret" {
    defaults = {
      id = "/cicd/common/splunk-cloud"
    }
  }

  mock_data "aws_secretsmanager_secret_version" {
    defaults = {
      secret_string = "mock-splunk-secret"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

mock_provider "external" {
  mock_data "external" {
    defaults = {
      result = {
        awselb                    = "awselb"
        cval                      = "cval"
        splunkd_8443              = "splunkd"
        splunkweb_csrf_token_8443 = "csrf"
        splunkweb_uid             = "uid"
      }
    }
  }
}

variables {
  aws_profile  = "test"
  aws_region   = "us-east-1"
  splunk_cloud = "https://splunk.example.com"
  default_tags = {
    Product = "Forge"
  }
  tags = {
    Env = "test"
  }
}

override_data {
  target = data.external.splunk_data
  values = {
    result = {
      awselb                    = "awselb"
      cval                      = "cval"
      splunkd_8443              = "splunkd"
      splunkweb_csrf_token_8443 = "csrf"
      splunkweb_uid             = "uid"
    }
  }
}

override_data {
  target = data.external.config
  values = {
    result = {
      iamExternalId   = "external-id-123"
      instanceIamRole = "arn:aws:iam::999999999999:role/splunk-data-manager"
    }
  }
}

run "splunk_data_manager_common_role_contract" {
  command = plan

  assert {
    condition = (
      aws_iam_role.splunk_dm_read_only.name == "SplunkDMReadOnly"
      && jsondecode(aws_iam_role.splunk_dm_read_only.assume_role_policy).Statement[0].Principal.AWS[0] == "arn:aws:iam::999999999999:role/splunk-data-manager"
      && jsondecode(aws_iam_role.splunk_dm_read_only.assume_role_policy).Statement[0].Condition.StringEquals["sts:ExternalId"] == "external-id-123"
      && aws_iam_role.splunk_dm_read_only.tags.Product == "Forge"
      && aws_iam_role.splunk_dm_read_only.tags.Env == "test"
    )
    error_message = "Splunk Data Manager common role must trust the discovered Splunk IAM role, require the external ID, and carry merged tags."
  }

  assert {
    condition = (
      aws_iam_role_policy.splunk_dm_policy_attachment.name == "SplunkDMReadOnlyPolicy"
      && aws_iam_role_policy.splunk_dm_policy_attachment.role == aws_iam_role.splunk_dm_read_only.id
    )
    error_message = "Splunk Data Manager common policy must remain attached to the read-only integration role."
  }
}
