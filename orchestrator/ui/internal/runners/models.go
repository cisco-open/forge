package runners

type PoolConfig struct {
	Size                 int    `json:"size"`
	ScheduleExpression   string `json:"schedule_expression"`
	ScheduleExpressionTZ string `json:"schedule_expression_timezone"`
}

type EC2RunnerConfig struct {
	AMIFilter               string       `json:"ami_filter"`
	AMIOwners               []string     `json:"ami_owners"`
	AMIKMSKeyARN            *string      `json:"ami_kms_key_arn,omitempty"`
	InstanceTypes           []string     `json:"instance_types"`
	InstanceTargetCapacity  string       `json:"instance_target_capacity_type"`
	BlockDeviceVolumeSizeGB int          `json:"block_device_volume_size"`
	BlockDeviceVolumeType   string       `json:"block_device_volume_type"`
	BlockDeviceKMSKeyID     *string      `json:"block_device_kms_key_id,omitempty"`
	PoolConfig              []PoolConfig `json:"pool_config,omitempty"`
}

type ARCRunnerConfig struct {
	MaxRunners              int    `json:"max_runners"`
	MinRunners              int    `json:"min_runners"`
	ScaleSetName            string `json:"scale_set_name"`
	ScaleSetType            string `json:"scale_set_type"`
	ContainerActionsRunner  string `json:"container_actions_runner"`
	ContainerRequestsCPU    string `json:"container_requests_cpu"`
	ContainerRequestsMemory string `json:"container_requests_memory"`
	ContainerLimitsCPU      string `json:"container_limits_cpu"`
	ContainerLimitsMemory   string `json:"container_limits_memory"`
}

type RunnerConfigs struct {
	EC2 map[string]EC2RunnerConfig `json:"ec2"`
	ARC map[string]ARCRunnerConfig `json:"arc"`
}
