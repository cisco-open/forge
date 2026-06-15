resource "splunk_configs_conf" "forgecicd_eks_control_plane_fields" {
  name = "transforms/forgecicd_eks_control_plane_fields"

  variables = {
    "REGEX"      = "(?<aws_region>[^:]+):\\/aws\\/eks\\/(?<eks_cluster>[^\\/]+)\\/cluster:(?<eks_component>authenticator|kube-apiserver-audit|kube-apiserver)(?:-(?<eks_log_stream_id>[^:]+))?"
    "FORMAT"     = "aws_region::$1 eks_cluster::$2 eks_component::$3 eks_log_stream_id::$4"
    "SOURCE_KEY" = "source"
    "CLEAN_KEYS" = "0"
  }

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }

  lifecycle {
    ignore_changes = [
      variables["CAN_OPTIMIZE"],
      variables["DEFAULT_VALUE"],
      variables["DEPTH_LIMIT"],
      variables["DEST_KEY"],
      variables["KEEP_EMPTY_VALS"],
      variables["LOOKAHEAD"],
      variables["MATCH_LIMIT"],
      variables["MV_ADD"],
      variables["WRITE_META"],
      variables["disabled"]
    ]
  }
}
