--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

require "check_redis_prefs"
local ts_utils = require "ts_utils"
local ts_gui_utils = require "ts_gui_utils"

local ts_all_asn = {}

local timeseries_id = "asn"

local function addTopTimeseries(tags, tsOptions)
    local timeseries = {}
    local asn_ts_enabled = ntop.getCache("ntopng.prefs.asn_rrd_creation")
    if asn_ts_enabled then
        local format_utils = require "format_utils"

        local series = ts_utils.listSeries("asn:traffic", table.clone(tags), tags.epoch_begin)
        if not table.empty(series) then
            local tmp_tags = table.clone(tags)
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.asn = serie.asn
                local tot_serie = ts_utils.queryTotal("asn:traffic", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "asn:traffic",
                        id = timeseries_id,
                        priority = 2,
                        query = "asn:" .. serie.asn,
                        label = tostring(format_utils.formatASN(serie.asn, false, false)),
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        timeseries = {
                            bytes_sent = {
                                label = serie.asn .. " " .. i18n('graphs.metric_labels.sent'),
                                color = ts_gui_utils.get_timeseries_color('bytes')
                            },
                            bytes_rcvd = {
                                label = serie.asn .. " " .. i18n('graphs.metric_labels.rcvd'),
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

function ts_all_asn.getTimeseries(tags, tsOptions)
    local timeseries = {}
    local emptyEpoch = false
    if (not tags.epoch_begin) or (not tags.epoch_end) then
        emptyEpoch = true
    end
    if (not emptyEpoch) then
        timeseries = addTopTimeseries(tags, emptyEpoch, tsOptions)
    end
    return timeseries
end

return ts_all_asn
