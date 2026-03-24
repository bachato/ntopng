--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
local ts_gui_utils = {}

local ts_utils = require "ts_utils"

-- #################################

local series_extra_info = {
    alerts = {
        color = '#2d99bd'
    },
    bytes = {
        color = '#1f77b4'
    },
    packets = {
        color = '#1f77b4'
    },
    bytes_sent = {
        color = '#c6d9fd'
    },
    bytes_rcvd = {
        color = '#90ee90'
    },
    devices = {
        color = '#ac9ddf'
    },
    flows = {
        color = '#8c6f94'
    },
    hosts = {
        color = '#ff7f0e'
    },
    score = {
        color = '#ff3231'
    },
    cli_score = {
        color = '#690504'
    },
    srv_score = {
        color = '#f5a2a2'
    },
    default = {
        color = '#c6d9fd'
    },
    usage_sent = {
        color = '#b3abd6'
    },
    usage_rcvd = {
        color = '#2f4241'
    }
}

-- #################################

function ts_gui_utils.get_timeseries_color(subject)
    if series_extra_info[subject] then
        return series_extra_info[subject].color
    end

    -- Safety check, if an improper value is given,
    -- then return a default color
    return series_extra_info.default.color
end

-- #################################

function ts_gui_utils.removeEmptyTimeseries(timeseries, tags)
    for index, ts_info in ipairs(timeseries) do
        local tot_serie = ts_utils.queryTotal(ts_info.schema, tags.epoch_begin, tags.epoch_end, tags)
        if not tot_serie and (not ts_info.always_visibile) then
            table.remove(timeseries, index)
        end
    end
    return timeseries
end

-- #################################

return ts_gui_utils
