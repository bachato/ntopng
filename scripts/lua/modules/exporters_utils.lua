--
-- (C) 2019-25 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils_gui"
local snmp_utils = nil
if ntop.isPro() then
    package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" ..
                       package.path
    snmp_utils = require "snmp_utils"
end

local exporters_utils = {}

-- ################################################

-- @brief: this function returns the list of all the Exporters Interfaces
function exporters_utils.getAllInterfacesList(add_role_to_interfaces)
    local list = {}

    local ifstats = interface.getStats()
    -- Get the list of all the probes
    for _, probe_list in pairs(ifstats.probes or {}) do
        for probe_ip, probe_info in pairsByKeys(probe_list or {}) do
            local uuid = probe_info["probe.uuid_num"]

            -- For each probe retrieve the list of interfaces
            if (uuid) then
                if (table.len(probe_info.exporters) == 0) then
                    -- Packet probe
                    local ports_table = interface.getFlowDeviceInfo(uuid, true)

                    for _, v in pairs(ports_table or {}) do
                        for id, info in pairsByField(v, "bytes.total", rev) do
                            local role = nil
                            if (add_role_to_interfaces) then
                                role = snmp_utils.get_snmp_interface_role(
                                           probe_ip, id)
                            end
                            list[#list + 1] = {
                                id = id,
                                name = format_portidx_name(
                                    probe_info["probe.ip"], tostring(id), true),
                                total_bytes = info["bytes.total"],
                                role = role
                            }
                        end
                    end
                else
                    -- Collector probe
                    local collector_value = 0

                    for exporter_ip, exporter_info in pairsByKeys(
                                                          probe_info.exporters or
                                                              {}) do
                        local node_key =
                            probe_info["probe.uuid"] ..
                                exporter_info["unique_source_id"]
                        local ports_table =
                            interface.getFlowDeviceInfo(
                                exporter_info.unique_source_id, true)

                        for _, v in pairs(ports_table or {}) do
                            for id, info in pairsByField(v, "bytes.total", rev) do
                                local role = nil
                                if (add_role_to_interfaces) then
                                    role =
                                        snmp_utils.get_snmp_interface_role(
                                            exporter_ip, id)
                                end
                                list[#list + 1] = {
                                    id = id,
                                    name = format_portidx_name(
                                        exporter_ip, tostring(id),
                                        true),
                                    total_bytes = info["bytes.total"],
                                    role = role
                                }
                            end
                        end
                    end
                end
            end

        end
    end

    return list
end

-- ################################################

return exporters_utils
