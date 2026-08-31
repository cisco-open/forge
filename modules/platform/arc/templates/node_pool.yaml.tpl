  apiVersion: karpenter.sh/v1
  kind: NodePool
  metadata:
    name: karpenter-${tenant}
  spec:
    template:
      metadata:
        labels:
          forge.local/scale_set_type: dind
          forge.local/tenant: ${tenant}
      spec:
        requirements:
        ${replace(trimspace(yamlencode(requirements)), "\n", "\n        ")}
        nodeClassRef:
          group: karpenter.k8s.aws
          kind: EC2NodeClass
          name: karpenter-${tenant}
        taints:
          - key: forge.local/scale_set_type
            value: dind
            effect: NoSchedule
          - key: forge.local/tenant
            value: ${tenant}
            effect: NoSchedule
    limits:
      cpu: ${cpu_limit}
    disruption:
      consolidationPolicy: ${jsonencode(consolidation_policy)}
      consolidateAfter: ${jsonencode(consolidate_after)}
