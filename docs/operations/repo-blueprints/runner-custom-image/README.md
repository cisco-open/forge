# Repo: runner-custom-image

Purpose: build product or tenant-specific AMIs from the base runner AMI. Keep
base OS work out of this repo. Install only the tools that make this runner
different.

```text
runner-custom-image/
├── .github/workflows/build-image.yml
├── ansible/
│   ├── playbooks/custom.yml
│   └── roles/custom/tasks/main.yml
├── packer/custom.pkr.hcl
└── renovate.json
```

Change `base_ami_name` to match the AMI produced by `runner-base-image`.
