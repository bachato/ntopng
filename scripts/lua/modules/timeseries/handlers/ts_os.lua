--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local ts_gui_utils = require "ts_gui_utils"

local ts_os = {}

local timeseries_id = "os"

local timeseries_list = {{
    schema = "os:traffic",
    id = timeseries_id,
    label = i18n("graphs.traffic_rxtx"),
    description = i18n("graphs.metric_descr.os_traffic_rxtx"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.traffic'),
    timeseries = {
        bytes_egress = {
            label = i18n('graphs.metrics_suffixes.egress'),
            color = ts_gui_utils.get_timeseries_color('bytes_sent')
        },
        bytes_ingress = {
            label = i18n('graphs.metrics_suffixes.ingress'),
            color = ts_gui_utils.get_timeseries_color('bytes_rcvd')
        }
    },
    always_visibile = true,
    default_visible = true
}}

function ts_os.getTimeseries(tags, tsOptions)
    return timeseries_list
end

return ts_os
