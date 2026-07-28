# Changelog

## [4.6.0](https://github.com/cisco-open/forge/compare/v4.5.1...v4.6.0) (2026-07-28)


### Features

* **logs:** add runner log DLQ redrive ([#555](https://github.com/cisco-open/forge/issues/555)) ([abbf49e](https://github.com/cisco-open/forge/commit/abbf49e1b48152b86f79b72e852f398100608b63))
* **observability:** add platform health detectors ([#552](https://github.com/cisco-open/forge/issues/552)) ([9c1a6d1](https://github.com/cisco-open/forge/commit/9c1a6d1cefed0744e3a8bc9eea391fea492a64de))


### Bug Fixes

* **integrations:** preserve Splunk permissions during destroy ([#554](https://github.com/cisco-open/forge/issues/554)) ([c1d76f4](https://github.com/cisco-open/forge/commit/c1d76f4b12007bf490f56e8aff1494f44047237f))
* **observability:** close detector coverage gaps ([#553](https://github.com/cisco-open/forge/issues/553)) ([7ca522c](https://github.com/cisco-open/forge/commit/7ca522cf0e4d6edc438d1cd94a916d9a3ca69943))
* **observability:** exclude read-only filesystems from disk panels ([#549](https://github.com/cisco-open/forge/issues/549)) ([d170a6e](https://github.com/cisco-open/forge/commit/d170a6e4816f7df5853eb8984c8c1c72a797c0c7))
* **observability:** extend service-limit chart window ([#550](https://github.com/cisco-open/forge/issues/550)) ([5c606da](https://github.com/cisco-open/forge/commit/5c606da4bed3a0eae9a073ae6978a302cc64cb69))
* **observability:** increase dependency monitor retries ([#557](https://github.com/cisco-open/forge/issues/557)) ([2ddaf13](https://github.com/cisco-open/forge/commit/2ddaf1312f0c7f6ac79098ed757e0c5ab83f1b04))

## [4.5.1](https://github.com/cisco-open/forge/compare/v4.5.0...v4.5.1) (2026-07-27)


### Bug Fixes

* **lambdas:** configure retries for SSM clients ([#546](https://github.com/cisco-open/forge/issues/546)) ([f98dbb8](https://github.com/cisco-open/forge/commit/f98dbb87272ae8974778dfb2a29fab0d0892ea65))
* **runner-groups:** retry transient GitHub reads ([#545](https://github.com/cisco-open/forge/issues/545)) ([08a99fb](https://github.com/cisco-open/forge/commit/08a99fbd2ea3e8b3f179b57c82d03e90df4fe7f1))

## [4.5.0](https://github.com/cisco-open/forge/compare/v4.4.1...v4.5.0) (2026-07-25)


### Features

* **observability:** expose Forge module ref through standard tags ([#541](https://github.com/cisco-open/forge/issues/541)) ([d9bcc1c](https://github.com/cisco-open/forge/commit/d9bcc1cd2c9d39c029860655bb02636efeac0c46))
* **observability:** own EC2 runner health detectors ([#538](https://github.com/cisco-open/forge/issues/538)) ([b6872e0](https://github.com/cisco-open/forge/commit/b6872e05a6cfdc74e54b8f03448ef7b77f9d583d))
* **webhook:** enable API Gateway access logs ([#530](https://github.com/cisco-open/forge/issues/530)) ([58dae30](https://github.com/cisco-open/forge/commit/58dae307124867e05114657bfe27493f836e6f38))


### Bug Fixes

* **job-logs:** ignore events missing identifiers ([#534](https://github.com/cisco-open/forge/issues/534)) ([ceac8e6](https://github.com/cisco-open/forge/commit/ceac8e6ac74540bc9d730ef5e8caccce623d86fc))
* **job-logs:** mitigate archiver out-of-memory failures ([#529](https://github.com/cisco-open/forge/issues/529)) ([bcc923b](https://github.com/cisco-open/forge/commit/bcc923bf927131434a48d7724ee20b5252484ca5))
* **logs:** fail runner-log delivery after retries ([#533](https://github.com/cisco-open/forge/issues/533)) ([cf987bd](https://github.com/cisco-open/forge/commit/cf987bd17c8dde484a7c13b25ee7488e3582bd64))
* **observability:** align OTel host coverage ([#537](https://github.com/cisco-open/forge/issues/537)) ([2e6af4d](https://github.com/cisco-open/forge/commit/2e6af4d0b73aed058dd3fb0e90d417e7207ac47f))
* **observability:** correlate Kubernetes runner failures ([#539](https://github.com/cisco-open/forge/issues/539)) ([e7dd558](https://github.com/cisco-open/forge/commit/e7dd558fe665eec2617752c3c95656287cd23cb7))
* **observability:** extract shared Lambda fields ([#528](https://github.com/cisco-open/forge/issues/528)) ([5652dcd](https://github.com/cisco-open/forge/commit/5652dcd7db8a88e1f921306bcc36c9914b53e682))
* **opencost:** use exporter cluster dimension ([#536](https://github.com/cisco-open/forge/issues/536)) ([bdb9941](https://github.com/cisco-open/forge/commit/bdb994154e06bfaed45c218e4053dacc234a0f0b))
* **trust:** reduce validation frequency ([#531](https://github.com/cisco-open/forge/issues/531)) ([5c3a009](https://github.com/cisco-open/forge/commit/5c3a009083436043112cf9c586e31f1f0890b1f3))
* **webhook:** handle invalid signatures ([#532](https://github.com/cisco-open/forge/issues/532)) ([3871908](https://github.com/cisco-open/forge/commit/38719080eddb9a254505e905151f3e702f32b03e))


### Performance Improvements

* **trust:** validate tenant roles concurrently ([#535](https://github.com/cisco-open/forge/issues/535)) ([73a6f95](https://github.com/cisco-open/forge/commit/73a6f950f049f1190c6ef9ce7fc4a0b5e604d445))

## [4.4.1](https://github.com/cisco-open/forge/compare/v4.4.0...v4.4.1) (2026-07-25)


### Bug Fixes

* **observability:** link detectors to dashboard charts ([#526](https://github.com/cisco-open/forge/issues/526)) ([ae1f0c6](https://github.com/cisco-open/forge/commit/ae1f0c6702799b63225d1ad89db220dbe8e5fa91))

## [4.4.0](https://github.com/cisco-open/forge/compare/v4.3.0...v4.4.0) (2026-07-25)


### Features

* **observability:** add AWS regional health dashboard ([#514](https://github.com/cisco-open/forge/issues/514)) ([8cc9f83](https://github.com/cisco-open/forge/commit/8cc9f830d707e21235d0132fee2fe6aa8df970a2))
* **observability:** add AWS service limits dashboard ([#515](https://github.com/cisco-open/forge/issues/515)) ([35afc93](https://github.com/cisco-open/forge/commit/35afc934797db6e67f58d4da48e8279ed4e11e65))
* **observability:** add dependency probes dashboard ([#516](https://github.com/cisco-open/forge/issues/516)) ([d1d29a1](https://github.com/cisco-open/forge/commit/d1d29a168e2e9bd8e0a65689da465b0c20456c70))
* **observability:** add EC2 runner job right-sizing charts ([#513](https://github.com/cisco-open/forge/issues/513)) ([db785b6](https://github.com/cisco-open/forge/commit/db785b6f34069673c242f392482843548ce79c3b))
* **observability:** add Kinesis control-plane dashboard ([#517](https://github.com/cisco-open/forge/issues/517)) ([8704c96](https://github.com/cisco-open/forge/commit/8704c96eb7ddc3889d3ca40f3975b279a3b46d2d))
* **observability:** add Lambda control-plane dashboard ([#518](https://github.com/cisco-open/forge/issues/518)) ([90a0329](https://github.com/cisco-open/forge/commit/90a0329d50f7c14afc7d45e84b0536652e347579))
* **observability:** add regional dependency monitoring ([#507](https://github.com/cisco-open/forge/issues/507)) ([3ff86aa](https://github.com/cisco-open/forge/commit/3ff86aafbe2f8aa5aaa7e50ac9ffc643d9dcc671))
* **observability:** add S3 control-plane dashboard ([#521](https://github.com/cisco-open/forge/issues/521)) ([1b190ad](https://github.com/cisco-open/forge/commit/1b190ad33daa2e38083bbf6148f0b460fb25c45a))
* **observability:** add SQS control-plane dashboard ([#519](https://github.com/cisco-open/forge/issues/519)) ([26120e8](https://github.com/cisco-open/forge/commit/26120e85cb8f0ae1ea86140473841e7a6b545da8))
* **observability:** add tenant S3 dashboard ([#520](https://github.com/cisco-open/forge/issues/520)) ([6f582d6](https://github.com/cisco-open/forge/commit/6f582d69edab1f75525d61f83089b8ec0b6e55ad))
* **observability:** complete Forge dashboard operator model ([#504](https://github.com/cisco-open/forge/issues/504)) ([04a3a25](https://github.com/cisco-open/forge/commit/04a3a2547c138c04b6c862340ec9936404da95e6))
* **observability:** improve Forge detector signal quality ([#502](https://github.com/cisco-open/forge/issues/502)) ([170f4a2](https://github.com/cisco-open/forge/commit/170f4a2d2c59bee5cb6f1e2d3100367fe66036d7))
* **observability:** improve Forge operational dashboards ([#503](https://github.com/cisco-open/forge/issues/503)) ([cde820d](https://github.com/cisco-open/forge/commit/cde820d86fad8afa9827cf664df556fedcb2ae14))
* **observability:** improve Forge operational insights ([#501](https://github.com/cisco-open/forge/issues/501)) ([e958b8b](https://github.com/cisco-open/forge/commit/e958b8b114de54b7df66eeaa083874ae6828de95))
* **observability:** improve Kubernetes control-plane health ([#522](https://github.com/cisco-open/forge/issues/522)) ([71f5c4f](https://github.com/cisco-open/forge/commit/71f5c4fd31c50e8f46adc80e6045ed49d621fb40))
* **platform:** publish GitHub routing metadata ([#510](https://github.com/cisco-open/forge/issues/510)) ([ff1b447](https://github.com/cisco-open/forge/commit/ff1b447d2b9bbaabc74941cfcfe8ba2ba3140c8e))
* **splunk:** add dependency monitor secrets ([#511](https://github.com/cisco-open/forge/issues/511)) ([993a84c](https://github.com/cisco-open/forge/commit/993a84c4bc6784766e449d9cf236c295c40e2cd4))
* **splunk:** add regional dependency monitor ([#512](https://github.com/cisco-open/forge/issues/512)) ([a8b0fc9](https://github.com/cisco-open/forge/commit/a8b0fc952a697adbdcaebf7633bb9804eb66b935))


### Bug Fixes

* **lambdas:** ignore terminal runner lifecycle errors ([#508](https://github.com/cisco-open/forge/issues/508)) ([12fce19](https://github.com/cisco-open/forge/commit/12fce19258f5c52bff70f0eeeaec8596a269ebeb))
* **observability:** correct dashboard windows and detector signals ([#499](https://github.com/cisco-open/forge/issues/499)) ([0e20efe](https://github.com/cisco-open/forge/commit/0e20efea816c3cc8924db1a4c761b46a5d6b4af2))
* **observability:** harden Forge dashboard telemetry ([#505](https://github.com/cisco-open/forge/issues/505)) ([566286f](https://github.com/cisco-open/forge/commit/566286fb382487761cecb3aa41bd9eb1968d0e22))
* **observability:** stabilize runner usage cluster filters ([#525](https://github.com/cisco-open/forge/issues/525)) ([08d450a](https://github.com/cisco-open/forge/commit/08d450ad27733cf1db0fabf1cd525940f9221d29))

## [4.3.0](https://github.com/cisco-open/forge/compare/v4.2.1...v4.3.0) (2026-07-23)


### Features

* **runners:** allow per-runner Lambda batch tuning ([#493](https://github.com/cisco-open/forge/issues/493)) ([3ae2625](https://github.com/cisco-open/forge/commit/3ae2625c15d842539a4bbf42a1d4b181c4407f38))
* **runners:** allow per-runner queue redrive tuning ([#495](https://github.com/cisco-open/forge/issues/495)) ([89beed4](https://github.com/cisco-open/forge/commit/89beed4c069ecced358dcf7a1ccf5be77699b8fb))

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
