# Preserve the existing host and access resources while adopting purpose-based
# OpenTofu addresses. Several physical AWS names intentionally remain
# `ptraynor_dev` because changing them would require replacement.
moved {
  from = data.aws_subnet.ptraynor_dev_host
  to   = data.aws_subnet.psg_pptx_host
}

moved {
  from = aws_security_group.ptraynor_dev_host
  to   = aws_security_group.psg_pptx_host
}

moved {
  from = aws_vpc_security_group_egress_rule.ptraynor_dev_host_https
  to   = aws_vpc_security_group_egress_rule.psg_pptx_host_https
}

moved {
  from = aws_vpc_security_group_egress_rule.ptraynor_dev_host_http
  to   = aws_vpc_security_group_egress_rule.psg_pptx_host_http
}

moved {
  from = aws_vpc_security_group_egress_rule.ptraynor_dev_host_dns_udp
  to   = aws_vpc_security_group_egress_rule.psg_pptx_host_dns_udp
}

moved {
  from = aws_vpc_security_group_egress_rule.ptraynor_dev_host_dns_tcp
  to   = aws_vpc_security_group_egress_rule.psg_pptx_host_dns_tcp
}

moved {
  from = aws_vpc_security_group_egress_rule.ptraynor_dev_host_postgresql
  to   = aws_vpc_security_group_egress_rule.psg_pptx_host_postgresql
}

moved {
  from = aws_iam_role.ptraynor_dev_host
  to   = aws_iam_role.psg_pptx_host
}

moved {
  from = aws_iam_role_policy_attachment.ptraynor_dev_host_ssm
  to   = aws_iam_role_policy_attachment.psg_pptx_host_ssm
}

moved {
  from = aws_iam_instance_profile.ptraynor_dev_host
  to   = aws_iam_instance_profile.psg_pptx_host
}

moved {
  from = aws_instance.ptraynor_dev_host
  to   = aws_instance.psg_pptx_host
}

moved {
  from = aws_vpc_security_group_ingress_rule.greenplum_from_ptraynor_dev_host
  to   = aws_vpc_security_group_ingress_rule.greenplum_from_psg_pptx_host
}

moved {
  from = aws_ssoadmin_permission_set.ptraynor_dev_access
  to   = aws_ssoadmin_permission_set.psg_pptx_host_access
}

moved {
  from = aws_ssoadmin_permission_set_inline_policy.ptraynor_dev_access
  to   = aws_ssoadmin_permission_set_inline_policy.psg_pptx_host_access
}

moved {
  from = aws_iam_role_policy.ptraynor_dev_greenplum_readonly_secret
  to   = aws_iam_role_policy.psg_pptx_host_greenplum_readonly_secret
}

moved {
  from = aws_iam_role_policy.ptraynor_dev_greenplum_pptx_underscored_secret
  to   = aws_iam_role_policy.psg_pptx_host_greenplum_pptx_underscored_secret
}

moved {
  from = aws_ssoadmin_account_assignment.user_access["whogan@preyrasolutions.com|538308268352|ptraynor_dev_access"]
  to   = aws_ssoadmin_account_assignment.user_access["whogan@preyrasolutions.com|538308268352|psg_pptx_host_access"]
}

moved {
  from = aws_ssoadmin_account_assignment.user_access["patrick.traynor@preyrasolutions.com|538308268352|ptraynor_dev_access"]
  to   = aws_ssoadmin_account_assignment.user_access["patrick.traynor@preyrasolutions.com|538308268352|psg_pptx_host_access"]
}
