--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

require "lua_utils_get"
require "check_redis_prefs"
local ts_utils = require "ts_utils"
local ts_gui_utils = require "ts_gui_utils"

local ts_profile = {}

local timeseries_id = "profile"

local timeseries_list = {{
    schema = "profile:traffic",
    id = timeseries_id,
    label = i18n("graphs.traffic"),
    description = i18n("graphs.metric_descr.profile_traffic"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.traffic'),
    timeseries = {
        bytes = {
            label = i18n('graphs.metric_labels.bytes'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        }
    },
    always_visibile = true
}}

function ts_profile.getTimeseries(tags, tsOptions)
    return timeseries_list
end

return ts_profile
