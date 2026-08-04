#!/usr/bin/env python3
"""Terraform entrypoint for Splunk Cloud Data Manager lifecycle operations."""

from splunk_data_manager.cli import main

if __name__ == '__main__':
    raise SystemExit(main())
