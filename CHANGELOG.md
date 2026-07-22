# Changelog

## [4.2.1](https://github.com/cisco-open/forge/compare/v4.2.0...v4.2.1) (2026-07-22)


### Bug Fixes

* **lambda:** prevent recurring deployment plans ([#489](https://github.com/cisco-open/forge/issues/489)) ([0549365](https://github.com/cisco-open/forge/commit/0549365de85f0de8057e14cbc2a11f726c9a081b))

## [4.2.0](https://github.com/cisco-open/forge/compare/v4.1.2...v4.2.0) (2026-07-22)


### Features

* **runners:** expose runner label maps ([#487](https://github.com/cisco-open/forge/issues/487)) ([294adca](https://github.com/cisco-open/forge/commit/294adca9a4886405bd446cf86a2737b484737595))

## [4.1.2](https://github.com/cisco-open/forge/compare/v4.1.1...v4.1.2) (2026-07-21)


### Bug Fixes

* **forge-runners:** make GitHub App webhook updates retryable ([#484](https://github.com/cisco-open/forge/issues/484)) ([e3ab1e3](https://github.com/cisco-open/forge/commit/e3ab1e3b1408d31bfd3913c5f22022d85ac950fb))

## [4.1.1](https://github.com/cisco-open/forge/compare/v4.1.0...v4.1.1) (2026-07-20)


### Bug Fixes

* **splunk-otel:** allow chart version updates ([#481](https://github.com/cisco-open/forge/issues/481)) ([540a15d](https://github.com/cisco-open/forge/commit/540a15d432cc2b3b0b61432db32717d8e6a82ab6))

## [4.1.0](https://github.com/cisco-open/forge/compare/v4.0.5...v4.1.0) (2026-07-16)


### Features

* **helpers:** add dedicated Mac hosts and Config recording ([#475](https://github.com/cisco-open/forge/issues/475)) ([ea10bca](https://github.com/cisco-open/forge/commit/ea10bca806bb2517a826e67394428f2ce097152e))


### Bug Fixes

* **helpers:** add License Manager service role ([#480](https://github.com/cisco-open/forge/issues/480)) ([e3a1fa4](https://github.com/cisco-open/forge/commit/e3a1fa403df3aeeb97330024a4e52291857c6f0c))

## [4.0.5](https://github.com/cisco-open/forge/compare/v4.0.4...v4.0.5) (2026-07-15)


### Bug Fixes

* **dispatcher:** alias reserved result attribute ([#474](https://github.com/cisco-open/forge/issues/474)) ([5573be6](https://github.com/cisco-open/forge/commit/5573be69b33bfdfab719b0173d0380525c0ff6a9))
* **examples:** order shared Splunk config after dispatcher ([#471](https://github.com/cisco-open/forge/issues/471)) ([64642aa](https://github.com/cisco-open/forge/commit/64642aa0c02f9d90807b3a8b9ed88aca3dc59c01))

## [4.0.4](https://github.com/cisco-open/forge/compare/v4.0.3...v4.0.4) (2026-07-13)


### Bug Fixes

* **ec2:** use instance profile for runner job-hooks and make them non-fatal ([#468](https://github.com/cisco-open/forge/issues/468)) ([6054d8c](https://github.com/cisco-open/forge/commit/6054d8cbd5806e580028a681db940cf944f2f38f))

## [4.0.3](https://github.com/cisco-open/forge/compare/v4.0.2...v4.0.3) (2026-07-13)


### Bug Fixes

* **splunk:** fix alert for multiple matches in stuck jobs ([#462](https://github.com/cisco-open/forge/issues/462)) ([fbd16d5](https://github.com/cisco-open/forge/commit/fbd16d5e2cfaaa4ab45f6766b0c754b69763c50f))
* **splunk:** fix query with breaking change in lambda logs ([#460](https://github.com/cisco-open/forge/issues/460)) ([4ae7972](https://github.com/cisco-open/forge/commit/4ae79725bda0ccbd1fc75495ee517ed82d84e9fb))

## [4.0.2](https://github.com/cisco-open/forge/compare/v4.0.1...v4.0.2) (2026-07-09)


### Bug Fixes

* **deps:** update Forge dependency pins ([#453](https://github.com/cisco-open/forge/issues/453)) ([5f34a94](https://github.com/cisco-open/forge/commit/5f34a94c5bb22914afd2bc422b07bb2e59ba2e25))
* **deps:** update uv lockfile automation ([#450](https://github.com/cisco-open/forge/issues/450)) ([c73f596](https://github.com/cisco-open/forge/commit/c73f596aa6ebffc381d07dd9219b54a2fc769048))
* **splunk-aws-billing:** set billing view ARN ([#449](https://github.com/cisco-open/forge/issues/449)) ([43f0123](https://github.com/cisco-open/forge/commit/43f01238962860e1a6332462708c87eaa98bccf5))
* **splunk-billing:** add log group dependencies ([#442](https://github.com/cisco-open/forge/issues/442)) ([b75ab7f](https://github.com/cisco-open/forge/commit/b75ab7f776c15ba532449625902348bfd2bcbb5d))
* **splunk:** suppress AWS billing export drift ([#444](https://github.com/cisco-open/forge/issues/444)) ([993d603](https://github.com/cisco-open/forge/commit/993d60326cde764ec97d1328116eeab9a8cb2a2a))

## [4.0.1](https://github.com/cisco-open/forge/compare/v4.0.0...v4.0.1) (2026-07-06)


### Bug Fixes

* **splunk:** use PyJWT for GitHub app JWTs ([#424](https://github.com/cisco-open/forge/issues/424)) ([26df3a2](https://github.com/cisco-open/forge/commit/26df3a2afac0e799f30374dea27d165c8e53b875))

## [4.0.0](https://github.com/cisco-open/forge/compare/v3.12.0...v4.0.0) (2026-07-05)


### ⚠ BREAKING CHANGES

* Forge module paths were reorganized into platform, infra, integrations, and helpers. Consumers must update module source paths before upgrading.

### Features

* **runner-logs:** enrich splunk fields from metadata sidecar ([#410](https://github.com/cisco-open/forge/issues/410)) ([946c603](https://github.com/cisco-open/forge/commit/946c603ca11cbcf1cc105f66e45cfbf741be917d))
* **splunk:** add EC2 scale-up failure dashboards ([#408](https://github.com/cisco-open/forge/issues/408)) ([3176c90](https://github.com/cisco-open/forge/commit/3176c90de1ab59dc5c06645cb334ea9d4760299b))


### Bug Fixes

* **ci:** remediate zizmor alerts ([#392](https://github.com/cisco-open/forge/issues/392)) ([953403a](https://github.com/cisco-open/forge/commit/953403adec549b8b9632bb2227a7d92fb5896ea7))
* **docs:** hash-pin docs dependencies ([#422](https://github.com/cisco-open/forge/issues/422)) ([733c9e4](https://github.com/cisco-open/forge/commit/733c9e4b3873a68b62f110e82ecaeb398620221c))


### Code Refactoring

* redesign Forge module layout ([#419](https://github.com/cisco-open/forge/issues/419)) ([2791806](https://github.com/cisco-open/forge/commit/2791806731112fa049ddbd5a1bfa4bc5c182d786))

## [3.12.0](https://github.com/cisco-open/forge/compare/v3.11.0...v3.12.0) (2026-07-03)


### Features

* **splunk-o11y:** add Forge impact dynamic variables ([#389](https://github.com/cisco-open/forge/issues/389)) ([ee1bb79](https://github.com/cisco-open/forge/commit/ee1bb792b644c754af515895ac683e260da18e77))

## [3.11.0](https://github.com/cisco-open/forge/compare/v3.10.0...v3.11.0) (2026-07-03)


### Features

* allow Splunk O11y dashboard group naming ([#387](https://github.com/cisco-open/forge/issues/387)) ([2b0e830](https://github.com/cisco-open/forge/commit/2b0e83051a16c24331c63dbacda4783d12ec2ac9))


### Bug Fixes

* enable OpenCost Prometheus source metrics ([#386](https://github.com/cisco-open/forge/issues/386)) ([1abd95f](https://github.com/cisco-open/forge/commit/1abd95f0175ce4598156a291e2699d878589b46a))

## [3.10.0](https://github.com/cisco-open/forge/compare/v3.9.2...v3.10.0) (2026-07-02)


### Features

* add OpenCost O11y dashboard ([#382](https://github.com/cisco-open/forge/issues/382)) ([8be1743](https://github.com/cisco-open/forge/commit/8be17434679ecab24d8a4bb0e74ad50f57ccb191))
* add Splunk OpenCost EKS integration ([#378](https://github.com/cisco-open/forge/issues/378)) ([f9a7726](https://github.com/cisco-open/forge/commit/f9a7726c26f0b26e45b43115b39c8fa284bd11d2))

## [3.9.2](https://github.com/cisco-open/forge/compare/v3.9.1...v3.9.2) (2026-07-01)


### Bug Fixes

* avoid windows hook log contention ([#375](https://github.com/cisco-open/forge/issues/375)) ([0a600cb](https://github.com/cisco-open/forge/commit/0a600cb28f866b2c259e881fb72b363f2346f904))

## [3.9.1](https://github.com/cisco-open/forge/compare/v3.9.0...v3.9.1) (2026-07-01)


### Bug Fixes

* break ec2 runner ami destroy cycle ([#373](https://github.com/cisco-open/forge/issues/373)) ([c599a81](https://github.com/cisco-open/forge/commit/c599a81fee4410d249b89767ff20d741515e5b7c))

## [3.9.0](https://github.com/cisco-open/forge/compare/v3.8.0...v3.9.0) (2026-06-30)


### Features

* skip Splunk redelivery for active runners ([#371](https://github.com/cisco-open/forge/issues/371)) ([06bc409](https://github.com/cisco-open/forge/commit/06bc409721585f52d1f92104a0e543440809a292))

## [3.8.0](https://github.com/cisco-open/forge/compare/v3.7.0...v3.8.0) (2026-06-30)


### Features

* add os-specific runner hooks ([#368](https://github.com/cisco-open/forge/issues/368)) ([0bced26](https://github.com/cisco-open/forge/commit/0bced2647ea1b8f49a818f6b69271fb09bba066a))

## [3.7.0](https://github.com/cisco-open/forge/compare/v3.6.1...v3.7.0) (2026-06-29)


### Features

* **ec2:** add per-OS runner job lifecycle hook templates (osx/windows) ([#364](https://github.com/cisco-open/forge/issues/364)) ([12235c4](https://github.com/cisco-open/forge/commit/12235c4b9e5dd8d0999eba5c416ce8e4f3c644ba))
* enrich Splunk workflow job context ([#362](https://github.com/cisco-open/forge/issues/362)) ([c1804fc](https://github.com/cisco-open/forge/commit/c1804fcf2e1de78cc320ec1d2dec126042c2a8e7))


### Bug Fixes

* add depends on in splunk_otel_collector ([#359](https://github.com/cisco-open/forge/issues/359)) ([51006ed](https://github.com/cisco-open/forge/commit/51006ed14761ccc0b51c5dfa4207bbdcfbb3bd50))
* **splunk-otel-eks:** update otel collector config and versions ([#363](https://github.com/cisco-open/forge/issues/363)) ([43c0ec9](https://github.com/cisco-open/forge/commit/43c0ec9e4e79080fd43ab3cf7ce0feeea2bcc2f6))

## [3.6.1](https://github.com/cisco-open/forge/compare/v3.6.0...v3.6.1) (2026-06-26)


### Bug Fixes

* **eks:** use latest compatible kube-proxy add-on version ([#335](https://github.com/cisco-open/forge/issues/335)) ([71c9123](https://github.com/cisco-open/forge/commit/71c9123f0c92f1ce09c2ca938c463e71bdabe97a))

## [3.6.0](https://github.com/cisco-open/forge/compare/v3.5.0...v3.6.0) (2026-06-24)


### Features

* add stuck workflow job redelivery dispatcher ([#347](https://github.com/cisco-open/forge/issues/347)) ([aceae92](https://github.com/cisco-open/forge/commit/aceae927c11ceef74b6f65c5013247d8f59a33ff))
* configure EC2 dynamic labels per runner ([#350](https://github.com/cisco-open/forge/issues/350)) ([df37c49](https://github.com/cisco-open/forge/commit/df37c499dec4321baf687a0d74cf49f3ff894488))

## [3.5.0](https://github.com/cisco-open/forge/compare/v3.4.0...v3.5.0) (2026-06-22)


### Features

* allow ARC container image overrides ([#340](https://github.com/cisco-open/forge/issues/340)) ([4213039](https://github.com/cisco-open/forge/commit/4213039bf2106609d893f7c996be9e2362f0227c))
