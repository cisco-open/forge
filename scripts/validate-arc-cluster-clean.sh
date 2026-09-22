#!/usr/bin/env bash
set -Eeuo pipefail

PHASE="argument parsing"
TENANTS_DIR=""
CLUSTER=""
AWS_PROFILE=""
AWS_REGION=""
EXPECTED_ACCOUNT_ID=""
ERRORS=0
CLUSTER_EXISTS=true

usage() {
    printf '%s\n' \
        "Usage: validate-arc-cluster-clean.sh --tenants-dir DIR --cluster NAME \\" \
        "  --aws-profile PROFILE --aws-region REGION --expected-account-id ID" \
        '' \
        'Read-only pre-destroy guard for an ARC EKS cluster. The check fails if an' \
        'ARC tenant namespace, Karpenter resource, or Pod Identity association' \
        'remains on the cluster.'
}

die() {
    echo "ERROR [$PHASE]: $*" >&2
    exit 1
}

record_error() {
    echo "ERROR [$PHASE]: $*" >&2
    ERRORS=$((ERRORS + 1))
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command is unavailable: $1"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --tenants-dir)
            [[ $# -ge 2 ]] || die "--tenants-dir requires a value"
            TENANTS_DIR=$2
            shift 2
            ;;
        --cluster)
            [[ $# -ge 2 ]] || die "--cluster requires a value"
            CLUSTER=$2
            shift 2
            ;;
        --aws-profile)
            [[ $# -ge 2 ]] || die "--aws-profile requires a value"
            AWS_PROFILE=$2
            shift 2
            ;;
        --aws-region)
            [[ $# -ge 2 ]] || die "--aws-region requires a value"
            AWS_REGION=$2
            shift 2
            ;;
        --expected-account-id)
            [[ $# -ge 2 ]] || die "--expected-account-id requires a value"
            EXPECTED_ACCOUNT_ID=$2
            shift 2
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
        esac
    done

    [[ -d "$TENANTS_DIR" ]] || die "tenants directory does not exist: $TENANTS_DIR"
    TENANTS_DIR=$(cd -- "$TENANTS_DIR" && pwd)
    [[ "$CLUSTER" == *-blue || "$CLUSTER" == *-green ]] ||
        die "cluster must end in -blue or -green"
    [[ -n "$AWS_PROFILE" ]] || die "--aws-profile is required"
    [[ -n "$AWS_REGION" ]] || die "--aws-region is required"
    [[ "$EXPECTED_ACCOUNT_ID" =~ ^[0-9]{12}$ ]] ||
        die "expected account ID must contain 12 digits"
}

preflight() {
    PHASE="preflight"
    local command_name actual_account cluster_lookup
    for command_name in aws jq kubectl; do
        require_command "$command_name"
    done

    actual_account=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text)
    [[ "$actual_account" == "$EXPECTED_ACCOUNT_ID" ]] ||
        die "AWS account mismatch: expected $EXPECTED_ACCOUNT_ID, authenticated to $actual_account"

    if ! cluster_lookup=$(aws eks describe-cluster \
        --region "$AWS_REGION" \
        --name "$CLUSTER" \
        --profile "$AWS_PROFILE" \
        --query cluster.status \
        --output text 2>&1); then
        if grep -q 'ResourceNotFoundException' <<<"$cluster_lookup"; then
            CLUSTER_EXISTS=false
            echo "Pre-destroy check: account=$EXPECTED_ACCOUNT_ID region=$AWS_REGION cluster=$CLUSTER is already absent"
            return
        fi
        die "unable to inspect EKS cluster '$CLUSTER': $cluster_lookup"
    fi

    KUBE_CONTEXT="${CLUSTER}-${AWS_PROFILE}-${AWS_REGION}-pre-destroy"
    aws eks update-kubeconfig \
        --region "$AWS_REGION" \
        --name "$CLUSTER" \
        --alias "$KUBE_CONTEXT" \
        --profile "$AWS_PROFILE" >/dev/null
    kubectl --context "$KUBE_CONTEXT" get --raw=/readyz 2>/dev/null | grep -qx ok ||
        die "Kubernetes API is not ready: $CLUSTER"
    echo "Pre-destroy check: account=$EXPECTED_ACCOUNT_ID region=$AWS_REGION cluster=$CLUSTER"
}

check_absent() {
    local description=$1
    shift
    local object
    object=$("$@") || {
        record_error "unable to inspect $description"
        return
    }
    [[ -z "$object" ]] || record_error "$description still exists: $object"
}

check_tenant() {
    local tenant_dir=$1 tenant config
    local associations
    tenant=$(basename "$tenant_dir")
    PHASE="inspect tenant $tenant"
    echo "Checking tenant '$tenant' on '$CLUSTER'..."
    config="${tenant_dir}/config.yml"
    [[ -f "$config" ]] || {
        record_error "tenant '$tenant' has no config.yml"
        return
    }

    check_absent "namespace '$tenant' on '$CLUSTER'" \
        kubectl --context "$KUBE_CONTEXT" get namespace "$tenant" --ignore-not-found -o name
    check_absent "NodePool 'karpenter-${tenant}' on '$CLUSTER'" \
        kubectl --context "$KUBE_CONTEXT" get nodepool.karpenter.sh "karpenter-${tenant}" --ignore-not-found -o name
    check_absent "EC2NodeClass 'karpenter-${tenant}' on '$CLUSTER'" \
        kubectl --context "$KUBE_CONTEXT" get ec2nodeclass.karpenter.k8s.aws "karpenter-${tenant}" --ignore-not-found -o name

    associations=$(aws eks list-pod-identity-associations \
        --cluster-name "$CLUSTER" \
        --namespace "$tenant" \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --output json) || {
        record_error "unable to inspect Pod Identity associations for tenant '$tenant'"
        return
    }
    if ! jq -e '.associations | length == 0' <<<"$associations" >/dev/null; then
        record_error "tenant '$tenant' Pod Identity associations remain on '$CLUSTER'"
    fi
}

main() {
    parse_args "$@"
    preflight

    if [[ "$CLUSTER_EXISTS" == false ]]; then
        echo "Verified: cluster '$CLUSTER' is already absent; no live tenant ARC footprint can remain in its Kubernetes API."
        exit 0
    fi

    local tenant_dir found=false
    for tenant_dir in "$TENANTS_DIR"/*; do
        [[ -d "$tenant_dir" ]] || continue
        found=true
        check_tenant "$tenant_dir"
    done
    [[ "$found" == true ]] || die "no tenant directories found in $TENANTS_DIR"

    PHASE="complete"
    if ((ERRORS > 0)); then
        die "cluster '$CLUSTER' failed $ERRORS ARC pre-destroy check(s); destruction is blocked"
    fi
    echo "Verified: cluster '$CLUSTER' has no live tenant ARC footprint."
}

main "$@"
