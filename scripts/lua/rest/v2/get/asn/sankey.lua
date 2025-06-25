--
-- (C) 2013-25 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"
require "label_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local format_utils = require "format_utils"
local info = ntop.getInfo()
local callback_utils = require "callback_utils"

local rc = rest_utils.consts.success.ok
local ifid = _GET["ifid"]
local criteria_as = _GET["criteria_as"]
local asn = tonumber(_GET["asn"])
local rsp = {}

local edges = {}
local nodes = {}

local unit
if criteria_as == "egress_traffic_criteria" then
   unit = "Egress"
else
   unit = "Ingress"
end

-- ################################################

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

-- ################################################

local node_ids = {}
local last_node_id = 0
local debug = false

function find_node_id(node)
   local rc = node_ids[node]

   if (rc == nil) then
      rc = last_node_id .. ""
      last_node_id = last_node_id + 1
      node_ids[node] = rc

      if (debug) then
	 tprint("Adding " .. node .. " as " .. rc)
      end

      return (rc)
   else
      return (rc)
   end
end

-- ################################################

local rsp = {}
local nodes = {}
local links = {}
local node_set = {}
local as_root_key = "root";

table.insert(nodes, {
		link = "/",
		node_id = as_root_key,
		label = "ASN "..asn
})

-- ####################

local function add_unique_node(node_id, label, link)
   if not node_set[node_id] then
      table.insert(nodes, { node_id = node_id, label = label, link = link })
      node_set[node_id] = true
   end
end

-- ####################

local tot_bytes = {}

function callback (_, flow)
   -- tprint(flow) io.write("-------------------------------\n")

   local exporter_ip = getProbeName(flow.device_ip) or "unknown"
   local bytes
   local exporter_node_id = find_node_id(exporter_ip)

   -- TODO: handle all directions
   
   if unit == "Ingress" and flow.dst_as == asn then	    
      local port_index = format_portidx_name(flow.device_ip, flow.in_index) or "?"
      local n_id = exporter_ip .. "@" .. port_index
      local port_node_id = find_node_id(n_id)

      bytes = tonumber(flow.bytes_sent) -- TODO haandle directions
      add_unique_node(exporter_node_id, exporter_ip, "#")
      add_unique_node(port_node_id, port_index, "#")

      if(tot_bytes[n_id] == nil) then tot_bytes[n_id] = { sent = 0, rcvd = 0 } end
      -- TODO sum bytes
       
      table.insert(links, {
		      source_node_id = port_node_id,
		      target_node_id = exporter_node_id,
		      value = bytes -- TODO set bytes total 
      })

      table.insert(links, {
		      source_node_id = exporter_node_id,
		      target_node_id = as_root_key,
		      value = bytes -- TODO set bytes total
      })
   end
   
   if unit == "Egress" and flow.src_as == asn then
      local port_index = format_portidx_name(flow.device_ip, flow.out_index) or "?"
      local n_id = exporter_ip .. "@" .. port_index
      local port_node_id = find_node_id(n_id)

      bytes = tonumber(flow.bytes_rcvd) or 0
      
      add_unique_node(exporter_node_id, exporter_ip, "#")
      add_unique_node(port_node_id, port_index, "#")
      table.insert(links, {
		      source_node_id = as_root_key,
		      target_node_id = exporter_node_id,
		      value = bytes
      })
      table.insert(links, {
		      source_node_id = exporter_node_id,port_node_id,
		      target_node_id = port_node_id,
		      value = bytes
      })
   end
end

local flows_filter = { asnFilter = asn, detailsLevel = "normal", maxHits = 10000, perPage = 10000 }
callback_utils.foreachFlow(ifid,
			   os.time()+30, -- deadline
			   callback, flows_filter)


rsp["nodes"] = nodes
rsp["links"] = links

rest_utils.answer(rest_utils.consts.success.ok, rsp)
