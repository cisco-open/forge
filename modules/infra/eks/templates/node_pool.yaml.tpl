apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: karpenter
spec:
  template:
    spec:
      requirements:
        - key: "karpenter.k8s.aws/instance-category"
          operator: In
          values: ["c", "m", "r"]
          # minValues here enforces the scheduler to consider at least that number of unique instance-category to schedule the pods.
          # This field is ALPHA and can be dropped or replaced at any time
          minValues: 2
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ["m5","m5d","c5","c5d","c4","r4"]
          minValues: 3
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: karpenter
  limits:
    cpu: 1000
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
