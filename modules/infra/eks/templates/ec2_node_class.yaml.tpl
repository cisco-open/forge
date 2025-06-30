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
        volumeSize: ${disk_size}Gi
        volumeType: ${disk_type}
        encrypted: true
        iops: ${disk_iops}
        throughput: ${disk_throughput}
        deleteOnTermination: true
  kubelet:
    maxPods: 100
  tags:
%{ for k, v in tags }
    ${k}: '${v}'
%{ endfor }
