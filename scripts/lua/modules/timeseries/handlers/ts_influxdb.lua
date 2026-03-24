--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

require "label_utils"
require "check_redis_prefs"
local ts_utils = require "ts_utils"
local ts_gui_utils = require "ts_gui_utils"

local ts_redis = {}

local timeseries_id = "influxdb"

local timeseries_list = {{
   schema = "influxdb:storage_size",
   id = timeseries_id,
   label = i18n("traffic_recording.storage_utilization"),
   description = i18n("graphs.metric_descr.influxdb_storage_utilization"),
   priority = 0,
   measure_unit = "bytes",
   scale = i18n('graphs.metric_labels.bytes'),
   timeseries = {
      disk_bytes = {
         label = i18n('graphs.metric_labels.bytes'),
         color = ts_gui_utils.get_timeseries_color('bytes')
      }
   },
   always_visibile = true
}, {
   schema = "influxdb:memory_size",
   id = timeseries_id,
   label = i18n("about.ram_memory"),
   description = i18n("graphs.metric_descr.influxdb_ram_memory"),
   priority = 0,
   measure_unit = "bytes",
   scale = i18n('graphs.metric_labels.bytes'),
   timeseries = {
      mem_bytes = {
         label = i18n('graphs.metric_labels.bytes'),
         color = ts_gui_utils.get_timeseries_color('bytes')
      }
   }
}, {
   schema = "influxdb:write_successes",
   id = timeseries_id,
   label = i18n("system_stats.write_througput"),
   description = i18n("graphs.metric_descr.influxdb_write_througput"),
   priority = 0,
   measure_unit = "number",
   scale = i18n('graphs.metric_labels.throughput'),
   timeseries = {
      points = {
         label = i18n('graphs.metric_labels.num_points'),
         color = ts_gui_utils.get_timeseries_color('default')
      }
   }
}, {
   schema = "influxdb:exports",
   id = timeseries_id,
   label = i18n("system_stats.exports_label"),
   description = i18n("graphs.metric_descr.influxdb_exports_label"),
   priority = 0,
   measure_unit = "number",
   scale = i18n('graphs.metric_labels.exports'),
   timeseries = {
      num_exports = {
         label = i18n('system_stats.exports_label'),
         color = ts_gui_utils.get_timeseries_color('default')
      }
   }
}, {
   schema = "influxdb:exported_points",
   id = timeseries_id,
   label = i18n("system_stats.exported_points"),
   description = i18n("graphs.metric_descr.influxdb_exported_points"),
   priority = 0,
   measure_unit = "number",
   scale = i18n('graphs.metric_labels.exports'),
   timeseries = {
      points = {
         label = i18n('graphs.metric_labels.num_points'),
         color = ts_gui_utils.get_timeseries_color('default')
      }
   }
}, {
   schema = "influxdb:dropped_points",
   id = timeseries_id,
   label = i18n("system_stats.dropped_points"),
   description = i18n("graphs.metric_descr.influxdb_dropped_points"),
   priority = 0,
   measure_unit = "number",
   scale = i18n('graphs.metric_labels.drops'),
   timeseries = {
      points = {
         label = i18n('graphs.metric_labels.num_points'),
         color = ts_gui_utils.get_timeseries_color('default')
      }
   }
}, {
   schema = "influxdb:rtt",
   id = timeseries_id,
   label = i18n("graphs.num_ms_rtt"),
   description = i18n("graphs.metric_descr.influxdb_num_ms_rtt"),
   priority = 0,
   measure_unit = "ms",
   scale = i18n('graphs.metric_labels.rtt'),
   timeseries = {
      millis_rtt = {
         label = i18n('graphs.num_ms_rtt'),
         color = ts_gui_utils.get_timeseries_color('default')
      }
   }
}}

function ts_redis.getTimeseries(tags, tsOptions)
    return timeseries_list
end

return ts_redis
