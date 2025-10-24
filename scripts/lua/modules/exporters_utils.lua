--
-- (C) 2019-25 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils_gui"
require "lua_utils_get"
local snmp_utils = nil
if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" ..
      package.path
   snmp_utils = require "snmp_utils"
end

local exporters_utils = {}

-- ################################################

local function formatInterfaceData(exporter_ip, new_ports_list, res, uuid_list,
                                   add_role_to_interfaces)
   for _, v in pairs(new_ports_list or {}) do
      for id, info in pairsByField(v, "bytes.total", rev) do
	 local role = nil
	 local interface_name = format_portidx_name(exporter_ip,
						    tostring(id), true)
	 local exporter_name = getProbeName(exporter_ip, true, true, false)
	 if (add_role_to_interfaces) then
	    role = snmp_utils.get_snmp_interface_role(exporter_ip, id)
	 end
	 res[#res + 1] = {
	    interface_id = id,
	    interface_name = interface_name,
	    exporter_ip = exporter_ip,
	    exporter_name = exporter_name,
	    exporter_uuid = uuid_list.exporter_uuid,
	    probe_uuid = uuid_list.probe_uuid,
	    ifid = uuid_list.ifid, -- Ifid of the exporter
	    bytes_sent = info["bytes.out_bytes"],
	    bytes_rcvd = info["bytes.in_bytes"],
	    total_bytes = info["bytes.total"],
	    role = role
	 }
      end
   end

end

-- ################################################

-- @brief: this function returns the list of all the Exporters Interfaces
function exporters_utils.getAllInterfacesList(add_role_to_interfaces)
   local list = {}

   local ifstats = interface.getStats()
   -- Get the list of all the probes
   for ifid, probe_list in pairs(ifstats.probes or {}) do
      for _, probe_info in pairsByKeys(probe_list or {}) do
	 local uuid = probe_info["probe.uuid_num"]
	 local probe_ip = probe_info["probe.ip"]

	 -- For each probe retrieve the list of interfaces
	 if (uuid) then
	    if (table.len(probe_info.exporters) == 0) then
	       -- Packet probe
	       local ports_table = interface.getFlowDeviceInfo(uuid, true)
	       local exporter_ip = probe_info["remote.if_addr"]
	       formatInterfaceData(exporter_ip, ports_table, list,
				   {
				      probe_uuid = uuid,
				      exporter_uuid = uuid,
				      ifid = ifid
				   }, add_role_to_interfaces)
	    else
	       -- Collector probe
	       local collector_value = 0

	       for exporter_ip, exporter_info in pairsByKeys(
		  probe_info.exporters or
		  {}) do
		  local ports_table =
		     interface.getFlowDeviceInfo(
			exporter_info.unique_source_id, true)

		  formatInterfaceData(exporter_ip, ports_table, list, {
					 probe_uuid = uuid,
					 exporter_uuid = unique_source_id,
					 ifid = ifid
								      }, add_role_to_interfaces)
	       end
	    end
	 end

      end
   end

   return list
end

-- ################################################

local _exporter_uuid = {}

function exporters_utils.getExporterUUID(exporter_ip)
   local ret = _exporter_uuid[exporter_ip]

   if(ret ~= nil) then
      return ret
   end

   if not isEmptyString(exporter_ip) then
      local flow_exporters = interface.getFlowDevices()
      for ifid, info in pairs(flow_exporters or {}) do
	 for exporter_uuid, exporter_info in pairs(info or {}) do
	    if exporter_info.exporter_ip == exporter_ip then
	       _exporter_uuid[exporter_ip] = { exporter_uuid, ifid }
	       return exporter_uuid, ifid
	    end
	 end
      end
   end

   return nil, nil
end

-- ################################################

local _probe_uuid = {}

function exporters_utils.getProbeUUID(exporter_ip)
   local ret = _probe_uuid[exporter_ip]

   if(ret ~= nil) then
      return ret
   end

   if not isEmptyString(exporter_ip) then
      local exporter_uuid = nil
      local flow_exporters = interface.getFlowDevices()
      for ifid, info in pairs(flow_exporters or {}) do
	 for uuid, exporter_info in pairs(info or {}) do
	    if exporter_info.exporter_ip == exporter_ip then
	       exporter_uuid = uuid
	       goto uuid_found
	    end
	 end
      end
      ::uuid_found::
      if (exporter_uuid) then
	 local ifstats = interface.getStats()
	 -- Get the list of all the probes
	 for ifid, probe_list in pairs(ifstats.probes or {}) do
	    for probe_uuid, probe_info in pairsByKeys(probe_list or {}) do
	       if tostring(probe_uuid) == tostring(exporter_uuid) then
		  -- Packet interface
		  _probe_uuid[exporter_ip] = { probe_uuid, ifid }
		  return probe_uuid, ifid
	       end
	       for _, exporter_info in pairs(probe_info.exporters or {}) do
		  if tostring(exporter_info.unique_source_id) == tostring(exporter_uuid) then
		     -- Netflow Interface
		     _probe_uuid[exporter_ip] =  { probe_uuid, ifid }
		     return probe_uuid, ifid
		  end
	       end
	    end
	 end
      end
   end

   return nil, nil
end

-- ################################################

return exporters_utils
