locals {
  github_webhook_workflow_jobs_definition = jsonencode({
    title       = "GitHub Webhook Workflow Job Events"
    description = "Shows per-tenant GitHub workflow_job webhook health checks and event details."
    inputs = {
      input_global_time = {
        options = {
          defaultValue = "-24h@h,now"
          token        = "global_time"
        }
        title = "Global Time Range"
        type  = "input.timerange"
      }
      input_tenant = {
        options = {
          defaultValue = "*"
          items = concat(
            [{ label = "All", value = "*" }],
            [for tenant in var.splunk_conf.tenant_names : { label = tenant, value = tenant }]
          )
          token = "tenant"
        }
        title = "Forge Tenant"
        type  = "input.dropdown"
      }
      input_repository = {
        options = {
          defaultValue = "*"
          token        = "repository"
        }
        title = "Repository"
        type  = "input.text"
      }
    }
    defaults = {
      dataSources = {
        "ds.search" = {
          options = {
            queryParameters = {
              earliest = "$global_time.earliest$"
              latest   = "$global_time.latest$"
            }
          }
        }
      }
    }
    visualizations = {
      tenant_health_summary_table = {
        dataSources = {
          primary = "tenant_health_summary_search"
        }
        options = {
          count = 20
        }
        showLastUpdated = true
        showProgressBar = false
        title           = "Per-Tenant Job Health"
        type            = "splunk.table"
      }
      stuck_jobs_table = {
        dataSources = {
          primary = "stuck_jobs_search"
        }
        options = {
          count = 20
        }
        showLastUpdated = true
        showProgressBar = false
        title           = "Stuck Jobs > 5 Minutes"
        type            = "splunk.table"
      }
      failed_jobs_table = {
        dataSources = {
          primary = "failed_jobs_search"
        }
        options = {
          count = 20
        }
        showLastUpdated = true
        showProgressBar = false
        title           = "Failed Jobs"
        type            = "splunk.table"
      }
      canceled_jobs_table = {
        dataSources = {
          primary = "canceled_jobs_search"
        }
        options = {
          count = 20
        }
        showLastUpdated = true
        showProgressBar = false
        title           = "Canceled Jobs"
        type            = "splunk.table"
      }
      github_webhook_workflow_jobs_table = {
        dataSources = {
          primary = "github_webhook_workflow_jobs_search"
        }
        options = {
          count = 50
        }
        showLastUpdated = true
        showProgressBar = false
        title           = "GitHub Webhook Workflow Job Events"
        type            = "splunk.table"
      }
    }
    dataSources = {
      tenant_health_summary_search = {
        name = "Per-tenant job health"
        options = {
          enableSmartSources = true
          query              = <<-EOT
            index="${var.splunk_conf.index}" forgecicd_log_type="webhook" "Github event"
            | spath path=github.github-event output=github_event
            | spath path=github.repository output=repository
            | spath path=github.action output=action
            | spath path=github.status output=status
            | spath path=github.conclusion output=conclusion
            | spath path=github.name output=job
            | spath path=github.workflowJobId output=workflow_job_id
            | spath path=github.started_at output=started_at
            | where github_event="workflow_job"
            | where "$tenant$"="*" OR forgecicd_tenant="$tenant$"
            | where "$repository$"="*" OR like(repository, "%$repository$%")
            | eval started_epoch=strptime(started_at, "%Y-%m-%dT%H:%M:%SZ")
            | stats latest(_time) as last_seen latest(action) as latest_action latest(status) as latest_status latest(conclusion) as latest_conclusion latest(started_epoch) as latest_started_epoch by forgecicd_tenant workflow_job_id repository job
            | eval stuck=if(latest_status!="completed" AND isnotnull(latest_started_epoch) AND latest_started_epoch<=relative_time(now(), "-5m"), 1, 0)
            | eval failed=if(latest_status="completed" AND latest_conclusion="failure", 1, 0)
            | eval canceled=if(latest_status="completed" AND latest_conclusion="cancelled", 1, 0)
            | stats sum(stuck) as stuck_jobs_over_5m sum(failed) as failed_jobs sum(canceled) as canceled_jobs count as workflow_jobs by forgecicd_tenant
            | where stuck_jobs_over_5m>0 OR failed_jobs>0 OR canceled_jobs>0
            | sort - stuck_jobs_over_5m - failed_jobs - canceled_jobs
          EOT
          queryParameters = {
            earliest = "$global_time.earliest$"
            latest   = "$global_time.latest$"
          }
        }
        type = "ds.search"
      }
      stuck_jobs_search = {
        name = "Stuck workflow_job events"
        options = {
          enableSmartSources = true
          query              = <<-EOT
            index="${var.splunk_conf.index}" forgecicd_log_type="webhook" "Github event"
            | spath path=github.github-event output=github_event
            | spath path=github.repository output=repository
            | spath path=github.action output=action
            | spath path=github.status output=status
            | spath path=github.conclusion output=conclusion
            | spath path=github.name output=job
            | spath path=github.workflowJobId output=workflow_job_id
            | spath path=github.started_at output=started_at
            | where github_event="workflow_job"
            | where "$tenant$"="*" OR forgecicd_tenant="$tenant$"
            | where "$repository$"="*" OR like(repository, "%$repository$%")
            | eval started_epoch=strptime(started_at, "%Y-%m-%dT%H:%M:%SZ")
            | stats latest(_time) as last_seen latest(action) as latest_action latest(status) as latest_status latest(conclusion) as latest_conclusion latest(started_at) as started_at latest(started_epoch) as latest_started_epoch by forgecicd_tenant workflow_job_id repository job
            | eval age_sec=now()-latest_started_epoch
            | where latest_status!="completed" AND isnotnull(latest_started_epoch) AND age_sec>300
            | eval age=tostring(age_sec, "duration")
            | eval last_seen=strftime(last_seen, "%Y-%m-%d %H:%M:%S")
            | table forgecicd_tenant repository job workflow_job_id latest_action latest_status started_at age last_seen
            | sort - age_sec
          EOT
          queryParameters = {
            earliest = "$global_time.earliest$"
            latest   = "$global_time.latest$"
          }
        }
        type = "ds.search"
      }
      failed_jobs_search = {
        name = "Failed workflow_job events"
        options = {
          enableSmartSources = true
          query              = <<-EOT
            index="${var.splunk_conf.index}" forgecicd_log_type="webhook" "Github event"
            | spath path=github.github-event output=github_event
            | spath path=github.repository output=repository
            | spath path=github.action output=action
            | spath path=github.status output=status
            | spath path=github.conclusion output=conclusion
            | spath path=github.name output=job
            | spath path=github.workflowJobId output=workflow_job_id
            | spath path=github.started_at output=started_at
            | spath path=github.completed_at output=completed_at
            | spath path=github.github-delivery output=delivery_id
            | where github_event="workflow_job" AND status="completed" AND conclusion="failure"
            | where "$tenant$"="*" OR forgecicd_tenant="$tenant$"
            | where "$repository$"="*" OR like(repository, "%$repository$%")
            | eval started_epoch=strptime(started_at, "%Y-%m-%dT%H:%M:%SZ")
            | eval completed_epoch=strptime(completed_at, "%Y-%m-%dT%H:%M:%SZ")
            | eval duration=if(isnotnull(completed_epoch) AND isnotnull(started_epoch), tostring(completed_epoch-started_epoch, "duration"), null())
            | table _time forgecicd_tenant repository job workflow_job_id conclusion started_at completed_at duration delivery_id xray_trace_id message
            | sort - _time
          EOT
          queryParameters = {
            earliest = "$global_time.earliest$"
            latest   = "$global_time.latest$"
          }
        }
        type = "ds.search"
      }
      canceled_jobs_search = {
        name = "Canceled workflow_job events"
        options = {
          enableSmartSources = true
          query              = <<-EOT
            index="${var.splunk_conf.index}" forgecicd_log_type="webhook" "Github event"
            | spath path=github.github-event output=github_event
            | spath path=github.repository output=repository
            | spath path=github.action output=action
            | spath path=github.status output=status
            | spath path=github.conclusion output=conclusion
            | spath path=github.name output=job
            | spath path=github.workflowJobId output=workflow_job_id
            | spath path=github.started_at output=started_at
            | spath path=github.completed_at output=completed_at
            | spath path=github.github-delivery output=delivery_id
            | where github_event="workflow_job" AND status="completed" AND conclusion="cancelled"
            | where "$tenant$"="*" OR forgecicd_tenant="$tenant$"
            | where "$repository$"="*" OR like(repository, "%$repository$%")
            | eval started_epoch=strptime(started_at, "%Y-%m-%dT%H:%M:%SZ")
            | eval completed_epoch=strptime(completed_at, "%Y-%m-%dT%H:%M:%SZ")
            | eval duration=if(isnotnull(completed_epoch) AND isnotnull(started_epoch), tostring(completed_epoch-started_epoch, "duration"), null())
            | table _time forgecicd_tenant repository job workflow_job_id conclusion started_at completed_at duration delivery_id xray_trace_id message
            | sort - _time
          EOT
          queryParameters = {
            earliest = "$global_time.earliest$"
            latest   = "$global_time.latest$"
          }
        }
        type = "ds.search"
      }
      github_webhook_workflow_jobs_search = {
        name = "GitHub webhook workflow_job events"
        options = {
          enableSmartSources = true
          query              = <<-EOT
            index="${var.splunk_conf.index}" forgecicd_log_type="webhook" "Github event"
            | spath path=github.github-event output=github_event
            | spath path=github.repository output=repository
            | spath path=github.action output=action
            | spath path=github.status output=status
            | spath path=github.conclusion output=conclusion
            | spath path=github.name output=job
            | spath path=github.workflowJobId output=workflow_job_id
            | spath path=github.started_at output=started_at
            | spath path=github.completed_at output=completed_at
            | spath path=github.github-delivery output=delivery_id
            | spath path=github.github-hook-id output=hook_id
            | spath path=github.github-hook-installation-target-id output=installation_target_id
            | where github_event="workflow_job"
            | where "$tenant$"="*" OR forgecicd_tenant="$tenant$"
            | where "$repository$"="*" OR like(repository, "%$repository$%")
            | eval aws_region=coalesce(aws_region, region, Region)
            | eval aws_request_id='aws-request-id'
            | eval started_epoch=strptime(started_at, "%Y-%m-%dT%H:%M:%SZ")
            | eval completed_epoch=strptime(completed_at, "%Y-%m-%dT%H:%M:%SZ")
            | eval duration=if(isnotnull(completed_epoch) AND isnotnull(started_epoch), tostring(completed_epoch-started_epoch, "duration"), null())
            | table _time timestamp forgecicd_tenant forgecicd_region_alias forgecicd_vpc_alias aws_region forgecicd_log_type repository github_event action status conclusion job workflow_job_id started_at completed_at duration delivery_id hook_id installation_target_id aws_request_id xray_trace_id message
            | sort - _time
          EOT
          queryParameters = {
            earliest = "$global_time.earliest$"
            latest   = "$global_time.latest$"
          }
        }
        type = "ds.search"
      }
    }
    layout = {
      globalInputs = [
        "input_global_time",
        "input_tenant",
        "input_repository"
      ]
      layoutDefinitions = {
        layout = {
          options = {
            gutterSize = 9
          }
          structure = [
            {
              item = "tenant_health_summary_table"
              position = {
                h = 260
                w = 1200
                x = 0
                y = 0
              }
              type = "block"
            },
            {
              item = "stuck_jobs_table"
              position = {
                h = 340
                w = 1200
                x = 0
                y = 260
              }
              type = "block"
            },
            {
              item = "failed_jobs_table"
              position = {
                h = 360
                w = 600
                x = 0
                y = 600
              }
              type = "block"
            },
            {
              item = "canceled_jobs_table"
              position = {
                h = 360
                w = 600
                x = 600
                y = 600
              }
              type = "block"
            },
            {
              item = "github_webhook_workflow_jobs_table"
              position = {
                h = 620
                w = 1200
                x = 0
                y = 960
              }
              type = "block"
            }
          ]
          type = "grid"
        }
      }
      options = {}
      tabs = {
        items = [
          {
            label    = "Workflow Jobs"
            layoutId = "layout"
          }
        ]
      }
    }
    applicationProperties = {
      collapseNavigation = true
    }
  })

  github_webhook_workflow_jobs_eai_data = <<EOF
<dashboard version="2" theme="light">
    <label>GitHub Webhook Workflow Job Events</label>
    <description></description>
    <definition>
        <![CDATA[${local.github_webhook_workflow_jobs_definition}]]>
    </definition>
    <meta type="hiddenElements">
        <![CDATA[
{
    "hideEdit": false,
    "hideOpenInSearch": false,
    "hideExport": false
}
        ]]>
    </meta>
</dashboard>
EOF
}

resource "splunk_data_ui_views" "github_webhook_workflow_jobs" {
  name     = "github_webhook_workflow_jobs"
  eai_data = local.github_webhook_workflow_jobs_eai_data

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }
}
