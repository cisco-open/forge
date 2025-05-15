apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: karpenter
spec:
  amiFamily: AL2
  amiSelectorTerms:
    - id: ${ami_id}
  role: ${role_arn}
  subnetSelectorTerms:
    - tags:
        Name: ops_a
    - tags:
        Name: ops_b
  securityGroupSelectorTerms:
    - id: ${primary_security_group_id}
    - id: ${security_group_id}
  kubelet:
    maxPods: 100
