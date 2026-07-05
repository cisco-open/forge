# Changelog

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
