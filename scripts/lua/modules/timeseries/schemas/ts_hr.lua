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

-- ############################################

-- flow:hr_traffic
-- Per-flow traffic at 15-second slot resolution.
-- The flow is identified by its 5-tuple,
-- plus first_seen to pin a specific instance.
schema = ts_utils.newSchema("flow:hr_traffic", {
    step          = 15,
    metrics_type  = ts_utils.metrics.counter,
    data_source   = "flows",
    flow_context  = true,  -- driver uses flow-specific WHERE logic
})
schema:addTag("ifid")
schema:addTag("cli_ip")
schema:addTag("srv_ip")
schema:addTag("cli_port")
schema:addTag("srv_port")
schema:addTag("protocol")
schema:addTag("first_seen")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")

-- ############################################

-- flow:hr_traffic_aggr
-- Aggregated traffic from HR flow counters matching optional WHERE filters.
-- Only ifid is required, other tags are used to build extra WHERE conditions
-- (missing / empty tags are skipped by the driver).
schema = ts_utils.newSchema("flow:hr_traffic_aggr", {
    step         = 15,
    metrics_type = ts_utils.metrics.counter,
    data_source  = "flows",
    agg_context  = true,
})
schema:addTag("ifid")
schema:addTag("cli_ip")
schema:addTag("srv_ip")
schema:addTag("cli_port")
schema:addTag("srv_port")
schema:addTag("l4proto")
schema:addTag("l7proto")
schema:addMetric("bytes_sent")
schema:addMetric("bytes_rcvd")
