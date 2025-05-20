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
%{ for id in subnet_ids }
    - id: ${id}
%{ endfor }
  securityGroupSelectorTerms:
    - id: ${primary_security_group_id}
    - id: ${security_group_id}
  blockDeviceMappings:
    - deviceName: /dev/sda1
      ebs:
        volumeSize: 200Gi
        volumeType: gp3
        encrypted: true
        iops: 10000
        throughput: 500
        deleteOnTermination: true
  kubelet:
    maxPods: 100
