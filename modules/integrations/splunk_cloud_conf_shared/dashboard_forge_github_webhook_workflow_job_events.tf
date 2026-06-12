locals {
  forge_github_webhook_workflow_job_events_definition = jsonencode({
    title       = "Forge GitHub Webhook Workflow Job Events"
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
            [for tenant in sort(var.splunk_conf.tenant_names) : { label = tenant, value = tenant }]
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
        title           = "Per-Tenant Completed Job Outcomes"
        type            = "splunk.table"
      }
      ec2_queued_jobs_table = {
        dataSources = {
          primary = "ec2_queued_jobs_search"
        }
        options = {
          count = 20
        }
        showLastUpdated = true
        showProgressBar = false
        title           = "EC2 Queued Jobs > 5 Minutes"
        type            = "splunk.table"
      }
      k8s_queued_jobs_table = {
        dataSources = {
          primary = "k8s_queued_jobs_search"
        }
        options = {
          count = 20
        }
        showLastUpdated = true
        showProgressBar = false
        title           = "Non EC2 Queued Jobs > 5 Minutes"
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
        title           = "Forge GitHub Webhook Workflow Job Events"
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
            | where github_event="workflow_job"
            | where "$tenant$"="*" OR forgecicd_tenant="$tenant$"
            | where "$repository$"="*" OR like(repository, "%$repository$%")
            | eval failed=if(status="completed" AND conclusion="failure", 1, 0)
            | eval canceled=if(status="completed" AND (conclusion="cancelled" OR conclusion="canceled"), 1, 0)
            | stats sum(failed) as failed_jobs sum(canceled) as canceled_jobs count as workflow_jobs by forgecicd_tenant
            | where failed_jobs>0 OR canceled_jobs>0
            | sort - failed_jobs - canceled_jobs
          EOT
          queryParameters = {
            earliest = "$global_time.earliest$"
            latest   = "$global_time.latest$"
          }
        }
        type = "ds.search"
      }
      ec2_queued_jobs_search = {
        name = "EC2 queued workflow_job events"
        options = {
          enableSmartSources = true
          query              = <<-EOT
            index="${var.splunk_conf.index}" ((forgecicd_log_type=webhook github.status=*) OR ("Successfully dispatched job for"))
            | rex field=message "to the queue (?<queued_url>https?://\S+)\s-\sJob ID:\s(?<dispatch_workflowJobId>\d+)"
            | eval workflowJobId=coalesce('github.workflowJobId', dispatch_workflowJobId)
            | where isnotnull(workflowJobId)
            | where "$tenant$"="*" OR forgecicd_tenant="$tenant$"
            | where "$repository$"="*" OR like('github.repository', "%$repository$%") OR like(queued_url, "%$repository$%")
            | eval is_webhook=if(forgecicd_log_type="webhook", 1, 0)
            | eval is_queued=if(forgecicd_log_type="webhook" AND 'github.status'="queued", 1, 0)
            | eval is_dispatch=if(searchmatch("Successfully dispatched job for"), 1, 0)
            | stats
                count(eval(is_webhook=1)) as total_events
                sum(is_queued) as queued_count
                max(is_dispatch) as has_dispatch
                min(_time) as first_seen
                max(_time) as last_seen
                latest(github.name) as job_name
                latest(forgecicd_tenant) as forgecicd_tenant
                latest(github.repository) as repository
                latest(github.started_at) as started_at
                values(github.labels) as labels
                values(github.github-delivery) as github_deliveries
                values(queued_url) as queued_url
              by workflowJobId
            | where total_events = queued_count
            | where has_dispatch = 1
            | eval stuck_since=strftime(first_seen, "%Y-%m-%dT%H:%M:%S%Z"), stuck_minutes=round((now() - first_seen) / 60, 1)
            | where stuck_minutes > 5
            | sort - stuck_minutes
            | table workflowJobId job_name repository labels started_at stuck_since stuck_minutes queued_url github_deliveries forgecicd_tenant
          EOT
          queryParameters = {
            earliest = "$global_time.earliest$"
            latest   = "$global_time.latest$"
          }
        }
        type = "ds.search"
      }
      k8s_queued_jobs_search = {
        name = "Non EC2 queued workflow_job events"
        options = {
          enableSmartSources = true
          query              = <<-EOT
            index="${var.splunk_conf.index}" ((forgecicd_log_type=webhook github.status=*) OR ("Received event contains runner labels" "Job ID:"))
            | rex field=message "Received event contains runner labels '(?<runner_labels>[^']+)' from '(?<warning_repo>[^']+)'.*Job ID:\s(?<warning_workflowJobId>\d+)"
            | eval workflowJobId=coalesce('github.workflowJobId', warning_workflowJobId)
            | where isnotnull(workflowJobId)
            | where "$tenant$"="*" OR forgecicd_tenant="$tenant$"
            | eval repository=coalesce('github.repository', warning_repo)
            | where "$repository$"="*" OR like(repository, "%$repository$%")
            | eval is_webhook=if(forgecicd_log_type="webhook", 1, 0)
            | eval is_queued=if(forgecicd_log_type="webhook" AND 'github.status'="queued", 1, 0)
            | eval has_runner_label_warning=if(searchmatch("Received event contains runner labels"), 1, 0)
            | stats
                count(eval(is_webhook=1)) as total_events
                sum(is_queued) as queued_count
                max(has_runner_label_warning) as has_runner_label_warning
                min(_time) as first_seen
                max(_time) as last_seen
                latest(github.name) as job_name
                latest(forgecicd_tenant) as forgecicd_tenant
                latest(github.repository) as repository
                latest(github.started_at) as started_at
                values(github.labels) as github_labels
                values(github.github-delivery) as github_deliveries
                values(runner_labels) as runner_labels
                values(warning_repo) as warning_repo
              by workflowJobId
            | where total_events = queued_count
            | where has_runner_label_warning = 1
            | eval stuck_since=strftime(first_seen, "%Y-%m-%dT%H:%M:%S%Z"), stuck_minutes=round((now() - first_seen) / 60, 1)
            | where stuck_minutes > 5
            | eval labels=coalesce(mvjoin(runner_labels, ", "), mvjoin(github_labels, ", "))
            | sort - stuck_minutes
            | table workflowJobId job_name repository warning_repo labels started_at stuck_since stuck_minutes github_deliveries forgecicd_tenant
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
              item = "ec2_queued_jobs_table"
              position = {
                h = 340
                w = 600
                x = 0
                y = 260
              }
              type = "block"
            },
            {
              item = "k8s_queued_jobs_table"
              position = {
                h = 340
                w = 600
                x = 600
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

  forge_github_webhook_workflow_job_events_eai_data = <<EOF
<dashboard version="2" theme="light">
    <label>Forge GitHub Webhook Workflow Job Events</label>
    <description></description>
    <definition>
        <![CDATA[${local.forge_github_webhook_workflow_job_events_definition}]]>
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

resource "splunk_data_ui_views" "forge_github_webhook_workflow_job_events" {
  name     = "forge_github_webhook_workflow_job_events"
  eai_data = local.forge_github_webhook_workflow_job_events_eai_data

  acl {
    app     = var.splunk_conf.acl.app
    owner   = var.splunk_conf.acl.owner
    sharing = var.splunk_conf.acl.sharing
    read    = var.splunk_conf.acl.read
    write   = var.splunk_conf.acl.write
  }
}
