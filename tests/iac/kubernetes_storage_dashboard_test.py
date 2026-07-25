import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
TEMPLATE = REPO_ROOT.joinpath(
    'modules',
    'integrations',
    'splunk_cloud_conf_shared',
    'template_files',
    'forge_kubernetes_storage_and_network.json.tftpl',
)


def _dashboard() -> dict:
    rendered = TEMPLATE.read_text(encoding='utf-8').replace(
        '${splunk_index}', 'forge_prod'
    )
    return json.loads(rendered)


def test_storage_signals_are_aged_per_kubernetes_object() -> None:
    query = _dashboard()['dataSources']['kube_event_categories_search'][
        'options'
    ]['query']

    assert 'path=involvedObject.namespace' in query
    assert 'path=involvedObject.name' in query
    assert 'by category namespace pod pvc reason' in query
    assert 'age_minutes=round((now()-first_time)/60,1)' in query
    assert 'active_minutes=round((last_time-first_time)/60,1)' in query


def test_runner_job_correlation_requires_both_signal_types() -> None:
    dashboard = _dashboard()
    query = dashboard['dataSources']['runner_job_correlation_search'][
        'options'
    ]['query']

    assert 'sourcetype="kube:events"' in query
    assert 'forgecicd_log_type=webhook github.status=*' in query
    assert 'path=github.runnerName' in query
    assert 'where k8s_events>0 AND job_events>0' in query
    assert 'failed_job_events' in query
    primary = dashboard['visualizations']['runner_job_correlation_table'][
        'dataSources'
    ]['primary']
    assert primary == 'runner_job_correlation_search'


def test_component_failures_are_correlated_in_five_minute_windows() -> None:
    dashboard = _dashboard()
    query = dashboard['dataSources'][
        'component_job_window_correlation_search'
    ]['options']['query']

    for sourcetype in (
        'kube:container:csi-provisioner',
        'kube:container:controller',
        'kube:container:calico-node',
    ):
        assert sourcetype in query
    assert 'bin _time span=5m' in query
    assert 'ebs_csi_errors' in query
    assert 'karpenter_errors' in query
    assert 'cni_errors' in query
    assert 'AND failed_jobs>0' in query
