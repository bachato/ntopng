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

local ts_mac = {}

local timeseries_id = "host"

local timeseries_list = {{
    schema = "mac:traffic",
    id = timeseries_id,
    label = i18n("graphs.traffic_rxtx"),
    description = i18n("graphs.metric_descr.mac_traffic_rxtx"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.traffic'),
    timeseries = {
        bytes_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = ts_gui_utils.get_timeseries_color('bytes_sent')
        },
        bytes_rcvd = {
            invert_direction = true,
            label = i18n('graphs.metric_labels.rcvd'),
            color = ts_gui_utils.get_timeseries_color('bytes_rcvd')
        }
    },
    always_visibile = true,
    default_visible = true
}}

local function addTopTimeseries(tags, tsOptions)
    local timeseries = {}
    local mac_ts_enabled = ntop.getCache("ntopng.prefs.l2_device_rrd_creation")
    local mac_top_ts_enabled = ntop.getCache("ntopng.prefs.l2_device_ndpi_timeseries_creation")

    -- Top l7 Categories
    if mac_ts_enabled and mac_top_ts_enabled then
        local series = ts_utils.listSeries("mac:ndpi_categories", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local category_name = getCategoryLabel(serie.category, interface.getnDPICategoryId(serie.category))
                local tot = 0
                tmp_tags.category = category_name
                local tot_serie = ts_utils.queryTotal("mac:ndpi_categories", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:mac:ndpi_categories",
                        group = i18n("graphs.category"),
                        priority = 3,
                        query = "category:" .. category_name,
                        label = category_name,
                        disable_perc_95_ts = true,
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        timeseries = {
                            bytes = {
                                label = category_name,
                                color = ts_gui_utils.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    return timeseries
end

function ts_mac.getTimeseries(tags, tsOptions)
    local timeseries = {}
    local emptyEpoch = false
    if (not tags.epoch_begin) or (not tags.epoch_end) then
        emptyEpoch = true
    end
    if (not emptyEpoch) then
        timeseries = addTopTimeseries(tags, tsOptions)
    end
    timeseries = table.merge(timeseries, timeseries_list)
    return timeseries
end

return ts_mac
