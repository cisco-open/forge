# Repo: containers

Purpose: build the containers Forge uses in CI: action-runner images,
pre-commit images, and small operational tool images.

```text
containers/
├── .github/workflows/build-containers.yml
├── containers/
│   ├── action-runner/
│   │   ├── Dockerfile
│   │   └── Makefile
│   └── pre-commit/
│       ├── Dockerfile
│       └── Makefile
└── renovate.json
```

Do not add VM packages such as KVM, libvirt, or nested Docker assumptions to
Kubernetes runner containers unless the runner platform explicitly supports it.
