# ntopng Lua API Reference (`network.*` bindings)

This document describes all C→Lua bindings exposed as `network.*` functions via
`src/LuaEngineNetwork.cpp`.  It is intended both for human developers writing Lua
scripts and as a machine-readable reference for AI-assisted code generation (e.g.
Claude Code in this repository).

---

## Table of Contents

1. [How `network.*` works](#1-how-network-works)
2. [Usage context](#2-usage-context)
3. [Network Selection](#3-network-selection)
4. [Network Statistics](#4-network-statistics)
5. [Alerts](#5-alerts)
6. [Alert Context Cache](#6-alert-context-cache)
7. [Complete Function Index](#7-complete-function-index)

---

## 1. How `network.*` works

### Context

`network.*` functions operate on a **local network** (a configured CIDR subnet)
stored in the Lua VM context (`NtopngLuaContext::network` → `NetworkStats*`).
Before calling most `network.*` functions you must either:

- Call `network.select(network_id)` with the numeric network ID, **or**
- Call `network.checkContext(cidr_string)` with the CIDR string (e.g. `"192.168.1.0/24"`)

Both set the active `NetworkStats` object for the current Lua VM.

### C→Lua registration

Every function in `_ntop_network_reg[]` (bottom of `src/LuaEngineNetwork.cpp`)
follows the standard pattern:

```c
static int ntop_network_xxx(lua_State* vm) {
    NtopngLuaContext* c = getLuaVMContext(vm);
    NetworkStats* ns = c ? c->network : NULL;
    // ...
}

// Registered as:
{ "xxx", ntop_network_xxx },   // called as network.xxx()
```

### Where network check scripts live

Network check scripts are stored in:

```
scripts/lua/modules/network_checks/
```

Each script is a Lua module with a `check()` function called per-network by the
engine.

---

## 2. Usage context

### Standard boilerplate for a network check script

```lua
-- scripts/lua/modules/network_checks/my_network_check.lua
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local alert_consts = require("alert_consts")
local alerts_api   = require("alerts_api")

local my_check = {}

function my_check.check(network_info)
    -- network_info.network_cidr contains the CIDR string, e.g. "10.0.0.0/8"

    -- Ensure the network context is set
    if not network.checkContext(network_info.network_cidr) then return end

    local stats = network.getNetworkStats()
    if not stats then return end

    -- Example: alert on high score
    if stats.score and stats.score > 100 then
        -- store/release alerts via network.storeTriggeredAlert / network.releaseTriggeredAlert
    end
end

return my_check
```

### Using `network.select()` directly (e.g. from a REST endpoint)

```lua
local ifid       = _GET["ifid"] or interface.getFirstInterfaceId()
local network_id = tonumber(_GET["network_id"])

interface.select(tostring(ifid))
network.select(network_id)

local stats = network.getNetworkStats()
rest_utils.answer(rest_utils.consts.success.ok, stats)
```

---

## 3. Network Selection

| Lua call | Returns | Description |
|---|---|---|
| `network.select(network_id)` | `nil` | Selects the active local network by its numeric ID (as returned by `interface.getNetworksStats()` key or `ntop.getLocalNetworkId()`). Pass `nil` to deselect. Must be called before `network.getNetworkStats()`. |
| `network.checkContext(cidr_string)` | `boolean` | Looks up the local network by its CIDR string (e.g. `"192.168.1.0/24"`) and sets it as the active network context. Returns `true` on success, `false` if the CIDR is not a known local network. Preferred in network check scripts where the CIDR is known. |

### Difference between `select` and `checkContext`

| | `network.select(id)` | `network.checkContext(cidr)` |
|---|---|---|
| Input | Numeric network ID | CIDR string |
| Use case | REST endpoints, scripts with a known ID | Network check scripts (engine passes CIDR) |
| Returns | `nil` | `boolean` (success/failure) |

---

## 4. Network Statistics

| Lua call | Returns | Description |
|---|---|---|
| `network.getNetworkStats()` | `table` | Returns a table of traffic and alert statistics for the currently selected local network. Returns `nil` if no network is selected. |
| `network.resetTrafficBetweenNets()` | `nil` | Resets the inter-network traffic matrix counters for the current network. **Pro edition only** — no-op in Community. |

### `network.getNetworkStats()` return table fields

The returned table is populated by `NetworkStats::lua()` and typically includes:

| Field | Type | Description |
|---|---|---|
| `network_id` | `integer` | Numeric ID of this network |
| `network_key` | `string` | CIDR string identifying the network (e.g. `"192.168.1.0/24"`) |
| `score` | `integer` | Current alert score for this network |
| `bytes_sent` | `integer` | Total bytes sent by hosts in this network |
| `bytes_rcvd` | `integer` | Total bytes received by hosts in this network |
| `num_hosts` | `integer` | Number of active hosts in this network |
| `num_local_hosts` | `integer` | Number of active local hosts in this network |
| `engaged_alerts` | `integer` | Count of currently engaged (active) alerts |
| `ingress` | `table` | Per-protocol ingress traffic statistics |
| `egress` | `table` | Per-protocol egress traffic statistics |
| `inner` | `table` | Per-protocol traffic between hosts within this network |

---

## 5. Alerts

### Alert lifecycle

| Lua call | Returns | Description |
|---|---|---|
| `network.getAlerts(params_table)` | `table` | Returns alerts matching given filter criteria for the currently selected local network. Supports the same `params_table` fields as `interface.getAlerts()`: `status`, `alert_type`, `alert_severity`, `page`, `perPage`, `order_by`. |
| `network.storeTriggeredAlert(alert_table)` | `nil` | Stores a triggered alert record in the alert database for the currently selected local network. Called by `alerts_api` internals. |
| `network.releaseTriggeredAlert(alert_table)` | `nil` | Marks a previously triggered alert for the current network as resolved/released. Called by `alerts_api` internals. |

### Typical alert pattern in a network check script

```lua
local alerts_api   = require("alerts_api")
local alert_consts = require("alert_consts")

-- In check():
local score = (network.getNetworkStats() or {}).score or 0
local alert_info = {
    alert_type     = alert_consts.alert_types.alert_network_anomaly,
    alert_severity = alert_consts.alert_severities.error,
    alert_entity   = alerts_api.networkEntity(network_info.network_cidr),
    alert_score    = score,
}

if score > 200 then
    alerts_api.store(alert_info)
else
    alerts_api.release(alert_info)
end
```

---

## 6. Alert Context Cache

The alert context cache lets network check scripts persist small state values
(strings) between consecutive check runs without hitting Redis.  Values are keyed
by `(key, periodicity)` pairs — different periodicities (minute, 5-minute, hourly,
etc.) maintain independent cache namespaces.

| Lua call | Returns | Description |
|---|---|---|
| `network.getCachedAlertValue(key, periodicity)` | `string` | Retrieves a cached string value for the current network. `key` is an arbitrary string; `periodicity` is a `ScriptPeriodicity` integer constant. Returns an empty string `""` if not set. |
| `network.setCachedAlertValue(key, value, periodicity)` | `nil` | Stores a string value in the alert context cache for the current network. Both `key` and `value` are strings; `periodicity` is a `ScriptPeriodicity` integer. |

### `ScriptPeriodicity` constants

These are defined in Lua as `checks.periodicities.*`:

| Constant | Typical value | Period |
|---|---|---|
| `checks.periodicities.min` | `0` | Every minute |
| `checks.periodicities.5mins` | `1` | Every 5 minutes |
| `checks.periodicities.hour` | `2` | Every hour |
| `checks.periodicities.day` | `3` | Every day |

### Cache usage example — track previous byte count for delta alerting

```lua
local checks = require("checks")
local periodicity = checks.periodicities.min

local stats    = network.getNetworkStats() or {}
local cur_bytes = (stats.bytes_sent or 0) + (stats.bytes_rcvd or 0)

local prev_str  = network.getCachedAlertValue("prev_bytes", periodicity)
local prev_bytes = tonumber(prev_str) or 0

local delta = cur_bytes - prev_bytes
network.setCachedAlertValue("prev_bytes", tostring(cur_bytes), periodicity)

if delta > 1e9 then
    -- alert: more than 1 GB transferred in one minute
end
```

---

## 7. Complete Function Index

All 9 `network.*` functions:

| Lua function | C implementation | Category |
|---|---|---|
| `network.checkContext(cidr_string)` | `ntop_network_check_context` | Selection |
| `network.getCachedAlertValue(key, periodicity)` | `ntop_network_get_cached_alert_value` | Alert cache |
| `network.getAlerts(params_table)` | `ntop_network_get_alerts` | Alerts |
| `network.getNetworkStats()` | `ntop_network_get_network_stats` | Statistics |
| `network.releaseTriggeredAlert(alert_table)` | `ntop_network_release_triggered_alert` | Alerts |
| `network.resetTrafficBetweenNets()` | `ntop_network_reset_traffic_between_nets` | Statistics |
| `network.select(network_id)` | `ntop_select_local_network` | Selection |
| `network.setCachedAlertValue(key, value, periodicity)` | `ntop_network_set_cached_alert_value` | Alert cache |
| `network.storeTriggeredAlert(alert_table)` | `ntop_network_store_triggered_alert` | Alerts |
