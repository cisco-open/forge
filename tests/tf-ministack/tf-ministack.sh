#!/usr/bin/env bash
# tf-ministack.sh <init|plan|apply|destroy|test> [dir] [extra args...]
#
# Roda OpenTofu (ou Terragrunt, via TF_BIN=terragrunt) contra o MiniStack.
# Exige que o MiniStack esteja rodando em :4566 - aborta se nao estiver, para
# nunca cair acidentalmente na AWS de verdade.
set -euo pipefail

CMD="${1:?uso: tf-ministack.sh <init|plan|apply|destroy|test> [dir] [args...]}"
DIR="${2:-.}"
shift $(($# >= 2 ? 2 : 1))

TF_BIN="${TF_BIN:-tofu}"

export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_ENDPOINT_URL="http://localhost:4566"
export USE_MINISTACK="true" # liga o bloco generate do Terragrunt

# guarda de seguranca: MiniStack precisa responder
if ! python3 - <<'PY' 2>/dev/null; then
import boto3
boto3.client("sts", endpoint_url="http://localhost:4566", region_name="us-east-1",
             aws_access_key_id="test", aws_secret_access_key="test").get_caller_identity()
PY
    echo "ERRO: MiniStack nao acessivel em http://localhost:4566 (rode: docker compose up -d)" >&2
    exit 1
fi

cd "$DIR"
exec "$TF_BIN" "$CMD" "$@"
