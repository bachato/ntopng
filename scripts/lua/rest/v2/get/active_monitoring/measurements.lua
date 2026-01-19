--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- ####################################

require "http_lint"
require "check_redis_prefs"
require "ntop_utils"
local active_monitoring_utils = require "am_utils"
local rest_utils = require "rest_utils"

local rc = rest_utils.consts.success.ok

-- ################################################

local rsp = {}
local measurements_info = {}

for key, info in pairs(active_monitoring_utils.getMeasurementsInfo()) do
    if key == "vulnerability_scan" or key == "cve_changes_detected" or key == "ports_changes_detected" then
        goto continue
    end
    local label = i18n(info.i18n_label) or info.i18n_label
    local unit = i18n(info.i18n_unit) or info.i18n_unit

    measurements_info[key] = {
        label = label,
        granularities = active_monitoring_utils.getAvailableGranularities(key),
        key = key,
        operator = info.operator,
        unit = unit,
        force_host = info.force_host,
        max_threshold = info.max_threshold,
        default_threshold = info.default_threshold
    }

    ::continue::
end

for _, info in pairsByKeys(measurements_info, asc) do
    rsp[#rsp + 1] = info
end

-- ################################################

rest_utils.answer(rc, rsp)
