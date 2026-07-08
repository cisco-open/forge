# Fuzz Harnesses

## What This Is

`fuzz` contains Atheris fuzz targets for Forge Lambda parser and normalizer
boundaries. These are executable fuzz harnesses, not pytest tests.

Current targets cover:

| Fuzzer                                | Boundary                                                              |
| ------------------------------------- | --------------------------------------------------------------------- |
| `job_log_archiver_metadata_fuzzer.py` | GitHub job-log metadata flattening and event parsing.                 |
| `redrive_deadletter_fuzzer.py`        | SQS redrive mapping parser.                                           |
| `splunk_s3_runner_logs_fuzzer.py`     | Splunk S3 runner log metadata, timestamp, and event wrapping helpers. |
| `splunk_stuck_dispatcher_fuzzer.py`   | Splunk stuck-workflow webhook body parsing and result normalization.  |
| `trust_common_env_fuzzer.py`          | Forge trust-validator environment parsing helpers.                    |

## Why It Is Used

Forge receives untrusted JSON, form bodies, SQS message bodies, S3 metadata, and
environment-derived configuration. These harnesses look for parser crashes,
unbounded recursion, unsafe normalization, and malformed input paths that normal
example-based tests may miss.

The fast deterministic property tests live under `tests/lambdas`. This directory
is for ClusterFuzzLite/Atheris execution.

## CI Execution

Two ClusterFuzzLite workflows use this directory:

- `ClusterFuzzLite PR Fuzzing` builds affected Python fuzzers on pull requests
  touching `.clusterfuzzlite/**`, `fuzz/**`, Lambda source, or the Python lock
  files, then runs them for 120 seconds in `code-change` mode.
- `ClusterFuzzLite Continuous Builds` builds and uploads the fuzzers on pushes
  to `main`.

The build definition is in `.clusterfuzzlite/build.sh`. It packages every
`fuzz/*_fuzzer.py` file with PyInstaller and adds the relevant Lambda source
directories to the import path.

## Local Execution

The CI-equivalent ClusterFuzzLite path requires Docker and is owned by the
GitHub workflows plus `.clusterfuzzlite/build.sh`; the repo does not currently
provide a local wrapper for it.

For a single-target local smoke run, install Atheris and the Lambda runtime
dependencies, then run a fuzzer directly:

```bash
python -m pip install atheris boto3 botocore cryptography PyJWT requests
python fuzz/redrive_deadletter_fuzzer.py -runs=100
```

Do not use real AWS credentials. The harnesses set dummy AWS environment
variables and either avoid AWS clients or stub them.
