--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

require "check_redis_prefs"
local ts_utils = require "ts_utils"
local ts_gui_utils = require "ts_gui_utils"

local ts_active_monitoring = {}

local timeseries_id = "am"

local function addTopTimeseries(tags, tsOptions)
    local timeseries = {}
    local am_utils = require "am_utils"

    -- google.com,metric:cicmp
    local data = split(tags.host, ',')
    local metric = split(data[2], ':')[2]

    local host = am_utils.getHost(data[1], metric)
    local measurement_info = {}

    local label = i18n("graphs.num_ms_rtt")
    local measure_label = i18n("flow_details.round_trip_time")
    local measure_unit = 'ms'

    if host then
        measurement_info = am_utils.getMeasurementInfo(host.measurement) or {}
    end

    if measurement_info then
        label = i18n(measurement_info.i18n_am_ts_label) or measurement_info.i18n_am_ts_label
        measure_label = i18n(measurement_info.i18n_am_ts_metric) or measurement_info.i18n_am_ts_metric
        if (measurement_info.i18n_unit) and (measurement_info.i18n_unit == 'field_units.mbits') then
            measure_unit = 'bps'
        elseif (measurement_info.i18n_unit) and (measurement_info.i18n_unit == 'field_units.percentage') then
            measure_unit = 'percentage'
        end
    end

    if measurement_info.force_host then
        -- Special case of speedtest
        timeseries[#timeseries + 1] = {
            schema = "am_host:val_hour",
            id = timeseries_id,
            label = label,
            priority = 0,
            measure_unit = measure_unit,
            scale = measure_label,
            timeseries = {
                value = {
                    label = measure_label,
                    color = ts_gui_utils.get_timeseries_color('default')
                }
            }
        }
    else
        timeseries[#timeseries + 1] = {
            schema = "am_host:val_min",
            id = timeseries_id,
            label = label,
            priority = 0,
            measure_unit = measure_unit,
            scale = measure_label,
            timeseries = {
                value = {
                    label = measure_label,
                    color = ts_gui_utils.get_timeseries_color('default')
                }
            }
        }
    end

    if (measurement_info) and (table.len(measurement_info.additional_timeseries) > 0) then
        for _, ts_information in ipairs(measurement_info.additional_timeseries) do
            timeseries[#timeseries + 1] = {
                schema = ts_information.schema .. "_min",
                id = timeseries_id,
                label = ts_information.label,
                priority = 0,
                measure_unit = "ms",
                scale = i18n('graphs.metric_labels.ms')
            }
            local am_schema_info = {}

            if ts_information.schema == 'am_host:jitter_stats' then
                am_schema_info = {
                    latency = {
                        label = i18n('flow_details.mean_rtt'),
                        color = ts_gui_utils.get_timeseries_color('default')
                    },
                    jitter = {
                        label = i18n('flow_details.rtt_jitter'),
                        color = ts_gui_utils.get_timeseries_color('default')
                    }
                }
            elseif ts_information.schema == 'am_host:cicmp_stats' then
                am_schema_info = {
                    min_rtt = {
                        label = i18n('graphs.min_rtt'),
                        color = ts_gui_utils.get_timeseries_color('default')
                    },
                    max_rtt = {
                        label = i18n('graphs.max_rtt'),
                        color = ts_gui_utils.get_timeseries_color('default')
                    }
                }
            elseif ts_information.schema == 'am_host:http_stats' then
                am_schema_info = {
                    lookup_ms = {
                        label = i18n('graphs.name_lookup'),
                        color = ts_gui_utils.get_timeseries_color('default')
                    },
                    other_ms = {
                        label = i18n('other'),
                        color = ts_gui_utils.get_timeseries_color('default')
                    }
                }
            elseif ts_information.schema == 'am_host:upload' then
                -- Speedtest specialcase
                am_schema_info = {
                    speed = {
                        label = i18n('active_monitoring_stats.upload_speed'),
                        color = ts_gui_utils.get_timeseries_color('bytes')
                    }
                }
                timeseries[#timeseries]['measure_unit'] = 'bps'
            elseif ts_information.schema == 'am_host:latency' then
                -- Speedtest specialcase
                am_schema_info = {
                    latency = {
                        label = ts_information.metrics_labels[1],
                        color = ts_gui_utils.get_timeseries_color('number')
                    }
                }
            end

            if measurement_info.force_host then
                -- Speedtest special case
                timeseries[#timeseries]['schema'] = ts_information.schema .. "_hour"
            end

            timeseries[#timeseries]['timeseries'] = am_schema_info
        end
    end

    return timeseries
end

function ts_active_monitoring.getTimeseries(tags, tsOptions)
    local timeseries = {}
    local emptyEpoch = false
    if (not tags.epoch_begin) or (not tags.epoch_end) then
        emptyEpoch = true
    end
    if not emptyEpoch then
        timeseries = addTopTimeseries(tags, emptyEpoch, tsOptions)
    end
    return timeseries
end

return ts_active_monitoring
