--
-- (C) 2025 - ntop.org
--
-- ASN (Autonomous System Number) Utilities Module
-- Provides functions for managing and retrieving ASN configurations and traffic statistics
-- Supports categorization of ASNs into customer, sub-customer, and remote types

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "check_redis_prefs"

--- Maximum number of top ASNs to return in getTop functions
local MAXIMUM_NUMBER_OF_TOP = 10
local HISTORICAL_SRC_ASN = "SRC_ASN"
local HISTORICAL_DST_ASN = "DST_ASN"

--- ASN utilities module
local as_utils = {}

---
-- Parses a comma-separated string of ASN numbers into a lookup table
-- @param string The comma-separated string of ASN numbers (e.g., "1234,5678,9012")
-- @return table A table with ASN numbers as keys for O(1) lookup
local function parseASNList(string)
    local asn = {}
    local tmp = split(string, ",")
    for _, val in pairs(tmp or {}) do
        asn[val] = 1
    end
    return asn
end

---
-- Formats SQL conditions for ASN filtering in historical queries
-- Translates ASN type selections (my_as, my_customer_as, remote_as, other_as) into SQL WHERE clauses
-- 
-- @param options Table containing filtering options with selected_asn field
-- @return string SQL condition string (e.g., "asn=123 OR asn=456") or empty string if no conditions
local function formatHistoricalASNFilters(options, historical_field)
    local check_as = nil                    -- Table of ASNs to filter by
    local invert = false                     -- Filter direction flag:
                                             -- false = INCLUSIVE (asn IN (...))
                                             -- true  = EXCLUSIVE (asn NOT IN (...))
    
    -- Determine filter type based on user selection
    if options.selected_asn == "my_as" then
        -- Customer ASNs only
        check_as = as_utils.getCustomerASNs()
    elseif options.selected_asn == "my_customer_as" then
        -- Sub-customer ASNs only
        check_as = as_utils.getSubCustomerASNs()
    elseif options.selected_asn == "remote_as" then
        -- Remote ASNs only
        check_as = as_utils.getRemoteASNs()
    elseif options.selected_asn == "other_as" then
        -- All configured ASNs (customer + sub-customer + remote)
        check_as = as_utils.getAllASNs()
        invert = true  -- "other_as" means NOT in configured ASNs
                       -- e.g., exclude all known ASNs to show "other" traffic
    end

    -- Build SQL conditions for each ASN in the filter list
    local conditions = {}
    for asn, _ in pairs(check_as or {}) do
        conditions[#conditions + 1] = string.format("%s=%s", historical_field, tostring(asn))
    end

    -- Return concatenated conditions or empty string if no filters
    -- Note: The caller is responsible for combining this with other WHERE clauses
    local filter = (table.concat(conditions, " OR ") or "")
    if not isEmptyString(filter) and (invert == true) then
        filter = string.format("NOT (%s)", filter)
    end

    return filter
end

---
-- Retrieves the customer ASN list from cache
-- @return string Comma-separated list of customer ASNs
function as_utils.getCustomerASNList()
    return ntop.getCache("ntopng.prefs.config_customer_asn_list") or ""
end

---
-- Retrieves the sub-customer ASN list from cache
-- @return string Comma-separated list of sub-customer ASNs
function as_utils.getSubCustomerASNList()
    return ntop.getCache("ntopng.prefs.config_sub_customer_asn_list") or ""
end

---
-- Retrieves the remote ASN list from cache
-- @return string Comma-separated list of remote ASNs
function as_utils.getRemoteASNList()
    return ntop.getCache("ntopng.prefs.config_remote_asn_list") or ""
end

--- Cached customer ASN lookup table
local cached_customer_asn = nil

---
-- Gets customer ASNs as a lookup table (with caching)
-- @return table Table with customer ASN numbers as keys
function as_utils.getCustomerASNs()
    if not cached_customer_asn then
        cached_customer_asn = parseASNList(as_utils.getCustomerASNList())
    end
    return cached_customer_asn or {}
end

--- Cached sub-customer ASN lookup table
local cached_subcustomer_asn = nil

---
-- Gets sub-customer ASNs as a lookup table (with caching)
-- @return table Table with sub-customer ASN numbers as keys
function as_utils.getSubCustomerASNs()
    if not cached_subcustomer_asn then
        cached_subcustomer_asn = parseASNList(as_utils.getSubCustomerASNList())
    end
    return cached_subcustomer_asn or {}
end

--- Cached remote ASN lookup table
local cached_remote_asn = nil

---
-- Gets remote ASNs as a lookup table (with caching)
-- @return table Table with remote ASN numbers as keys
function as_utils.getRemoteASNs()
    if not cached_remote_asn then
        cached_remote_asn = parseASNList(as_utils.getRemoteASNList())
    end
    return cached_remote_asn or {}
end

---
-- Retrieves all ASN configurations (customer, sub-customer, remote)
-- @return table Customer ASN lookup table
-- @return table Sub-customer ASN lookup table
-- @return table Remote ASN lookup table
function as_utils.getAllConfigurations()
    local customer_asn = as_utils.getCustomerASNs()
    local sub_customer_asn = as_utils.getSubCustomerASNs()
    local remote_asn = as_utils.getRemoteASNs()
    return customer_asn, sub_customer_asn, remote_asn
end

--- Cached table containing all configured ASNs
local cached_all_asn = nil

---
-- Gets all configured ASNs (customer + sub-customer + remote)
-- @return table Table containing all configured ASN numbers as keys
function as_utils.getAllASNs()
    local all_asn = nil
    if not cached_all_asn then
        local customer_asn, sub_customer_asn, remote_asn = as_utils.getAllConfigurations()
        local res = {}
        -- Merge customer and sub-customer ASNs
        local costumer_sub = table.merge(customer_asn, sub_customer_asn)
        -- Merge with remote ASNs
        local all_asn = table.merge(costumer_sub, remote_asn)
        cached_all_asn = all_asn
    end

    return cached_all_asn or {}
end

---
-- Determines the configuration type of a specific ASN
-- @param asn The ASN number to check
-- @return string|nil The configuration type ("customer_asn", "sub_customer_asn", "remote_asn") or nil if not configured
function as_utils.getASNConfiguration(asn)
    local res = nil
    local customer_asn, sub_customer_asn, remote_asn = as_utils.getAllConfigurations()
    
    if customer_asn[asn] ~= nil then
        res = "customer_asn"
    elseif sub_customer_asn[asn] ~= nil then
        res = "sub_customer_asn"
    elseif remote_asn[asn] ~= nil then
        res = "remote_asn"
    end
    
    return res
end

---
-- Gets all customer and sub-customer ASNs merged into a single table
-- @return table Combined lookup table of customer and sub-customer ASNs
function as_utils.getCustomerAndSubCustomerASNs()
    local res = {}
    local sub_customer_asns = as_utils.getSubCustomerASNs()
    local my_asns = as_utils.getCustomerASNs()
    
    -- Merge both tables
    for k, v in pairs(sub_customer_asns) do
        res[k] = v
    end
    for k, v in pairs(my_asns) do
        res[k] = v
    end
    
    return res
end

---
-- Retrieves live ASN traffic statistics from the current interface
-- @param options Table containing filtering options (selected_asn)
-- @return table ASN statistics keyed by ASN number
function as_utils.retrieveASLiveTraffic(options)
    -- Get live ASN statistics from interface
    local live_asn_info = interface.getLiveASNStats() or {}
    local live_src_asn = live_asn_info["src_asn"]
    local live_dst_asn = live_asn_info["dst_asn"]
    local asn_stats = {}

    -- Process source ASN statistics
    for asn, bytes_stats in pairs(live_src_asn) do
        asn = tostring(asn)
        if not asn_stats[asn] then
            -- New ASN: get info and initialize
            local as_info = interface.getASInfo(tonumber(asn), true)
            if (as_info) then
                as_info["bytes.sent"] = bytes_stats.bytes_sent
                as_info["bytes.rcvd"] = bytes_stats.bytes_rcvd
                as_info["traffic"] = bytes_stats.total_bytes
                asn_stats[asn] = as_info
            end
        else
            -- Existing ASN: aggregate statistics
            asn_stats[asn]["bytes.sent"] = asn_stats[asn]["bytes.sent"] + bytes_stats.bytes_sent
            asn_stats[asn]["bytes.rcvd"] = asn_stats[asn]["bytes.rcvd"] + bytes_stats.bytes_rcvd
            asn_stats[asn]["traffic"] = asn_stats[asn]["bytes.total"] + bytes_stats.total_bytes
        end
    end

    -- Process destination ASN statistics
    for asn, bytes_stats in pairs(live_dst_asn) do
        asn = tostring(asn)
        if not asn_stats[asn] then
            -- New ASN: get info and initialize
            local as_info = interface.getASInfo(tonumber(asn))
            if (as_info) then
                as_info["bytes.sent"] = bytes_stats.bytes_sent
                as_info["bytes.rcvd"] = bytes_stats.bytes_rcvd
                as_info["traffic"] = bytes_stats.total_bytes
                asn_stats[asn] = as_info
            end
        else
            -- Existing ASN: aggregate statistics
            asn_stats[asn]["bytes.sent"] = asn_stats[asn]["bytes.sent"] + bytes_stats.bytes_sent
            asn_stats[asn]["bytes.rcvd"] = asn_stats[asn]["bytes.rcvd"] + bytes_stats.bytes_rcvd
            asn_stats[asn]["traffic"] = asn_stats[asn]["traffic"] + bytes_stats.total_bytes
        end
    end

    -- Apply ASN type filtering if specified
    if not isEmptyString(options.selected_asn) and (options.selected_asn ~= "all") then
        local check_as = nil
        local invert = false

        -- Determine filter type
        if options.selected_asn == "my_as" then
            check_as = as_utils.getCustomerASNs()
        elseif options.selected_asn == "my_customer_as" then
            check_as = as_utils.getSubCustomerASNs()
        elseif options.selected_asn == "remote_as" then
            check_as = as_utils.getRemoteASNs()
        elseif options.selected_asn == "other_as" then
            check_as = as_utils.getAllASNs()
            invert = true  -- "other_as" means NOT in configured ASNs
        end

        -- Filter ASNs based on selection
        for asn, as_info in pairs(asn_stats) do
            local present = check_as[asn] ~= nil
            if present == invert then
                asn_stats[asn] = nil
            end
        end
    end
    
    return asn_stats
end

---
-- Retrieves historical ASN traffic statistics from ClickHouse database
-- @param options Table containing filtering options (epoch_begin, epoch_end, ifid, selected_asn)
-- @return table Historical ASN statistics keyed by ASN number
function as_utils.retrieveASHistoricalTraffic(options)
    -- Check if ClickHouse support is available
    if not hasClickHouseSupport() then
        return {}
    end

    -- Built two different where for efficiency reasons, filtering inside the UNION
    -- is a lot faster the filtering outside even if the code readability is a bit less
    local src_asn_filters = formatHistoricalASNFilters(options, HISTORICAL_SRC_ASN)
    local dst_asn_filters = formatHistoricalASNFilters(options, HISTORICAL_DST_ASN)
    -- Build WHERE clause for time range and interface
    local where = string.format("(FIRST_SEEN >= %u AND FIRST_SEEN <= %u AND LAST_SEEN <= %u) AND INTERFACE_ID = %u",
        tonumber(options.epoch_begin), tonumber(options.epoch_end), tonumber(options.epoch_end), tonumber(options.ifid))
    
    -- Complex SQL query to aggregate ASN statistics from flows table
    -- Combines both source and destination ASNs
    local query = string.format(
        "SELECT asn, min(FIRST_SEEN) as \"seen.first\", max(LAST_SEEN) as \"seen.last\", sum(SCORE) as score, sum(total_bytes) AS traffic, sum(bytes_sent) as \"bytes.sent\", sum(bytes_rcvd) as \"bytes.rcvd\", sum(total_bytes) / sum(dateDiff('second', FIRST_SEEN, LAST_SEEN) + 1) AS throughput_bps " ..
            "FROM (SELECT SRC_ASN AS asn, FLOW_ID, TOTAL_BYTES as total_bytes, SRC2DST_BYTES as bytes_sent, DST2SRC_BYTES as bytes_rcvd, FIRST_SEEN, LAST_SEEN, INTERFACE_ID, SCORE FROM flows WHERE %s %s UNION ALL " ..
            "SELECT DST_ASN AS asn, FLOW_ID, TOTAL_BYTES as total_bytes, DST2SRC_BYTES as bytes_sent, SRC2DST_BYTES as bytes_rcvd, FIRST_SEEN, LAST_SEEN, INTERFACE_ID, SCORE FROM flows WHERE %s %s AND DST_ASN != SRC_ASN " ..
            ") GROUP BY asn", where, ternary(isEmptyString(src_asn_filters), "", " AND " .. src_asn_filters), where, ternary(isEmptyString(dst_asn_filters), "", " AND " .. dst_asn_filters))
    
    local historical_asn_stats = interface.execSQLQuery(query) or {}
    local asn_stats = {}
    
    -- Process historical data
    for _, as_info in pairs(historical_asn_stats) do
        local asn = as_info["asn"]
        as_info["bytes.sent"] = tonumber(as_info["bytes.sent"])
        as_info["bytes.rcvd"] = tonumber(as_info["bytes.rcvd"])
        as_info["traffic"] = tonumber(as_info["traffic"])
        asn_stats[tostring(asn)] = as_info
    end

    -- For recent time periods, merge live data with historical data
    -- This ensures complete statistics for the requested time range
    local live_info = as_utils.retrieveASLiveTraffic(options) or {}

    -- Merge live and historical data
    for asn, as_info in pairs(live_info) do
        if not asn_stats[asn] then
            -- New ASN: add live data
            asn_stats[asn] = as_info
        else
            -- Existing ASN: aggregate statistics
            asn_stats[asn]["bytes.sent"] = asn_stats[asn]["bytes.sent"] + as_info["bytes.sent"]
            asn_stats[asn]["bytes.rcvd"] = asn_stats[asn]["bytes.rcvd"] + as_info["bytes.rcvd"]
            asn_stats[asn]["traffic"] = asn_stats[asn]["traffic"] + as_info["traffic"]
            asn_stats[asn]["score"] = asn_stats[asn]["score"] + as_info["score"]
            
            -- Calculate weighted average for throughput
            local time_diff = asn_stats[asn]["seen.last"] - asn_stats[asn]["seen.first"]
            asn_stats[asn]["throughput_bps"] = ((asn_stats[asn]["throughput_bps"] * time_diff) +
                                                   as_info["throughput_bps"]) / (time_diff + 1)

            -- Update first seen timestamp if necessary
            if tonumber(asn_stats[asn]["seen.first"]) < as_info["seen.first"] then
                asn_stats[asn]["seen.first"] = as_info["seen.first"]
            end
        end
    end

    return asn_stats
end

---
-- Retrieves top ASNs by traffic for live data
-- @param options Table containing filtering options (selected_asn)
-- @return table Array of top ASN statistics, sorted by traffic
function as_utils.getTopASLive(options)
    local live_info = as_utils.retrieveASLiveTraffic(options) or {}
    local counter = 0
    local asn_tops = {}
    
    -- Sort by traffic (descending) and take top N
    for _, as_info in pairsByField(live_info, 'traffic', rev) do
        counter = counter + 1
        asn_tops[#asn_tops + 1] = as_info
        if (counter >= MAXIMUM_NUMBER_OF_TOP) then
            break
        end
    end

    return asn_tops
end

---
-- Retrieves top ASNs by traffic for historical data
-- @param options Table containing filtering options (epoch_begin, epoch_end, ifid, selected_asn)
-- @return table Array of top ASN statistics, sorted by traffic
function as_utils.getTopASHistorical(options)
    local live_info = as_utils.retrieveASHistoricalTraffic(options) or {}
    local counter = 0
    local asn_tops = {}
    
    -- Sort by traffic (descending) and take top N
    for _, as_info in pairsByField(live_info, 'traffic', rev) do
        counter = counter + 1
        asn_tops[#asn_tops + 1] = as_info
        if (counter >= MAXIMUM_NUMBER_OF_TOP) then
            break
        end
    end

    return asn_tops
end

return as_utils