--
-- (C) 2013-25 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local TABLE_NAME = "hourly_asn"
local flow_data_historical = {}

-- ###################################################

-- Helper used just to correctly format the where clause using OR or AND
local function buildWhereClause(current_where, new_filter, use_or)
    if not current_where then
        return new_filter
    else
        local operator = use_or and "OR" or "AND"
        return string.format("%s %s %s", current_where, operator, new_filter)
    end
end

-- ###################################################

-- @brief Helper used just to format a single filter
-- @param filter List, all info about the filter to be created
-- @param use_or Boolean, true if OR is needed to be used false otherwise (AND)
-- @param position Number, important to understand if OR or AND cond are to be used
-- @param where String, update the where when done
-- @param group_by String, update the group_by when done
-- @param select_query String, update the select_query when done
-- @return where, group_by, select_query
local function processFilter(filter, use_or, position, where, group_by,
                             select_query)
    local skip_select = false
    local column_name
    local new_filter

    -- Choose the right filter type
    if type(filter) == "number" or type(filter) == "string" then
        skip_select = true
        new_filter =
            string.format("%s=%s", tostring(position), tostring(filter))
    else
        column_name = filter.id or filter.key or filter.column_id
        new_filter = string.format("%s=%s", column_name,
                                   tostring(filter.filter_value))
    end

    -- Update the where
    where = buildWhereClause(where, new_filter, use_or)

    -- Skip if requested
    if skip_select then return where, group_by, select_query end

    -- Format the select + group by if needed
    local column_key = filter.key or filter.column_id
    if not isEmptyString(filter.db_formatting_fun) then
        column_key = string.format("%s(%s)", filter.db_formatting_fun,
                                   column_key)
    end

    select_query = string.format("%s, %s AS %s", select_query, column_key,
                                 column_name)

    if filter.is_key then
        group_by = string.format("%s, %s", group_by, column_name)
    end

    return where, group_by, select_query
end

-- ###################################################

-- @brief Given a list of columns and a flow, create a unique key using the columns
-- @param select_columns List, as key an id and as value a boolean, telling if the element
--                      has to be used as an id or not (e.g. bytes_sent are NOT ids)
-- @param where_filters List, containing all the filters
-- @param sort_columns List, containing all the columns to sort by
-- @param invert_direction Boolean, true if traffic directions needs to be inverted
-- @param first_seen Number, begin epoch used for the query
-- @param last_seen Number, end epoch used for the query
-- @return a list of data retrieved from the DB
function flow_data_historical.retrieveFlowData(select_columns, where_filters,
                                               sort_columns, invert_direction,
                                               first_seen, last_seen,
                                               isHistorical)
    local select_query = nil
    local group_by = nil
    local order_by = nil
    local where = nil
    local results = {}

    -- Iterate all the columns and format the select and group by
    for position, column_info in pairs(select_columns or {}) do
        local column_name = column_info.id or column_info.column_id
        local column_key = column_info.key
        if invert_direction and not isEmptyString(column_info.invert_with) then
            column_name = column_info.invert_with
        end
        -- In case of CH, some columns needs a special formatting function
        -- (e.g. IPs with IPv4NumToString)
        if not isEmptyString(column_info.db_formatting_fun) and isHistorical then
            column_key = string.format("%s(%s)", column_info.db_formatting_fun,
                                       column_info.key)
        end
        -- Format the select
        local select_part = string.format("%s AS %s", column_key, column_name)
        select_query = select_query and (select_query .. ", " .. select_part) or
                           select_part

        -- Add also to the group by
        if column_info.is_key then
            group_by = group_by and (group_by .. ", " .. column_name) or
                           column_name
        end
    end

    -- Iterate the filters, same format as the columns
    for pos, column_info in pairs(where_filters) do
        if type(column_info) == "table" and column_info[1] then
            -- Array of OR conditions
            for i, sub_filter in ipairs(column_info) do
                where, group_by, select_query =
                    processFilter(sub_filter, i > 1, i, where, group_by,
                                  select_query)
            end
        else
            where, group_by, select_query =
                processFilter(column_info, false, pos, where, group_by,
                              select_query)
        end
    end

    for pos, column_info in pairs(sort_columns or {}) do
        local order_col = string.format("%s DESC", column_info.id)
        order_by = order_by and (order_by .. ", " .. order_col) or order_col
    end

    -- Add first and last_seen to the where
    if not where then where = "" end
    order_by = order_by and ("ORDER BY " .. order_by) or ""
    -- In case of live table, no first_seen or last_seen used
    if (isHistorical) then
        where = string.format(
                    "%s AND (FIRST_SEEN >= %u AND FIRST_SEEN <= %u AND LAST_SEEN <= %u)",
                    where, tonumber(first_seen), tonumber(last_seen),
                    tonumber(last_seen))
    end

    if not select_query or not group_by then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "Empty list of columns\n")
        return results
    end

    -- TODO: have a generic parameter for the different tables available
    local query = string.format(
                      "SELECT %s FROM %s WHERE %s GROUP BY %s %s LIMIT 2000", -- Upper floor
                      select_query, TABLE_NAME, where, group_by, order_by)

    --tprint(query)
    if isHistorical and hasClickHouseSupport() then
        results = interface.execSQLQuery(query) or {}
    else
        results = interface.execInMemoryQuery(query) or {}
    end
    --tprint(results)

    return results
end

-- ###################################################

return flow_data_historical
