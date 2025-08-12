--
-- (C) 2013-25 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils_gui"
local rest_utils = require("rest_utils")
local country_code = require "country_keys"

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
    rc = rest_utils.consts.err.invalid_interface
    rest_utils.answer(rc)
    return
end

interface.select(ifid)

local rsp = {}
local data = {}
local host_key = _GET["host"]
local hosts_category = tonumber(_GET["hosts_category"] or 0)
local host_info = url2hostinfo(_GET)
local MAX_HOSTS = 512

-- ############################################################

local function handlePeer(host_key)
    local host_data = interface.getHostInfo(host_key)

    return host_data
end

-- ##############

-- Get single host data (host_key is the requested IP)
if (host_key) then
    -- From req create a table
    local host_info = url2hostinfo(_GET)
    local flows = getTopFlowPeers(hostinfo2hostkey(host_info),
                                  MAX_HOSTS - hosts_count, nil,
                                  {detailsLevel = "max"})

    data.hosts = {}

    for key, value in pairs(flows) do

        -- create table for client IP
        local h = handlePeer(value["cli.ip"])
        if h ~= nil then data.hosts[value["cli.ip"]] = h end

        -- create table for server IP
        local h = handlePeer(value["srv.ip"])
        if h ~= nil then data.hosts[value["srv.ip"]] = h end

    end

    -- Active hosts
elseif (hosts_category == 0) then
    data =
        interface.getHostsInfo(false, "column_traffic", MAX_HOSTS, nil, false --[[ Desc order ]] )
    -- Alerted hosts
elseif (hosts_category == 1) then
    data =
        interface.getHostsInfo(false, "column_score", MAX_HOSTS, nil, false --[[ Desc order ]] ,
                               nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
                               nil, nil, nil, nil, nil, nil, nil, true) -- Get alerted hosts
    -- Local hosts
elseif (hosts_category == 2) then
    data = interface.getLocalHostsInfo(false, "column_traffic", MAX_HOSTS, nil,
                                       false --[[ Desc order ]] )
    -- Remote hosts
elseif (hosts_category == 3) then
    data = interface.getRemoteHostsInfo(false, "column_traffic", MAX_HOSTS, nil,
                                        false --[[ Desc order ]] )
else
    data = nil
end

-- tprint(data)
if (data) and (data["hosts"]) then
    for address, value in pairs(data["hosts"]) do
        if value["latitude"] ~= 0 or value["longitude"] ~= 0 then
            local country = value["country"]
            local country_info = country_code.get_country_info(country)

            if (country_info) then
                local iso3_country = country_info[1]
                local country_id = country_info[2]

                if (hosts_category == 1) and (value.score == 0) then
                    traceError(TRACE_ERROR, TRACE_CONSOLE,
                               "Requested alerted hosts, but got Host with no score [Host: " ..
                                   address .. "][Score: " .. value.score .. "]")
                    goto skip_host
                end
                --[[
                traceError(TRACE_NORMAL, TRACE_CONSOLE,
                           "[Host: " .. address .. "][Score: " .. value.score ..
                               "][Num Alerts: " .. value["num_alerts"] +
                               value["active_alerted_flows"] .. "]")
                ]]
                local host = {
                    lat = value["latitude"],
                    lng = value["longitude"],
                    isRoot = false,
                    country = iso3_country,
                    country_id = country_id,
                    ip = address,
                    scoreClient = value["score.as_client"],
                    scoreServer = value["score.as_server"],
                    numAlerts = value["active_alerted_flows"],
                    country_code = country,
                    isAlert = value.score > 0
                }

                if not isEmptyString(value["city"]) then
                    host["city"] = value["city"]
                end

                rsp[#rsp + 1] = host

                ::skip_host::
            end
        end
    end

end

rest_utils.answer(rest_utils.consts.success.ok, rsp)
