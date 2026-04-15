--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
require "lua_utils_gui"
local json = require "dkjson"
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

local function formatBgpBmpInfo(bgp_info)
    local rsp = {}
    for prefix, peers in pairs(bgp_info or {}) do
        local peer_list = {}
        local peer_id = {}
        local asn_list = {}
        local bgp_origin = {}
        local bgp_next_hop = {}
        local as_path = {}
        local communities = {}
        local med_list = {}
        local local_pref_list = {}
        for bgp_id, info in pairs(peers) do
            peer_list[#peer_list + 1] = {
                id = bgp_id,
                info = info
            }
        end
        local max_len = (#peer_list > 2) and 8 or 32
        for _, peer in ipairs(peer_list) do
            peer_id[#peer_id + 1] = {
                name = string.format("%s%s", peer_id, formatNextHop(peer.id))
            }
            asn_list[#asn_list + 1] = {
                name = string.format("%s (%s)", peer.info.asn, ntop.getASNameFromASN(tonumber(peer.info.asn))),
                url = string.format("%s/lua/hosts_stats.lua?asn=%s", ntop.getHttpPrefix(), peer.info.asn)
            }
            bgp_origin[#bgp_origin + 1] = {
                name = string.upper(peer.info["origin"] or "")
            }
            bgp_next_hop[#bgp_next_hop + 1] = {
                name = peer.info["next_hop"] or ""
            }
            med_list[#med_list + 1] = {
                name = ((peer.info["med"] ~= nil) and tostring(peer.info["med"]) or "")
            }
            local_pref_list[#local_pref_list + 1] = {
                name = ((peer.info["local_pref"] ~= nil) and tostring(peer.info["local_pref"]) or "")
            }

            -- Formatting AS Path list
            if peer.info["as_path"] and #peer.info["as_path"] > 0 then
                local parts = {}
                for _, asn in ipairs(peer.info["as_path"]) do
                    as_path[#as_path + 1] = {
                        name = ntop.getASNameFromASN(tonumber(asn)),
                        url = string.format("%s/lua/hosts_stats.lua?asn=%s", ntop.getHttpPrefix(), asn)
                    }
                end
            end

            -- Formatting Communities list
            if peer.info["communities"] and #peer.info["communities"] > 0 then
                for _, c in ipairs(peer.info["communities"]) do
                communities[#communities + 1] = {
                    name = c
                }
                end
            end
        end
        rsp[#rsp + 1] = {
            name = "bgp_prefix",
            value = prefix
        }
        rsp[#rsp + 1] = {
            name = "bgp_peer_id",
            value = peer_id
        }
        rsp[#rsp + 1] = {
            name = "bgp_peer_asn",
            value = asn_list
        }
        rsp[#rsp + 1] = {
            name = "bgp_origin",
            value = bgp_origin
        }
        rsp[#rsp + 1] = {
            name = "bgp_next_hop",
            value = bgp_next_hop
        }
        rsp[#rsp + 1] = {
            name = "bgp_as_path",
            value = as_path
        }
        if not ((#bgp_info == 1) and (#peer_list > 0)) then
            rsp[#rsp + 1] = {
                name = "bgp_med",
                value = med_list
            }
            rsp[#rsp + 1] = {
                name = "bgp_local_pref",
                value = local_pref_list
            }
            rsp[#rsp + 1] = {
                name = "bgp_communities",
                value = communities
            }
        end
    end
    return rsp
end

if (flow) and (flow.bgp) then
    local client_info = {}
    local server_info = {}
    if (flow.bgp.src) then
        local bgp_info = json.decode(flow.bgp.src)
        client_info = formatBgpBmpInfo(bgp_info)
    end
    if (flow.bgp.dst) then
        local bgp_info = json.decode(flow.bgp.dst)
        server_info = formatBgpBmpInfo(bgp_info)
    end
    rsp = {
        client_info = client_info,
        server_info = server_info
    }
end

rest_utils.answer(rest_utils.consts.success.ok, rsp)
