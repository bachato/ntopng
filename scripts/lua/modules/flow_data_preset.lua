--
-- (C) 2013-25 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils_get"
require "lua_utils_gui"
local format_utils = require "format_utils"
local flow_data_preset = {}
-- This table contains the mapping to the live and historical flows,
-- if the column has to be used as key (except bytes/packets everything should be a key)
-- and the formatter
local columns = {
    asn = {filters = {live = "asnFilter", historical = " ASN"}},
    src_asn = {
        live = "src_as",
        historical = "SRC_ASN",
        is_key = true,
        filters = {live = "asnSrcFilter", historical = "SRC_ASN"},
        formatter = {funct = format_utils.formatASN}
    },
    dst_asn = {
        live = "dst_as",
        historical = "DST_ASN",
        is_key = true,
        filters = {live = "asnDstFilter", historical = "DST_ASN"},
        formatter = {funct = format_utils.formatASN}
    },
    src_peer_asn = {
        live = "src_peer_as",
        historical = "SRC_PEER_ASN",
        is_key = true,
        formatter = {funct = format_utils.formatASN}
    },
    dst_peer_asn = {
        live = "dst_peer_as",
        historical = "DST_PEER_ASN",
        is_key = true,
        formatter = {funct = format_utils.formatASN}
    },
    in_device = {
        live = "device_ip",
        historical = "PROBE_IP",
        is_key = true,
        filters = {live = "deviceIpFilter", historical = "PROBE_IP"},
        formatter = {funct = getProbeName}
    },
    out_device = {
        live = "device_ip",
        historical = "PROBE_IP",
        is_key = true,
        filters = {live = "deviceIpFilter", historical = "PROBE_IP"},
        formatter = {funct = getProbeName}
    },
    device = {
        live = "device_ip",
        historical = "PROBE_IP",
        is_key = true,
        filters = {live = "deviceIpFilter", historical = "PROBE_IP"},
        formatter = {funct = getProbeName}
    },
    in_iface_index = {
        live = "in_index",
        historical = "INPUT_SNMP",
        is_key = true,
        formatter = {funct = format_portidx_name, column_dependent = "device"}
    },
    out_iface_index = {
        live = "out_index",
        historical = "OUTPUT_SNMP",
        is_key = true,
        formatter = {funct = format_portidx_name, column_dependent = "device"}
    },
    interface = {
        formatter = {funct = format_portidx_name, column_dependent = "device"}
    },
    bytes_sent = {live = "bytes_sent", historical = "SUM(SRC2DST_BYTES)", invert_with = "bytes_rcvd"},
    bytes_rcvd = {live = "bytes_rcvd", historical = "SUM(DST2SRC_BYTES)", invert_with = "bytes_sent"},
    as = {formatter = {funct = format_utils.formatASN}},
    transit_as = {formatter = {funct = format_utils.formatASN}},
    src_transit_as = {formatter = {funct = format_utils.formatASN}},
    dst_transit_as = {formatter = {funct = format_utils.formatASN}}
}

-- ###########################################

-- @brief Given a list of ids in an array format, returns the 
-- name of the data in case of live flows or historical
-- @param columns_id Array, containing a list of columns ids
-- @param is_historical Boolean, true if historical ids are needed, false for live ones 
-- @return a list of matching ids for the requested type (live or historical)
function flow_data_preset.retrieveColumns(columns_id, is_historical)
    local id_list = {}
    local data_type = "live"

    if is_historical then data_type = "historical" end

    for position, id in pairs(columns_id or {}) do
        if columns[id] then
            local column_info = columns[id]
            column_info["key"] = column_info[data_type]
            column_info["id"] = id
            id_list[position] = column_info
        end
    end

    return id_list
end

-- ###########################################

-- @brief Given a list of filters, returns a list of particular conditions for each filter if available
-- @param where Array, containing a list of ids for the where
-- @param available_filters List, containing a list filters, key is the key of the filter, value is the value
-- @param is_historical Boolean, true if historical ids are needed, false for live ones 
-- @return a list of filters, key - value
function flow_data_preset.convertFilters(where, available_filters, is_historical)
    local where_query = {}
    local data_type = "live"
    if (not available_filters) or (table.len(available_filters) == 0) then
        return where_query
    end

    if is_historical then data_type = "historical" end

    for _, key in pairs(where or {}) do
        if (columns[key] and columns[key]["filters"] and
            columns[key]["filters"][data_type]) then
            local filter = columns[key]["filters"][data_type]
            where_query[filter] = available_filters[key]
        end
    end

    -- Ifid filter is mandatory, add it in case it's missing
    if not where_query["ifid"] then
        where_query["ifid"] = interface.getId() -- Use current ifid
    end

    if data_type == "live" then where_query["detailsLevel"] = "normal" end

    return where_query
end

-- ###########################################

-- @brief Return the requested formatted data if a 
--        formatting function is available
-- @param key String, key of the formatter to retrieve
-- @param value String, data to format 
-- @param all_values List, element containing all the data, 
--               in case some data needs other data, e.g. SNMP Interface
-- @return the formatted data
function flow_data_preset.getFormattedData(key, value, all_values)
    local formatted_value = value
    -- If key is empty or no formatter available return the value
    if isEmptyString(key) or isEmptyString(formatted_value) then
        return formatted_value
    end

    if (not columns[key]) or (not columns[key]["formatter"]) or
        (not columns[key]["formatter"]["funct"]) then return formatted_value end

    -- Get the formatter function
    local formatter = columns[key]["formatter"]["funct"]

    -- See if there is some column from which is dependent, 
    -- e.g. SNMP Interface needs the SNMP IP
    if columns[key]["formatter"]["column_dependent"] then
        -- TODO: Now it's limited to a single column, add multiple columns
        local element =
            all_values[columns[key]["formatter"]["column_dependent"]]
        if (not element) then -- Not found return value
            return formatted_value
        end
        return formatter(element, formatted_value)
    else
        return formatter(formatted_value)
    end

    return formatted_value
end

-- ###########################################

return flow_data_preset
