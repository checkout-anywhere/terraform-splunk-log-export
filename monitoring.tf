# Copyright 2021 Google LLC
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

resource "google_monitoring_group" "splunk-export-pipeline-group" {
  count  = var.workspace != "" ? 1 : 0

  display_name = "Splunk Log Export Group"
  project = var.workspace

  filter = "resource.metadata.name=starts_with(\"${var.dataflow_job_name}\")"
}

resource "google_monitoring_dashboard" "splunk-export-pipeline-dashboard" {
  count  = var.workspace != "" ? 1 : 0

  project = var.workspace
  dashboard_json = <<EOF
{
  "displayName": "Splunk Log Export Ops",
  "gridLayout": {
    "columns": "3",
    "widgets": [
      {
        "title": "Total Messages Exported (All-time)", 
        "scorecard": {
          "timeSeriesQuery": {
            "timeSeriesFilter": {
              "aggregation": {
                "alignmentPeriod": "60s",
                "crossSeriesReducer": "REDUCE_MAX",
                "perSeriesAligner": "ALIGN_MAX"
              },
              "filter": "metric.type=\"custom.googleapis.com/dataflow/outbound-successful-events\" resource.type=\"dataflow_job\" resource.label.\"job_name\"=\"splunk-export-pipeline-main-3258\""
            }
          }
        }
      },
      {
        "title": "Log Sink Data Rate ",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"logging.googleapis.com/exports/byte_count\" resource.type=\"logging_sink\"  resource.label.\"name\"=\"${local.project_log_sink_name}\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_RATE"
                  }
                }
              },
              "plotType": "STACKED_BAR",
              "minAlignmentPeriod": "60s"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "y1Axis",
            "scale": "LINEAR"
          },
          "chartOptions": {
            "mode": "COLOR"
          }
        }
      },
      {
        "title": "Logs Exported by Pipeline (Hourly)",
        "xyChart": {
          "chartOptions": {
            "mode": "COLOR"
          },
          "dataSets": [
            {
              "plotType": "STACKED_BAR",
              "targetAxis": "Y1",
              "timeSeriesQuery": {
                "timeSeriesQueryLanguage": "fetch dataflow_job\n| metric 'custom.googleapis.com/dataflow/outbound-successful-events'\n| filter (resource.job_name == '${local.dataflow_main_job_name}')\n| align next_older(1m)\n| every 1m\n| adjacent_delta\n| group_by 60m, sum(val())\n"
              }
            }
          ],
          "thresholds": [],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "y1Axis",
            "scale": "LINEAR"
          }
        }
      },
      {
        "title": "Backlog Size",
        "scorecard": {
          "timeSeriesQuery": {
            "timeSeriesFilter": {
              "filter": "metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\" resource.type=\"pubsub_subscription\" resource.label.\"subscription_id\"=\"${local.dataflow_input_subscription_name}\"",
              "aggregation": {
                "alignmentPeriod": "60s",
                "perSeriesAligner": "ALIGN_NEXT_OLDER",
                "crossSeriesReducer": "REDUCE_SUM"
              }
            }
          },
          "sparkChartView": {
            "sparkChartType": "SPARK_BAR"
          },
          "thresholds": [
            {
              "value": 10000,
              "color": "RED",
              "direction": "ABOVE"
            },
            {
              "value": 1000,
              "color": "YELLOW",
              "direction": "ABOVE"
            }
          ]
        }
      },
      {
        "title": "Input Throughput from Log Sink (EPS)",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"logging.googleapis.com/exports/log_entry_count\" resource.type=\"logging_sink\" resource.label.\"name\"=\"${local.project_log_sink_name}\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_RATE"
                  },
                  "secondaryAggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_MEAN"
                  }
                }
              },
              "plotType": "LINE",
              "minAlignmentPeriod": "60s"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "y1Axis",
            "scale": "LINEAR"
          },
          "chartOptions": {
            "mode": "COLOR"
          }
        }
      },
      {
        "title": "Output Throughput to Splunk (EPS)",
        "xyChart": {
          "chartOptions": {
            "mode": "COLOR"
          },
          "dataSets": [
            {
              "plotType": "LINE",
              "targetAxis": "Y1",
              "timeSeriesQuery": {
                "timeSeriesQueryLanguage": "fetch dataflow_job\n| filter (resource.job_name =='${local.dataflow_main_job_name}')\n| metric 'custom.googleapis.com/dataflow/outbound-successful-events'\n| align next_older(1m)\n| every 1m\n| adjacent_delta\n| align rate(1m)\n| every 1m"
              }
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "y1Axis",
            "scale": "LINEAR"
          }
        }
      },
      {
        "title": "Current Logs in Deadletter",
        "scorecard": {
          "timeSeriesQuery": {
            "timeSeriesFilter": {
              "filter": "metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\" resource.type=\"pubsub_subscription\" resource.label.\"subscription_id\"=monitoring.regex.full_match(\"${local.dataflow_output_deadletter_sub_name}\")",
              "aggregation": {
                "alignmentPeriod": "60s",
                "perSeriesAligner": "ALIGN_NEXT_OLDER",
                "crossSeriesReducer": "REDUCE_SUM"
              }
            }
          },
          "sparkChartView": {
            "sparkChartType": "SPARK_LINE"
          },
          "thresholds": [
            {
              "value": 100,
              "color": "RED",
              "direction": "ABOVE"
            },
            {
              "value": 0,
              "color": "YELLOW",
              "direction": "ABOVE"
            }
          ]
        }
      },
      {
        "title": "Splunk HEC - Errors",
        "xyChart": {
          "chartOptions": {
            "mode": "COLOR"
          },
          "dataSets": [
            {
              "plotType": "STACKED_BAR",
              "targetAxis": "Y1",
              "timeSeriesQuery": {
                "timeSeriesQueryLanguage": "fetch dataflow_job\n| filter resource.job_name =\"${local.dataflow_main_job_name}\"\n| metric 'custom.googleapis.com/dataflow/http-server-error-requests'\n| align next_older(1m)\n| every 1m\n| adjacent_delta"
              }
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "y1Axis",
            "scale": "LINEAR"
          }
        }
      },
      {
        "title": "Splunk HEC - Avg Batch Size (All-time)",
        "scorecard": {
          "sparkChartView": {
            "sparkChartType": "SPARK_LINE"
          },
          "timeSeriesQuery": {
            "apiSource": "DEFAULT_CLOUD",
            "timeSeriesFilter": {
              "aggregation": {
                "alignmentPeriod": "60s",
                "crossSeriesReducer": "REDUCE_MEAN",
                "perSeriesAligner": "ALIGN_MEAN"
              },
              "filter": "metric.type=\"custom.googleapis.com/dataflow/write_to_splunk_batch_MEAN\" resource.type=\"dataflow_job\" resource.label.\"job_name\"=\"${local.dataflow_main_job_name}\""
            }
          }
        }
      },
      {
        "title": "Splunk HEC - Avg Latency (ms) (All-time)",
        "scorecard": {
          "sparkChartView": {
            "sparkChartType": "SPARK_LINE"
          },
          "thresholds": [
            {
              "color": "RED",
              "direction": "ABOVE",
              "label": "",
              "value": 2000
            },
            {
              "color": "YELLOW",
              "direction": "ABOVE",
              "label": "",
              "value": 500
            }
          ],
          "timeSeriesQuery": {
            "apiSource": "DEFAULT_CLOUD",
            "timeSeriesFilter": {
              "aggregation": {
                "alignmentPeriod": "60s",
                "crossSeriesReducer": "REDUCE_MEAN",
                "perSeriesAligner": "ALIGN_MEAN"
              },
              "filter": "metric.type=\"custom.googleapis.com/dataflow/successful_write_to_splunk_latency_ms_MEAN\" resource.type=\"dataflow_job\" resource.label.\"job_name\"=\"${local.dataflow_main_job_name}\""
            }
          }
        }
      },
      {
        "title": "Total Messages Exported (All-time)",
        "scorecard": {
          "timeSeriesQuery": {
            "timeSeriesFilter": {
              "filter": "metric.type=\"custom.googleapis.com/dataflow/outbound-successful-events\" resource.type=\"dataflow_job\" resource.label.\"job_name\"=\"${local.dataflow_main_job_name}\"",
              "aggregation": {
                "alignmentPeriod": "60s",
                "crossSeriesReducer": "REDUCE_MAX",
                "perSeriesAligner": "ALIGN_MAX"
              }
            }
          },
          "sparkChartView": {
            "sparkChartType": "SPARK_BAR"
          }
        }
      },
      {
        "title": "Total Messages Failed",
        "xyChart": {
          "dataSets": [
            {
              "plotType": "LINE",
              "targetAxis": "Y1",
              "timeSeriesQuery": {
                "timeSeriesQueryLanguage": "fetch dataflow_job\n| filter resource.job_name =\"${local.dataflow_main_job_name}\"\n| metric 'custom.googleapis.com/dataflow/total-failed-messages'\n| align next_older(1m)\n| every 1m\n| adjacent_delta"
              }
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "y1Axis",
            "scale": "LINEAR"
          },
          "chartOptions": {
            "mode": "COLOR"
          }
        }
      },
      {
        "title": "Total Messages Replayed",
        "xyChart": {
          "dataSets": [
            {
              "plotType": "LINE",
              "targetAxis": "Y1",
              "timeSeriesQuery": {
                "timeSeriesQueryLanguage": "fetch dataflow_job\n| filter resource.job_name =\"${local.dataflow_replay_job_name}\"\n| metric 'dataflow.googleapis.com/job/elements_produced_count'\n| align next_older(1m)\n| every 1m\n| adjacent_delta"
              }
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "y1Axis",
            "scale": "LINEAR"
          },
          "chartOptions": {
            "mode": "COLOR"
          }
        }
      },

      {
        "title": "Log Sink Error",
        "xyChart": {
          "chartOptions": {
            "mode": "COLOR"
          },
          "dataSets": [
            {
              "minAlignmentPeriod": "60s",
              "plotType": "STACKED_BAR",
              "targetAxis": "Y1",
              "timeSeriesQuery": {
                "apiSource": "DEFAULT_CLOUD",
                "timeSeriesFilter": {
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "crossSeriesReducer": "REDUCE_NONE",
                    "perSeriesAligner": "ALIGN_SUM"
                  },
                  "filter": "metric.type=\"logging.googleapis.com/exports/error_count\" resource.type=\"logging_sink\" resource.label.\"name\"=\"${local.project_log_sink_name}\""
                }
              }
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "y1Axis",
            "scale": "LINEAR"
          }
        }
      },
      {
        "title": "Pub/Sub Publishing Rate",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"pubsub.googleapis.com/topic/send_message_operation_count\" resource.type=\"pubsub_topic\" resource.label.\"topic_id\"=\"${local.dataflow_input_topic_name}\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_RATE",
                    "crossSeriesReducer": "REDUCE_SUM",
                    "groupByFields": [
                      "resource.label.\"topic_id\""
                    ]
                  },
                  "secondaryAggregation": {
                    "alignmentPeriod": "60s"
                  }
                }
              },
              "plotType": "LINE",
              "minAlignmentPeriod": "60s"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "y1Axis",
            "scale": "LINEAR"
          },
          "chartOptions": {
            "mode": "COLOR"
          }
        }
      },
      {
        "title": "Pub/Sub Streaming Pull Rate",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"pubsub.googleapis.com/subscription/pull_message_operation_count\" resource.type=\"pubsub_subscription\" resource.label.\"subscription_id\"=\"${local.dataflow_input_subscription_name}\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_RATE",
                    "crossSeriesReducer": "REDUCE_SUM",
                    "groupByFields": [
                      "resource.label.\"subscription_id\""
                    ]
                  },
                  "secondaryAggregation": {
                    "alignmentPeriod": "60s"
                  }
                }
              },
              "plotType": "LINE",
              "minAlignmentPeriod": "60s"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "y1Axis",
            "scale": "LINEAR"
          },
          "chartOptions": {
            "mode": "COLOR"
          }
        }
      },
      {
        "title": "Data Lag in Backlog",
        "scorecard": {
          "timeSeriesQuery": {
            "timeSeriesFilter": {
              "filter": "metric.type=\"pubsub.googleapis.com/subscription/oldest_unacked_message_age\" resource.type=\"pubsub_subscription\" resource.label.\"subscription_id\"=\"${local.dataflow_input_subscription_name}\"",
              "aggregation": {
                "alignmentPeriod": "60s",
                "perSeriesAligner": "ALIGN_NEXT_OLDER",
                "crossSeriesReducer": "REDUCE_MEAN"
              }
            }
          },
          "sparkChartView": {
            "sparkChartType": "SPARK_LINE"
          },
          "thresholds": [
            {
              "value": 60,
              "color": "YELLOW",
              "direction": "ABOVE"
            }
          ]
        }
      },
      {
        "title": "Dataflow Cores In Use",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"dataflow.googleapis.com/job/current_num_vcpus\" resource.type=\"dataflow_job\" resource.label.\"job_name\"=\"${local.dataflow_main_job_name}\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_MEAN",
                    "crossSeriesReducer": "REDUCE_SUM",
                    "groupByFields": [
                      "resource.label.\"job_name\""
                    ]
                  }
                },
                "unitOverride": "1"
              },
              "plotType": "LINE",
              "minAlignmentPeriod": "60s"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "y1Axis",
            "scale": "LINEAR"
          },
          "chartOptions": {
            "mode": "COLOR"
          }
        }
      },
      {
        "title": "Dataflow CPU Utilization",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" resource.type=\"gce_instance\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_MEAN",
                    "crossSeriesReducer": "REDUCE_MEAN",
                    "groupByFields": [
                      "metadata.user_labels.\"dataflow_job_name\""
                    ]
                  }
                },
                "unitOverride": "ratio"
              },
              "plotType": "LINE",
              "minAlignmentPeriod": "60s"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "y1Axis",
            "scale": "LINEAR"
          },
          "chartOptions": {
            "mode": "COLOR"
          }
        }
      },
      {
        "title": "Dataflow System Lag",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"dataflow.googleapis.com/job/system_lag\" resource.type=\"dataflow_job\" resource.label.\"job_name\"=\"${local.dataflow_main_job_name}\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_MEAN",
                    "crossSeriesReducer": "REDUCE_SUM"
                  },
                  "secondaryAggregation": {
                    "alignmentPeriod": "60s"
                  }
                }
              },
              "plotType": "LINE",
              "minAlignmentPeriod": "60s"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "y1Axis",
            "scale": "LINEAR"
          },
          "chartOptions": {
            "mode": "COLOR"
          }
        }
      },
      {
        "title": "Dataflow worker - Error logs",
        "logsPanel": {
          "filter": "resource.type=\"dataflow_step\"\nlog_id(\"dataflow.googleapis.com/worker\")\nseverity=ERROR",
          "resourceNames": [
            "projects/798413660424"
          ]
        }
      },
      {
        "title": "Dataflow worker - UDF debug logs",
        "logsPanel": {
          "filter": "resource.type=\"dataflow_step\"\nlog_id(\"dataflow.googleapis.com/worker\")\njsonPayload.logger=\"System.out\"",
          "resourceNames": [
            "projects/798413660424"
          ]
        }
      }
    ]
  }
}

EOF
}