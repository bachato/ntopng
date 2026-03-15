# ntopng Lua API Reference (`host.*` bindings)

This document describes all C→Lua bindings exposed as `host.*` functions via
`src/LuaEngineHost.cpp`.  It is intended both for human developers writing Lua
scripts and as a machine-readable reference for AI-assisted code generation (e.g.
Claude Code in this repository).

---

## Table of Contents

1. [How `host.*` works](#1-how-host-works)
2. [Usage context](#2-usage-context)
3. [Identity & Addressing](#3-identity--addressing)
4. [Address Type Flags](#4-address-type-flags)
5. [Traffic Counters](#5-traffic-counters)
6. [Protocol Statistics](#6-protocol-statistics)
7. [Peer Contact Counters](#7-peer-contact-counters)
8. [Score & Alerts](#8-score--alerts)
9. [Script Control](#9-script-control)
10. [Complete Function Index](#10-complete-function-index)

---

## 1. How `host.*` works

### Context

`host.*` functions are available **only inside host check scripts** — Lua scripts
invoked by the ntopng host-processing engine for each tracked host.  They operate
on the **current host** implicitly stored in the Lua VM context
(`NtopngLuaContext::host`); no arguments are needed to identify the host.

### C→Lua registration

Every function in `_ntop_host_reg[]` (bottom of `src/LuaEngineHost.cpp`) follows
this pattern:

```c
static int ntop_host_get_xxx(lua_State* vm) {
    NtopngLuaContext* c = getLuaVMContext(vm);
    Host* h = c ? c->host : NULL;

    if (h)
        lua_push<type>(vm, h->get_xxx());
    else
        lua_pushnil(vm);

    return ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK);
}

// Registered as:
{ "xxx", ntop_host_get_xxx },   // called as host.xxx()
```

### Where host check scripts live

Host check scripts are stored in:

```
scripts/lua/modules/host_checks/
```

Each script is a Lua module that exports a `check()` function called per-host by
the engine.

---

## 2. Usage context

### Standard boilerplate for a host check script

```lua
-- scripts/lua/modules/host_checks/my_host_check.lua
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local host_consts = require("host_consts")

local my_check = {}

-- Called once per tracked host by the engine
function my_check.check(host_info)
    -- Guard: skip non-local or non-unicast hosts
    if not host.is_local() then return end
    if not host.is_unicast() then return end

    -- Skip on first run (no baseline yet)
    if host.isFirstCheckRun() then return end

    local bytes = host.bytes()
    local score = host.score()

    if bytes > 1e9 then
        host.triggerAlert(100, "Host transferred > 1 GB: " .. tostring(bytes))
    end
end

return my_check
```

### Important notes

- `host.*` functions return `nil` if called outside a host check context (i.e.
  when `NtopngLuaContext::host` is `NULL`).
- Most functions take **no arguments** (exceptions: `host.skipVisitedHost` and
  `host.triggerAlert`).
- `host.*` is completely separate from `interface.*` — there is no need to call
  `interface.select()` inside host check scripts.
- Unlike `flow.*`, host check scripts run periodically (not per-packet), so
  counters reflect accumulated totals since the host was first seen.

---

## 3. Identity & Addressing

| Lua call | Returns | Description |
|---|---|---|
| `host.ip()` | `string` | The IP address (or IP/mask for network hosts) of the current host, e.g. `"192.168.1.10"` or `"10.0.0.0/24"`. |
| `host.mac()` | `string` | The MAC address string associated with the current host (e.g. `"aa:bb:cc:dd:ee:ff"`). Returns a zero MAC (`"00:00:00:00:00:00"`) if unknown. |
| `host.name()` | `string` | The visual display name for the current host — the resolved hostname if available, otherwise a custom label, otherwise the IP string. |
| `host.vlan_id()` | `integer` | The VLAN ID associated with the current host. Returns `0` if the host is not on a tagged VLAN. |

---

## 4. Address Type Flags

These predicates classify the host's IP address type. All return `false` when
called outside a host check context.

| Lua call | Returns | Description |
|---|---|---|
| `host.is_local()` | `boolean` | `true` if the host's IP falls within a locally configured network (i.e. it is an "inside" host). |
| `host.is_unicast()` | `boolean` | `true` if the host's IP is a unicast address (not broadcast or multicast). Returns `true` when the host has no IP. |
| `host.is_multicast()` | `boolean` | `true` if the host's IP is a multicast address (224.0.0.0/4 for IPv4, ff00::/8 for IPv6). |
| `host.is_broadcast()` | `boolean` | `true` if the host's IP is a broadcast address (e.g. 255.255.255.255 or a directed broadcast). |
| `host.is_blacklisted()` | `boolean` | `true` if the host's IP appears on any configured threat intelligence blacklist. |
| `host.is_rx_only()` | `boolean` | `true` if the host has only ever been seen receiving traffic (no outbound packets observed). |

### Typical guard pattern

```lua
-- Most checks only make sense for local unicast hosts
if not host.is_local() then return end
if not host.is_unicast() then return end
if host.is_blacklisted() then return end  -- already flagged elsewhere
```

---

## 5. Traffic Counters

All byte counters accumulate from the moment the host was first seen (or since the
last counter reset via `interface.resetHostStats()`).

| Lua call | Returns | Description |
|---|---|---|
| `host.bytes()` | `integer` | Total bytes transferred in both directions (sent + received). |
| `host.bytes_sent()` | `integer` | Total bytes sent (uploaded) by this host. |
| `host.bytes_rcvd()` | `integer` | Total bytes received (downloaded) by this host. |

---

## 6. Protocol Statistics

| Lua call | Returns | Description |
|---|---|---|
| `host.l7()` | `table` | Returns a table of per-nDPI-protocol byte and flow statistics for this host. Each key is a protocol name; each value is a sub-table with `bytes_sent`, `bytes_rcvd`, `flows` fields. Returns `nil` if nDPI stats are not available for this host. |

### Example — detect heavy BitTorrent usage

```lua
local l7 = host.l7()
if l7 and l7["BitTorrent"] then
    local bt = l7["BitTorrent"]
    if (bt.bytes_sent + bt.bytes_rcvd) > 100e6 then
        host.triggerAlert(60, "Heavy BitTorrent usage detected")
    end
end
```

---

## 7. Peer Contact Counters

These counters track TCP/UDP connections that were **one-sided** (the host sent
traffic but received no reply, or vice versa).  They are useful for detecting port
scans, SYN floods, and other anomalous contact patterns.

| Lua call | Returns | Description |
|---|---|---|
| `host.getNumContactedPeersAsClientTCPUDPNoTX()` | `integer` | Number of distinct remote peers this host contacted as a TCP/UDP client but never received any reply from. High values may indicate a port/host scan. |
| `host.getNumContactsFromPeersAsServerTCPUDPNoTX()` | `integer` | Number of distinct remote clients that attempted to connect to this host as a TCP/UDP server but were never answered. High values may indicate this host is a scan target. |
| `host.getNumContactedTCPUDPServerPortsNoTX()` | `integer` | Number of distinct server ports this host contacted (as client) with no reply received. Useful for detecting horizontal port scans. |
| `host.getUnidirectionalTCPUDPFlowsStats()` | `table` | Returns a table breaking down unidirectional (no-reply) TCP/UDP flow counts by client and server roles. |
| `host.resetHostContacts()` | `nil` | Resets all peer-contact counters for this host (contacted peers, server ports, unidirectional flows). Used after processing to avoid double-counting across check intervals. |

### Example — port scan detection

```lua
local contacted_ports = host.getNumContactedTCPUDPServerPortsNoTX()
local contacted_peers = host.getNumContactedPeersAsClientTCPUDPNoTX()

if contacted_ports > 50 or contacted_peers > 100 then
    host.triggerAlert(80, string.format(
        "Possible scan: %d ports / %d peers with no reply",
        contacted_ports, contacted_peers))
    host.resetHostContacts()  -- reset to avoid re-alerting next cycle
end
```

---

## 8. Score & Alerts

| Lua call | Returns | Description |
|---|---|---|
| `host.score()` | `integer` | The current alert score for this host — the sum of all active alert severity scores. Higher values indicate more/worse active alerts. |
| `host.triggerAlert(value, msg)` | `nil` | Triggers a custom alert on the current host. `value` is a numeric severity/score contribution; `msg` is a description string that appears in the alert details. No-op if called outside a host check context. |

### Alert severity guidelines

| Score value | Suggested severity |
|---|---|
| 1–25 | Informational |
| 26–50 | Warning |
| 51–75 | Error |
| 76–100 | Critical |

---

## 9. Script Control

| Lua call | Returns | Description |
|---|---|---|
| `host.isFirstCheckRun()` | `boolean` | Returns `true` if this is the very first invocation of the host check script for this host. Use this to skip checks that require a baseline (e.g. delta comparisons). |
| `host.skipVisitedHost([skip[, skip_until]])` | `nil` | Controls whether the host check script re-evaluates this host. Call with `skip=true` to suppress future evaluations; optionally pass `skip_until` as a Unix timestamp after which evaluation resumes. Call with `skip=false` (or no arguments) to re-enable evaluation. |

### `skipVisitedHost` usage pattern

```lua
-- After triggering an alert, suppress re-alerting for 1 hour
if should_alert then
    host.triggerAlert(70, "Anomaly detected")
    local one_hour_from_now = os.time() + 3600
    host.skipVisitedHost(true, one_hour_from_now)
end
```

---

## 10. Complete Function Index

All 23 `host.*` functions:

| Lua function | C implementation | Category |
|---|---|---|
| `host.bytes()` | `ntop_host_get_bytes_total` | Traffic |
| `host.bytes_rcvd()` | `ntop_host_get_bytes_rcvd` | Traffic |
| `host.bytes_sent()` | `ntop_host_get_bytes_sent` | Traffic |
| `host.getNumContactedPeersAsClientTCPUDPNoTX()` | `ntop_get_num_contacted_peers_as_client_tcp_udp_notx` | Peer contacts |
| `host.getNumContactedTCPUDPServerPortsNoTX()` | `ntop_get_num_contacted_tcp_udp_server_ports_notx` | Peer contacts |
| `host.getNumContactsFromPeersAsServerTCPUDPNoTX()` | `ntop_get_num_contacts_from_peers_as_server_tcp_udp_notx` | Peer contacts |
| `host.getUnidirectionalTCPUDPFlowsStats()` | `ntop_get_unidirectional_tcp_udp_flows_stats` | Peer contacts |
| `host.ip()` | `ntop_host_get_ip` | Identity |
| `host.isFirstCheckRun()` | `ntop_is_first_check_run` | Script control |
| `host.is_blacklisted()` | `ntop_host_is_blacklisted` | Address flags |
| `host.is_broadcast()` | `ntop_host_is_broadcast` | Address flags |
| `host.is_local()` | `ntop_host_is_local` | Address flags |
| `host.is_multicast()` | `ntop_host_is_multicast` | Address flags |
| `host.is_rx_only()` | `ntop_host_is_rx_only` | Address flags |
| `host.is_unicast()` | `ntop_host_is_unicast` | Address flags |
| `host.l7()` | `ntop_host_get_l7_stats` | Protocol stats |
| `host.mac()` | `ntop_host_get_mac` | Identity |
| `host.name()` | `ntop_host_get_name` | Identity |
| `host.resetHostContacts()` | `ntop_reset_host_contacts` | Peer contacts |
| `host.score()` | `ntop_host_get_score` | Score & alerts |
| `host.skipVisitedHost([skip[, skip_until]])` | `ntop_skip_visited_host` | Script control |
| `host.triggerAlert(value, msg)` | `ntop_trigger_host_alert` | Score & alerts |
| `host.vlan_id()` | `ntop_host_get_vlan_id` | Identity |
