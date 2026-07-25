from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DETECTOR_DIR = REPO_ROOT / (
    'modules/integrations/splunk_o11y_conf_shared/detectors'
)
DETECTOR_MAIN_FILES = (
    DETECTOR_DIR / 'aws_regional_health/main.tf',
    DETECTOR_DIR / 'ec2_runner_health/main.tf',
)


def test_detector_scope_uses_dynamic_properties_without_cisco_tag_names() -> None:
    for detector_main in DETECTOR_MAIN_FILES:
        source = detector_main.read_text(encoding='utf-8')

        assert 'for variable in var.dynamic_variables' in source
        assert 'concat(variable.values, variable.values_suggested)' in source
        assert 'aws_tag_ProductFamilyName' not in source
        assert 'aws_tag_Environment' not in source
