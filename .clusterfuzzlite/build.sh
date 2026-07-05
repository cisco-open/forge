#!/bin/bash -eu

FUZZER_DIR="$SRC/forge/fuzz"
LAMBDA_PATHS=(
    "$SRC/forge/modules/integrations/splunk_cloud_s3_runner_logs/lambda"
    "$SRC/forge/modules/integrations/splunk_stuck_workflow_job_dispatcher/lambda"
    "$SRC/forge/modules/platform/forge_runners/forge_trust_validator/lambda"
    "$SRC/forge/modules/platform/forge_runners/github_actions_job_logs/lambda/job_log_archiver"
    "$SRC/forge/modules/platform/forge_runners/redrive_deadletter/lambda"
)

for fuzzer in "$FUZZER_DIR"/*_fuzzer.py; do
    fuzzer_basename="$(basename -s .py "$fuzzer")"
    fuzzer_package="${fuzzer_basename}.pkg"
    pyinstaller_path_args=()
    for lambda_path in "${LAMBDA_PATHS[@]}"; do
        pyinstaller_path_args+=(--paths "$lambda_path")
    done

    pyinstaller \
        --distpath "$OUT" \
        --workpath "$WORK/pyinstaller/$fuzzer_basename" \
        --specpath "$WORK/spec" \
        "${pyinstaller_path_args[@]}" \
        --onefile \
        --name "$fuzzer_package" \
        "$fuzzer"

    cat >"$OUT/$fuzzer_basename" <<EOF
#!/bin/sh
# LLVMFuzzerTestOneInput for fuzzer detection.
this_dir=\$(dirname "\$0")
"\$this_dir/$fuzzer_package" "\$@"
EOF
    chmod +x "$OUT/$fuzzer_basename"
done
