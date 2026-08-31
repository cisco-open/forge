apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: karpenter
spec:
  template:
    spec:
      requirements:
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ${jsonencode(instance_families)}
        - key: kubernetes.io/arch
          operator: In
          values: ${jsonencode(architectures)}
        - key: kubernetes.io/os
          operator: In
          values: ${jsonencode(operating_systems)}
        - key: karpenter.sh/capacity-type
          operator: In
          values: ${jsonencode(capacity_types)}
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: karpenter
  limits:
    cpu: ${cpu_limit}
  disruption:
    consolidationPolicy: ${jsonencode(consolidation_policy)}
    consolidateAfter: ${jsonencode(consolidate_after)}
