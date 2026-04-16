--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
require "lua_utils_gui"
local json = require "dkjson"
local bgp_utils = require "bgp_utils"
local rest_utils = require "rest_utils"

-- ################################################

local rsp = {}
local ifid = _GET["ifid"]
local flow_key = _GET["flow_key"]
local flow_hash_id = _GET["flow_hash_id"]

local row_id = _GET["row_id"]
local instance_name = _GET["instance_name"] or ""
local tstamp = _GET["tstamp"]

if not isEmptyString(ifid) then
    interface.select(ifid)
end

-- ################################################

local flow = nil

if flow_hash_id and flow_key then
    -- Live
    flow = interface.findFlowByKeyAndHashId(tonumber(flow_key), tonumber(flow_hash_id))
elseif row_id and instance_name and tstamp and ntop.isEnterpriseL() --[[ Required otherwise it crashes ]] then
    local db_search_manager = require "db_search_manager"
    local historical_flow_utils = require "historical_flow_utils"

    flow = db_search_manager.get_flow(row_id, tstamp, instance_name)
    flow = historical_flow_utils.convertToLiveFlowFormat(flow)
end

-- ################################################

if (flow) and (flow.bgp) then
    local client_info = {}
    local server_info = {}
    if (flow.bgp.src) then
        local bgp_info = json.decode(flow.bgp.src)
        client_info = bgp_utils.formatBgpBmpInfo(bgp_info)
    end
    if (flow.bgp.dst) then
        local bgp_info = json.decode(flow.bgp.dst)
        server_info = bgp_utils.formatBgpBmpInfo(bgp_info)
    end
    rsp = {
        client_info = client_info,
        server_info = server_info
    }
end

-- ################################################

rest_utils.answer(rest_utils.consts.success.ok, rsp)
