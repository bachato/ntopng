--
-- (C) 2013-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
local format_utils = require "format_utils"
local as_utils = require "as_utils"
local rest_utils = require "rest_utils"
local json = require("dkjson")

--
-- Get AS Name from IP
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/asn/get_as_data.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local ifid = _GET["ifid"] or interface.getId()
local epoch_begin = _GET["epoch_begin"] or 0
local epoch_end = _GET["epoch_end"] or 0
local is_live = toboolean(_GET["is_live"] or true)
local selected_asn = _GET["show_as"]

local ases_info = {}
local res = {}

interface.select(ifid)

if not is_live and not hasClickHouseSupport() then
    rest_utils.answer(rest_utils.consts.err.clickhouse_missing)
    return 
end

local options = {
    ifid = ifid,
    epoch_begin = epoch_begin,
    epoch_end = epoch_end,
    selected_asn = selected_asn
}

-- Now there are two possibilities:
-- - the traffic live is requested
-- - the historical traffic
if (is_live) and (is_live == true) then
    ases_info = as_utils.retrieveASLiveTraffic(options)
else
    ases_info = as_utils.retrieveASHistoricalTraffic(options)
end

-- In both cases however, live and historical, we miss the Currently Live info, so let's retrieve those
-- and sum the bytes with the live ones for Historical, use the live ones for live traffic

local live_flows_stats = interface.getActiveFlowsStats(nil, nil, false, nil, nil, nil, nil) or {}

for key, value in pairs(ases_info or {}) do
    local record = {}
    local add_record = true

    local asn = tonumber(value["asn"])
    local bytes_sent = value["bytes.sent"]
    local bytes_rcvd = value["bytes.rcvd"]

    record["asn"] = asn
    if value["num_hosts"] then
        record["num_hosts"] = value["num_hosts"]
        record["avg_host_score"] = math.floor(value["score"] / value["num_hosts"])
    end
    record["bytes_sent"] = bytes_sent
    record["bytes_rcvd"] = bytes_rcvd
    if value["alerted_flows"] then
        record["alerted_flows"] = value["alerted_flows"]["total"]
    end
    if bytes_sent and bytes_rcvd then
        record["traffic"] = bytes_sent + bytes_rcvd
    end
    record["seen_since"] = tonumber(value["seen.first"])
    record["score"] = value["score"]
    record["throughput"] = value["throughput_bps"]
    if value["asname"] then
        if (asn == 0) then
            value["asname"] = i18n('reserved_as')
        end
        record["asname"] = value["asname"]
    else
        record["asname"] = ntop.getASNameFromASN(tonumber(record["asn"]))
    end

    if asn == 0 then
        record["asname"] = "Private hosts"
    end

    if not is_live then
        local as_info = interface.getASInfo(asn)
        record["is_in_memory"] = not(as_info == nil)
    end

    record["breakdown"] = {
        bytes_sent = bytes_sent,
        bytes_rcvd = bytes_rcvd
    }

    if add_record then
        table.insert(res, record)
    end
end


local customer_asn, sub_customer_asn, remote_asn = as_utils.getAllConfigurations()
for pos, value in pairs(res or {}) do
    if value.asn ~= nil and value.asname ~= nil then
        local as = tostring(value.asn)
        if customer_asn[as] then
            value.is_customer_asn = true
        elseif sub_customer_asn[as] then
            value.is_sub_customer_asn = true
        elseif remote_asn[as] then
            value.is_remote_asn = true
        end
    end
end

rest_utils.answer(rest_utils.consts.success.ok, res)
