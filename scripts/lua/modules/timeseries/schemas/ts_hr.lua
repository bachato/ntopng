--
-- (C) 2024 - ntop.org
--
-- High-Resolution timeseries schemas.
--
-- These schemas read their data directly from the ClickHouse 'flows'
-- table (via the clickhousehr driver) instead of the 'timeseries'
-- table.  The flows table carries HR_SRC2DST_BYTES / HR_DST2SRC_BYTES
-- Array(UInt64) columns populated by nProbe when HR fields are
-- exported, giving 15-second slot granularity per flow.
--
-- Requirements:
--   - Enterprise M (or better) license
--   - ClickHouse configured as flow dump backend (-F clickhouse)
--   - nProbe with HR counter support
--
-- All schemas here must set:
--   data_source = "flows"
-- so ts_utils_core routes queries to the clickhousehr driver.
--

local ts_utils = require("ts_utils_core")

-- ############################################

-- iface:hr_traffic
-- Per-interface aggregate traffic at 15-second slot resolution.
-- Metrics are byte counters summed over all flows active in each slot.
local schema = ts_utils.newSchema("iface:hr_traffic", {
    step         = 15,
    metrics_type = ts_utils.metrics.counter,
    data_source  = "flows",
})
schema:addTag("ifid")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ############################################

-- host:hr_traffic
-- Per-host traffic at 15-second slot resolution.
schema = ts_utils.newSchema("host:hr_traffic", {
    step           = 15,
    metrics_type   = ts_utils.metrics.counter,
    data_source    = "flows",
    host_direction = "host", -- tag that determines traffic direction
})
schema:addTag("ifid")
schema:addTag("host")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")
