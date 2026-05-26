--
-- (C) 2024 - ntop.org
--
-- ClickHouse High-Resolution timeseries driver.
--
-- HR timeseries are read directly from the 'flows' table by unpacking
-- the HR_SRC2DST_BYTES / HR_DST2SRC_BYTES Array(UInt64) columns that
-- nProbe populates when exporting with HR fields. Each element covers
-- a 15-second slot starting at the flow FIRST_SEEN timestamp.
--
-- Note: there is NO write path, HR data is written by the C++ flow-dump,
-- calling append() is not required.
--
-- Schemas backed by this driver must define data_source = "flows"
-- in their options table. This deriver is selected by ts_utils_core via
-- ts_utils.getQueryDriverForSchema().
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local driver = {}

require "ntop_utils"
local ts_common = require("ts_common")

-- ##############################################

local HR_SLOT_SECONDS = 15

-- Maps schema tag names to flows table column names.
local TAG_TO_COLUMN = {
   ifid = "INTERFACE_ID",
}

-- Maps schema metric names to HR array column names in the flows table.
local METRIC_TO_ARRAY = {
   bytes_sent = "HR_SRC2DST_BYTES",
   bytes_rcvd = "HR_DST2SRC_BYTES",
}

-- ##############################################

local function ch_query(sql)
   local res, err = interface.execSQLQuery(sql, false --[[no row limit]], false --[[don't wait]])
   if type(res) ~= "table" then return nil end
   return res
end

local function ch_escape(s)
   s = tostring(s or "")
   s = s:gsub("\\", "\\\\")
   s = s:gsub("'",  "\\'")
   return s
end

-- ##############################################

--! @brief Driver constructor.
--! @param options table with at least { db = "dbname" }.
function driver:new(options)
   if not ntop.isClickHouseEnabled() then return nil end

   local obj = { db = options.db or "ntopng" }
   setmetatable(obj, self)
   self.__index = self
   return obj
end

-- ##############################################
-- Internal helpers
-- ##############################################

-- Build the WHERE fragment for the supplied tags (conditions on flows columns).
local function tags_where(tags)
   local conds = {}
   for tag, val in pairs(tags) do
      local col = TAG_TO_COLUMN[tag]
      if col then
         conds[#conds + 1] = string.format("%s = '%s'", col, ch_escape(val))
      end
   end
   return (#conds > 0) and (" AND " .. table.concat(conds, " AND ")) or ""
end

-- Build the SELECT list for HR metrics.
-- Each metric maps to sum(arrayElement(<HR_array>, slot)).
local function metric_select(schema)
   local sel = {}
   for _, metric in ipairs(schema._metrics) do
      local arr = METRIC_TO_ARRAY[metric]
      if arr then
         sel[#sel + 1] = string.format(
            "sum(arrayElement(%s, slot)) AS `%s`",
            ch_escape(arr), ch_escape(metric))
      end
   end
   return sel
end

-- Return the HR array column to use for ARRAY JOIN (first metric that maps).
local function pick_join_array(schema)
   for _, metric in ipairs(schema._metrics) do
      local arr = METRIC_TO_ARRAY[metric]
      if arr then return arr end
   end
   return "HR_SRC2DST_BYTES"   -- safe fallback
end

-- ClickHouse expression for the wall-clock time of a slot.
-- FIRST_SEEN is UInt32 (epoch seconds); slot is 1-based from arrayEnumerate.
-- Using toUInt64 avoids overflow for flows with many slots.
local function slot_ts_expr()
   return string.format(
      "toUInt64(FIRST_SEEN) + (toUInt64(slot) - 1) * %d",
      HR_SLOT_SECONDS)
end

-- ##############################################
-- Driver API
-- ##############################################

--! @brief No-op: HR data is written by the C++ flow-dump pipeline.
function driver:append(schema, timestamp, tags, metrics)
   return true
end

-- ##############################################

--! @brief Query HR timeseries data from the flows table.
function driver:query(schema, tstart, tend, tags, options)
   local time_step = ts_common.calculateSampledTimeStep(
      HR_SLOT_SECONDS, tstart, tend, options)

   local tw       = tags_where(tags)
   local join_arr = pick_join_array(schema)
   local sel      = metric_select(schema)
   local sts      = slot_ts_expr()

   if #sel == 0 then
      traceError(TRACE_ERROR, TRACE_CONSOLE,
         "[ClickHouse HR] schema '" .. schema.name .. "' has no supported HR metrics")
      return nil
   end

   -- Three-level time filter:
   --   FIRST_SEEN <= tend / LAST_SEEN >= tstart  → pre-filters rows (uses index)
   --   slot timestamp BETWEEN tstart AND tend     → keeps only slots inside window
   local sql = string.format(
      "SELECT intDiv(%s, %d) * %d AS t, %s "
      .. "FROM `%s`.`flows` "
      .. "ARRAY JOIN arrayEnumerate(%s) AS slot "
      .. "WHERE length(%s) > 0%s "
      .. "AND FIRST_SEEN <= %d AND LAST_SEEN >= %d "
      .. "AND %s BETWEEN %d AND %d "
      .. "GROUP BY t ORDER BY t ASC",
      sts, time_step, time_step,
      table.concat(sel, ", "),
      ch_escape(self.db),
      ch_escape(join_arr),
      ch_escape(join_arr), tw,
      tend, tstart,
      sts, tstart, tend)

   local data = ch_query(sql)

   -- Build output series skeletons.
   local series   = {}
   local max_vals = {}
   for i, metric in ipairs(schema._metrics) do
      series[i]   = { id = metric, data = {} }
      max_vals[i] = ts_common.getMaxPointValue(schema, metric, tags)
   end

   local expected_t = tstart
   local idx        = 1

   if data and #data > 0 then
      for _, row in ipairs(data) do
         local cur_t = tonumber(row["t"])
         if cur_t == nil then goto continue end

         -- Fill gaps with fill_value.
         while (cur_t - expected_t) >= time_step do
            for _, serie in ipairs(series) do
               serie.data[idx] = options.fill_value
            end
            idx        = idx + 1
            expected_t = expected_t + time_step
         end

         for i, metric in ipairs(schema._metrics) do
            local v = tonumber(row[metric])
            if v == nil then v = options.fill_value end
            series[i].data[idx] = ts_common.normalizeVal(v, max_vals[i], options)
         end
         idx        = idx + 1
         expected_t = expected_t + time_step

         ::continue::
      end
   end

   -- Fill remaining buckets up to tend.
   while (tend - expected_t) >= 0 do
      if (not options.fill_series) and (expected_t > os.time()) then break end
      for _, serie in ipairs(series) do
         serie.data[idx] = options.fill_value
      end
      idx        = idx + 1
      expected_t = expected_t + time_step
   end

   local count = idx - 1
   local total_serie, stats

   if options.calculate_stats then
      if #series == 1 then
         total_serie = table.clone(series[1].data)
      else
         total_serie = {}
         for i = 1, count do
            local s = 0
            for _, serie in ipairs(series) do
               local v = serie.data[i]
               if v and v == v then s = s + v end   -- skip NaN
            end
            total_serie[i] = s
         end
      end

      if total_serie then
         stats = ts_common.calculateStatistics(total_serie, time_step, tend - tstart,
                    schema.options.metrics_type)
         stats = table.merge(stats or {}, ts_common.calculateMinMax(total_serie))
         for _, serie in ipairs(series) do
            local s = ts_common.calculateStatistics(serie.data, time_step, tend - tstart,
                         schema.options.metrics_type)
            serie.statistics = table.merge(s or {}, ts_common.calculateMinMax(serie.data))
         end
      end
   end

   return {
      metadata = {
         epoch_begin = tstart,
         epoch_end   = tend,
         epoch_step  = time_step,
         num_point   = count,
         schema      = schema.name,
         query       = tags,
      },
      series             = series,
      statistics         = stats,
      source_aggregation = "raw",
      additional_series  = { total = total_serie },
   }
end

-- ##############################################

--! @brief High-level query entry-point (mirrors clickhousets interface).
function driver:timeseries_query(options)
   local actual_tags = options.schema_info:verifyTags(options.tags) or options.tags
   return self:query(options.schema_info, options.epoch_begin, options.epoch_end,
                     actual_tags, options)
end

-- ##############################################

--! @brief Calculate per-metric totals over a time range.
function driver:queryTotal(schema, tstart, tend, tags, options)
   local tw       = tags_where(tags)
   local join_arr = pick_join_array(schema)
   local sts      = slot_ts_expr()
   local sel      = {}

   for _, metric in ipairs(schema._metrics) do
      local arr = METRIC_TO_ARRAY[metric]
      if arr then
         sel[#sel + 1] = string.format(
            "sum(arrayElement(%s, slot)) AS `%s`",
            ch_escape(arr), ch_escape(metric))
      end
   end

   if #sel == 0 then return {} end

   local sql = string.format(
      "SELECT %s FROM `%s`.`flows` "
      .. "ARRAY JOIN arrayEnumerate(%s) AS slot "
      .. "WHERE length(%s) > 0%s "
      .. "AND FIRST_SEEN <= %d AND LAST_SEEN >= %d "
      .. "AND %s BETWEEN %d AND %d",
      table.concat(sel, ", "),
      ch_escape(self.db),
      ch_escape(join_arr),
      ch_escape(join_arr), tw,
      tend, tstart,
      sts, tstart, tend)

   local data = ch_query(sql)
   if (not data) or (#data == 0) then return {} end

   local row = data[1]
   local res = {}
   for _, metric in ipairs(schema._metrics) do
      res[metric] = tonumber(row[metric])
   end
   return res
end

-- ##############################################

--! @brief Return the last N non-NaN values for each metric.
function driver:queryLastValues(options)
   local last_values = {}
   local rsp = self:timeseries_query(options)

   for _, data in pairs((rsp or {}).series or {}) do
      local values = {}
      for i = #data.data, 1, -1 do
         if #values == options.num_points then break end
         if data.data[i] == data.data[i] then   -- skip NaN
            values[#values + 1] = data.data[i]
         end
      end
      last_values[data.id] = values
   end

   return last_values
end

-- ##############################################

--! @brief Top queries are not supported for HR schemas; returns nil.
function driver:timeseries_top(options, top_tags)
   return nil
end

-- ##############################################

--! @brief Check whether HR data exists for the given tags / time range.
function driver:listSeries(schema, tags_filter, wildcard_tags, start_time, end_time)
   local tw        = tags_where(tags_filter)
   local join_arr  = pick_join_array(schema)
   local time_cond = string.format("FIRST_SEEN >= %d", start_time)
   if end_time then
      time_cond = time_cond .. string.format(" AND LAST_SEEN <= %d", end_time)
   end

   local sql = string.format(
      "SELECT 1 FROM `%s`.`flows` "
      .. "WHERE length(%s) > 0%s AND %s LIMIT 1",
      ch_escape(self.db),
      ch_escape(join_arr), tw, time_cond)

   local data = ch_query(sql)
   if (not data) or (#data == 0) then return nil end

   return { tags_filter }
end

-- ##############################################

--! @brief Delete is not meaningful for HR schemas (data lives in the flows table).
function driver:delete(schema_prefix, tags)
   return true
end

--! @brief HR data retention is managed by the flows table retention policy.
function driver:deleteOldData(ifid)
   return true
end

--! @brief No separate setup needed — the flows table is managed elsewhere.
function driver:setup(ts_utils)
   return true
end

--! @brief Return latest available timestamp.
function driver:getLatestTimestamp(ifid)
   return os.time()
end

--! @brief Health reflects ClickHouse reachability (same signal as the TS driver).
function driver:get_health()
   local res = interface.execSQLQuery(
      "SELECT 1 AS ok FROM system.parts LIMIT 1", false, false)
   return (type(res) == "table") and "green" or "yellow"
end

-- ##############################################

return driver
