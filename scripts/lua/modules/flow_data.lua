--
-- (C) 2013-25 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if ntop.isPro() then
    package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" ..
                       package.path
end

local flow_data = {}
local callback_utils = require "callback_utils"
local flow_data_preset = require "flow_data_preset"
local trace_stats = false
local separator = " | "

-- ###################################################

-- @brief Given a list of columns and a flow, create a unique key to pair the values, 
--        using the columns, basically simulating a group by
-- @param columns List, as key an id and as value a boolean, telling if the element
--                      has to be used as an id or not (e.g. bytes_sent are NOT ids)
-- @return a unique key composed by the elements requested
local function formatKey(data, columns, rename_field_list)
    local all_key = ""
    local trace_string = "Checking new flow" -- string only used for tracing data
    -- Iterate all the requested info
    for position, column_info in pairs(columns) do
        local aggregation_key = column_info.id
        -- Check if an other name is requested to be used
        if rename_field_list and rename_field_list[position] then
            aggregation_key = rename_field_list[position]
        end
        local value = data[aggregation_key]
        -- Find the info inside the flow
        if type(data[aggregation_key]) == "string" then
            all_key = string.format("%s%s%s", all_key, separator, value)
            trace_string = string.format("%s [%s: %s]", trace_string,
                                         aggregation_key, value)
        end
    end
    if trace_stats then traceError(TRACE_NORMAL, TRACE_CONSOLE, trace_string) end

    return all_key
end

-- ###################################################

-- @brief Given a list of columns and a flow, create a unique key using the columns
-- @param columns List, as key an id and as value a boolean, telling if the element
--                      has to be used as an id or not (e.g. bytes_sent are NOT ids)
-- @param flow List, containing all the elements 
-- @param rename_field_list Array, containing a list of elements to be renamed; 
--                          NOTE: if the column[1] needs to be renamed, an element with a new
--                          name needs to be in rename_field_list[1] (SAME EXACT POSITION)
-- @param check_different_list Array, containing a list of elements, the element inside column
--                             in position i, needs to be different from element inside check_different_list
--                             in position i, see line 74; 
-- @return an array with a list of elements at 0 with are not ids, correctly compiled otherwise
local function formatEmptyStats(columns, flow, rename_field_list,
                                check_different_list)
    local element = {}
    local trace_string = "Creating entry for new key"
    -- Iterate all columns and create an entry for each KEY column (see scripts/lua/modules/flow_data_preset.lua)
    for position, column_info in pairs(columns) do
        local key = column_info.id
        -- Check if an other name is requested to be used
        if rename_field_list and rename_field_list[position] then
            key = rename_field_list[position]
        end

        -- Check if the requested element is a key and if it's present
        if (column_info.is_key) then
            -- Skip if it's not in the flow
            if (flow[column_info.key]) then
                local flow_element = tostring(flow[column_info.key])
                element[key] = flow_element
                -- Check if there is an other field to be checked
                if (check_different_list) and (check_different_list[position]) then
                    local other_flow_element = tostring(flow[check_different_list[position]["key"]])
                    if flow_element == other_flow_element then
                        element[key] = nil
                    end
                end
                if trace_stats then
                    trace_string = string.format("%s [%s: %s]", trace_string,
                                                 key,
                                                 tostring(element[key] or ""))
                end
            end
        else
            -- Not a key, so a value, set it to 0
            element[key] = 0
        end
    end

    if trace_stats then traceError(TRACE_NORMAL, TRACE_CONSOLE, trace_string) end

    return element
end

-- ###################################################

-- @brief Given a list of columns and a flow, create a unique key using the columns
-- @param columns List, as key an id and as value a boolean, telling if the element
--                      has to be used as an id or not (e.g. bytes_sent are NOT ids)
-- @param invert_direction Boolean, true if traffic directions needs to be inverted 
-- @param flow List, containing all the elements 
-- @param current_element List, containing the statistics previously collected, needs to be updated
-- @return an updated list of stats, contained in current_element
local function updateStats(columns, invert_direction, flow, current_element)
    -- Iterate the requested fields
    for _, column_info in pairs(columns) do
        if (not column_info.is_key) then -- Not a key, so a value to be updated (e.g. bytes)
            local flow_key_stat = column_info.key
            local id = column_info.id
            if invert_direction then id = column_info.invert_with end
            current_element[id] = current_element[id] +
                                      tonumber(flow[flow_key_stat] or 0)

            if trace_stats then
                traceError(TRACE_NORMAL, TRACE_CONSOLE,
                           string.format(
                               "Increasing stats [Column Id: %s]->[%s: %u] [Tot: %u]",
                               id, flow_key_stat, tonumber(flow[flow_key_stat]),
                               current_element[id]))
            end
        end
    end

    return current_element
end

-- ###################################################

function flow_data.getStats(queries)
    local results = {}

    for _, query_info in pairs(queries or {}) do
        local isHistorical = false
        if (query_info.filters and query_info.filters.last_seen) then
            isHistorical = true
        end
        local columns = flow_data_preset.retrieveColumns(
                            query_info.select_query, isHistorical)
        local filters = flow_data_preset.convertFilters(query_info.where_query,
                                                        query_info.filters,
                                                        isHistorical)
        local different_columns = flow_data_preset.retrieveColumns(
                                      query_info.different_from, isHistorical)
        if isHistorical then -- Historical
            --[[
            if not ntop.isEnterpriseM() then return {} end
            flow_data_historical = require "flow_data_historical"
            results = flow_data_historical.retrieveFlowData(columns, filters)
        ]]
        else -- Live
            local function formatData(_, flow)
                local empty = formatEmptyStats(columns, flow,
                                               query_info.rename_key_field,
                                               different_columns)
                local key = formatKey(empty, columns,
                                      query_info.rename_key_field)
                if not results[key] then -- Entry still not created
                    results[key] = empty
                end

                results[key] = updateStats(columns, query_info.invert_direction,
                                           flow, results[key])
            end
            callback_utils.foreachFlow(filters.ifid, os.time() + 30, -- deadline
                                       formatData, filters)
        end
    end

    -- Now we have equal table for live and historical, so now format the data and run the checks
    return results
end

-- ###################################################

-- @brief Given a list of columns and a flow, create a unique key using the columns
-- @param columns Array of stats to format
-- @return an Array of formatted elements
function flow_data.formatStats(stats_to_format)
    local formatted_stats = {}

    -- For each element, see if there is a defined formatter in 
    -- scripts/lua/modules/flow_data_preset.lua:format_functions
    -- if there is, split the value in { id = id, name = formattedName }
    -- otherwise keep that as it is
    for _, values in pairs(stats_to_format) do
        local formatted_element = {}
        for key, value in pairs(values or {}) do
            -- Format the data
            local formatted_data = flow_data_preset.getFormattedData(key, value,
                                                                     values)
            if (formatted_data ~= value) or (type(formatted_data) == "string") then
                formatted_element[key] = {id = value, name = formatted_data}
            else
                formatted_element[key] = value
            end
        end
        if values.bytes_sent and values.bytes_rcvd then
            formatted_element.total_bytes = values.bytes_sent +
                                                values.bytes_rcvd
        end
        formatted_stats[#formatted_stats + 1] = formatted_element
    end

    return formatted_stats
end

-- ###################################################

return flow_data
