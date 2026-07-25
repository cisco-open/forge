from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ALERT = REPO_ROOT.joinpath(
    'modules',
    'integrations',
    'splunk_stuck_workflow_job_dispatcher',
    'splunk_alert.tf',
)
DASHBOARD = REPO_ROOT.joinpath(
    'modules',
    'integrations',
    'splunk_cloud_conf_shared',
    'dashboard_forge_github_webhook_workflow_job_events.tf',
)


def test_redelivery_alert_scopes_webhook_and_dispatch_sources() -> None:
    source = ALERT.read_text(encoding='utf-8')

    assert 'sourcetype="aws:cloudwatchlogs"' in source
    assert 'source="*:/aws/lambda/*-webhook*"' in source
    assert 'source="*:/aws/lambda/*-dispatch-to-runner*"' in source
    assert 'stuck_minutes <= 1440' in source


def test_dashboard_supports_source_scoped_seven_day_audit() -> None:
    source = DASHBOARD.read_text(encoding='utf-8')

    assert source.count('source="*:/aws/lambda/*-webhook*"') >= 2
    assert source.count('source="*:/aws/lambda/*-dispatch-to-runner*"') >= 2
    assert source.count('stuck_minutes <= 10080') == 2
