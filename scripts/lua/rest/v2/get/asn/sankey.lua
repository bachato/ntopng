--
-- (C) 2013-25 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "check_redis_prefs"
require "flow_utils"
local rest_utils = require "rest_utils"
local flow_sankey = require "flow_sankey"
local format_utils = require "format_utils"

-- Retrieve the info from the rest
local asn = tonumber(_GET["asn"] or 0)
local ifid = _GET["ifid"] or interface.getId()
local criteria_as = _GET["criteria_as"]
local data_type = _GET["type"] or ""
local epoch_begin = nil
local epoch_end = nil
local res = {}
local filters = {}
local queries = {}

-- Empty ASN return an error
if isEmptyString(asn) or (asn == 0) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

-- In case historical data has been requested, add the epoch_begin and epoch_end
if data_type == "historical" and hasClickHouseSupport() then
   -- Handle the epoch only with the historical
   epoch_begin = tonumber(_GET["epoch_begin"])
   epoch_end = tonumber(_GET["epoch_end"])
end

if criteria_as == "ingress_egress_traffic_criteria" then
   filters = {
      asn = asn,
      ifid = ifid,
      first_seen = epoch_begin,
      last_seen = epoch_end
   }
   queries = {
      {
	 select_query = {
	    "in_iface_index", "in_device", "bytes_sent", "bytes_rcvd",
	    "total_bytes"
	 },
	 where_query = {"asn"},
	 sort_by = {"total_bytes"},
	 filters = filters,
	 root = {
	    formatter = format_utils.formatASN,
	    id = asn,
	    add_root_first = false
	 }
      }, {
	 select_query = {
	    "out_device", "out_iface_index", "bytes_sent", "bytes_rcvd",
	    "total_bytes"
	 },
	 where_query = {"asn"},
	 sort_by = {"total_bytes"},
	 filters = filters,
	 root = {
	    formatter = format_utils.formatASN,
	    id = asn,
	    add_root_first = true
	 }
	 }
   }
elseif isEmptyString(criteria) or (criteria == "traffic_between_ases") then
   queries = {
      {
	 select_query = {
	    "src_asn", "src_peer_asn", "dst_peer_asn", "bytes_sent",
	    "bytes_rcvd", "total_bytes"
	 },
	 different_from = {nil, "src_asn", "dst_asn"},
	 rename_key_field = {nil, "src_peer_asn_1", "dst_peer_asn_1"},
	 skip_flow = {{key = "src_asn", value = "0"}},
	 where_query = {"dst_asn"},
	 sort_by = {"total_bytes"},
	 filters = {
	    dst_asn = asn,
	    ifid = ifid,
	    first_seen = epoch_begin,
	    last_seen = epoch_end
	 },
	 root = {
	    formatter = format_utils.formatASN,
	    id = asn,
	    add_root_first = false
	 }
      }, {
	 select_query = {
	    "src_peer_asn", "dst_peer_asn", "dst_asn", "bytes_sent",
	    "bytes_rcvd", "total_bytes"
	 },
	 where_query = {"src_asn"},
	 sort_by = {"total_bytes"},
	 different_from = {"src_asn", "dst_asn"},
	 rename_key_field = {"src_peer_asn_2", "dst_peer_asn_2"},
	 skip_flow = {{key = "dst_asn", value = 0}},
	 filters = {
	    src_asn = asn,
	    ifid = ifid,
	    first_seen = epoch_begin,
	    last_seen = epoch_end
	 },
	 root = {
	    formatter = format_utils.formatASN,
	    id = asn,
	    add_root_first = true
	 }
	 }
   }
end

local nodes = {}
local links = {}
local MAX_NODES_PER_LEVEL = 10
nodes, links = flow_sankey.generateSankey(queries, MAX_NODES_PER_LEVEL, not isEmptyString(epoch_begin))

res["nodes"] = nodes
res["links"] = links

rest_utils.answer(rest_utils.consts.success.ok, res)
