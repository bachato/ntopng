# ntopng Lua API Reference (`interface.*` bindings)

This document describes all C→Lua bindings exposed as `interface.*` functions via
`src/LuaEngineInterface.cpp`.  It is intended both for human developers writing Lua
scripts and as a machine-readable reference for AI-assisted code generation (e.g.
Claude Code in this repository).

---

## Table of Contents

1. [How `interface.*` works](#1-how-interface-works)
2. [REST API development guide](#2-rest-api-development-guide)
3. [Interface Selection & Identity](#3-interface-selection--identity)
4. [Interface Type & Capability Flags](#4-interface-type--capability-flags)
5. [Interface Statistics](#5-interface-statistics)
6. [Host Information](#6-host-information)
7. [Flow Information](#7-flow-information)
8. [MAC Address Information](#8-mac-address-information)
9. [nDPI Protocol & Category](#9-ndpi-protocol--category)
10. [Alerts](#10-alerts)
11. [SNMP & Flow Devices](#11-snmp--flow-devices)
12. [Host Pools & Quotas](#12-host-pools--quotas)
13. [Network / AS / VLAN / Country Statistics](#13-network--as--vlan--country-statistics)
14. [Service & Periodicity Maps](#14-service--periodicity-maps)
15. [ACL Management](#15-acl-management)
16. [Network Discovery (mDNS / ARP / Ping)](#16-network-discovery-mdns--arp--ping)
17. [Live Capture & PCAP](#17-live-capture--pcap)
18. [RRD Queue](#18-rrd-queue)
19. [ClickHouse](#19-clickhouse)
20. [sFlow](#20-sflow)
21. [eBPF / Containers](#21-ebpf--containers)
22. [nEdge / L7 Shaping & Policy](#22-nedge--l7-shaping--policy)
23. [RADIUS Accounting (nEdge)](#23-radius-accounting-nedge)
24. [Miscellaneous](#24-miscellaneous)

---

## 1. How `interface.*` works

### Selecting an interface first

All `interface.*` functions operate on the **currently selected interface** stored in
the Lua VM state.  You **must** call `interface.select(ifid)` before any other
`interface.*` call — otherwise the VM uses a fallback interface (the first available).

```lua
-- Always select an interface first
local ifid = _GET["ifid"] or interface.getFirstInterfaceId()
interface.select(tostring(ifid))
```

### C→Lua registration

Every Lua function in `_ntop_interface_reg[]` (bottom of
`src/LuaEngineInterface.cpp`) follows this pattern:

```c
// 1. Implement a static C function
static int ntop_my_function(lua_State* vm) {
    NetworkInterface* ntop_interface = getCurrentInterface(vm);
    if (!ntop_interface) return (CONST_LUA_ERROR);

    ntop_lua_check(vm, __FUNCTION__, 1, LUA_TSTRING);
    const char* arg = lua_tostring(vm, 1);

    lua_pushstring(vm, result);
    return CONST_LUA_OK;  // or CONST_LUA_ERROR
}

// 2. Register it
{ "myFunction", ntop_my_function },   // called as interface.myFunction(...)
```

### Standard boilerplate (REST endpoints using interface.*)

```lua
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json       = require("dkjson")
local rest_utils = require("rest_utils")

-- Select interface
local ifid = _GET["ifid"] or interface.getFirstInterfaceId()
interface.select(tostring(ifid))
```

---

## 2. REST API development guide

### File location

REST endpoints live at:

```
scripts/lua/rest/v2/<method>/<resource>/<action>.lua
```

Examples:
- `scripts/lua/rest/v2/get/interface/data.lua`
- `scripts/lua/rest/v2/get/host/data.lua`
- `scripts/lua/rest/v2/get/flow/active.lua`

### Minimal REST endpoint template

```lua
-- scripts/lua/rest/v2/get/interface/my_endpoint.lua
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json       = require("dkjson")
local rest_utils = require("rest_utils")

-- Auth check
if not isAdministratorOrPrintErr() then
  rest_utils.answer(rest_utils.consts.err.not_granted)
  return
end

-- Param validation
local ifid = _GET["ifid"]
if not ifid then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

-- Select interface and fetch data
interface.select(tostring(ifid))
local stats = interface.getStats()

rest_utils.answer(rest_utils.consts.success.ok, stats)
```

### `rest_utils.consts` error table (most common)

| Constant | HTTP code | Meaning |
|---|---|---|
| `success.ok` | 200 | OK |
| `err.not_granted` | 401 | Not authorized |
| `err.invalid_args` | 400 | Bad/missing params |
| `err.internal_error` | 500 | C-level error |
| `err.not_found` | 404 | Resource not found |
| `err.not_allowed` | 405 | Method not allowed |

### Common REST patterns

**Pattern 1 — Return interface stats**
```lua
interface.select(tostring(ifid))
local stats = interface.getStats()
rest_utils.answer(rest_utils.consts.success.ok, stats)
```

**Pattern 2 — Return host info**
```lua
interface.select(tostring(ifid))
local host = _GET["host"]
local vlan  = _GET["vlan"] or 0
local info  = interface.getHostInfo(host, vlan)
if not info then
  rest_utils.answer(rest_utils.consts.err.not_found)
  return
end
rest_utils.answer(rest_utils.consts.success.ok, info)
```

**Pattern 3 — Paginated flow listing**
```lua
interface.select(tostring(ifid))
local flows = interface.getFlowsInfo({
  currentPage  = tonumber(_GET["page"]) or 1,
  perPage      = tonumber(_GET["perPage"]) or 10,
  sortColumn   = _GET["sortColumn"] or "bytes",
  sortOrder    = _GET["sortOrder"] or "desc",
})
rest_utils.answer(rest_utils.consts.success.ok, flows)
```

**Pattern 4 — nDPI stats for an interface**
```lua
interface.select(tostring(ifid))
local ndpi = interface.getnDPIStats()
rest_utils.answer(rest_utils.consts.success.ok, ndpi)
```

---

## 3. Interface Selection & Identity

| Lua call | Returns | Description |
|---|---|---|
| `interface.getIfNames([exclude_viewed])` | `table` | Returns a table mapping interface IDs (as string keys) to interface names. Pass `true` to exclude viewed sub-interfaces. |
| `interface.getFirstInterfaceId()` | `integer` | Returns the numeric ID of the first available network interface. Useful as a default when no `ifid` is supplied. |
| `interface.select(ifid)` | `nil` | Selects the active interface for all subsequent `interface.*` calls in this Lua VM. `ifid` may be a number or string. **Must be called before any other interface.* function.** |
| `interface.getId()` | `integer` | Returns the numeric ID of the currently selected interface. |
| `interface.getName()` | `string` | Returns the name (e.g. `"eth0"`) of the currently selected interface. |
| `interface.getMasterInterfaceId()` | `integer` | Returns the numeric ID of the parent (master) interface when this is a sub-interface. |
| `interface.isValidIfId(ifid)` | `boolean` | Returns `true` if the given interface ID or name corresponds to an existing, enabled interface. |
| `interface.getMaxIfSpeed([ifname_or_id])` | `integer` | Returns the configured maximum speed in bps. Defaults to the current interface if no argument given. |
| `interface.getEndpoint()` | `string` | Returns the capture endpoint/source string (e.g. `"eth0"`, `"tcp://127.0.0.1:1234"`). |
| `interface.getIfMac()` | `string` | Returns the hardware MAC address of the currently selected interface. |
| `interface.name2id(ifname)` | `integer` | Converts an interface name string to its numeric ID. |

---

## 4. Interface Type & Capability Flags

| Lua call | Returns | Description |
|---|---|---|
| `interface.isPacketInterface()` | `boolean` | `true` if this is a live packet-capture interface (not ZMQ/sFlow/eBPF). |
| `interface.isDiscoverableInterface()` | `boolean` | `true` if network discovery is supported on this interface. |
| `interface.isBridgeInterface()` | `boolean` | `true` if this interface is operating in nEdge bridge/inline mode. |
| `interface.isPcapDumpInterface()` | `boolean` | `true` if this is a PCAP replay/dump interface. |
| `interface.isDatabaseViewInterface()` | `boolean` | `true` if this is a ClickHouse/DB view interface. |
| `interface.isZMQInterface()` | `boolean` | `true` if this interface receives flows via ZMQ (nProbe integration). |
| `interface.isView()` | `boolean` | `true` if this is an aggregated view interface covering multiple sub-interfaces. |
| `interface.isViewed()` | `boolean` | `true` if this interface is aggregated by a view interface. |
| `interface.viewedBy()` | `integer` | Returns the ID of the view interface that aggregates this interface, or `nil`. |
| `interface.isLoopback()` | `boolean` | `true` if this is a loopback interface. |
| `interface.isRunning()` | `boolean` | `true` if the interface capture thread is currently running. |
| `interface.isIdle()` | `boolean` | `true` if the interface is idle (no recent traffic). |
| `interface.setInterfaceIdleState(is_idle)` | `nil` | Sets the idle state of the interface (used by management scripts). |
| `interface.isSubInterface()` | `boolean` | `true` if this is a disaggregated sub-interface. |
| `interface.isSyslogInterface()` | `boolean` | `true` if this interface receives syslog events. |
| `interface.hasVLANs()` | `boolean` | `true` if the interface has observed VLAN-tagged traffic. |
| `interface.hasEBPF()` | `boolean` | `true` if the interface has received eBPF process-level events. |
| `interface.hasExternalAlerts()` | `boolean` | `true` if the interface has received external (injected) alerts. |

---

## 5. Interface Statistics

| Lua call | Returns | Description |
|---|---|---|
| `interface.getStats()` | `table` | Returns comprehensive real-time statistics for the interface (bytes, packets, flows, hosts, drops, throughput, etc.). |
| `interface.getStatsUpdateFreq()` | `integer` | Returns the statistics update frequency in seconds for this interface. |
| `interface.getSecsToFirstData()` | `integer` | Returns seconds elapsed since the interface first received traffic. |
| `interface.updateDirectionStats()` | `nil` | Forces an update of per-direction (upload/download) statistics. |
| `interface.updateTopSites()` | `nil` | Triggers a refresh of the top-sites (popular domains) tracking. |
| `interface.getThroughput()` | `table` | Returns current throughput in bps and pps in both directions (`{"upload_bps":…, "download_bps":…, …}`). |
| `interface.getHashTablesStats()` | `table` | Returns size and usage statistics for the interface hash tables (hosts, flows, MACs, etc.). |
| `interface.getPeriodicActivitiesStats()` | `table` | Returns timing and execution statistics for all periodic scripts on this interface. |
| `interface.getQueuesStats()` | `table` | Returns enqueue/dequeue statistics for internal interface queues. |
| `interface.setPeriodicActivityProgress(activity, progress_pct)` | `nil` | Updates the completion percentage for a running periodic script (used internally by periodic scripts). |
| `interface.getActiveFlowsStats([params])` | `table` | Returns statistics on currently active flows grouped by various dimensions. |
| `interface.getLiveASNStats(asn)` | `table` | Returns live (real-time) traffic statistics for a specific ASN. |
| `interface.getAnomalies()` | `table` | Returns a table of currently active behavioral anomalies on this interface. |
| `interface.getScore()` | `table` | Returns the current alert score breakdown for this interface. |
| `interface.getProtocolFlowsStats()` | `table` | Returns per-L4-protocol flow and byte statistics. |
| `interface.getVLANFlowsStats()` | `table` | Returns per-VLAN flow and byte statistics. |
| `interface.resetCounters([only_drops])` | `nil` | Resets traffic counters for the interface. Pass `true` to reset only drop counters. |
| `interface.resetBroadcastDomains()` | `nil` | Resets all learned broadcast domain state for the interface. |
| `interface.incSyslogStats(stat_name, n)` | `nil` | Increments a named syslog processing statistics counter. |

---

## 6. Host Information

### Host counts

| Lua call | Returns | Description |
|---|---|---|
| `interface.getNumHosts()` | `integer` | Total count of active hosts (local + remote). |
| `interface.getNumLocalHosts()` | `integer` | Count of currently active local hosts. |
| `interface.getNumLocalRxOnlyHosts()` | `integer` | Count of local hosts seen only in the receive direction. |
| `interface.getNumFlows()` | `integer` | Total count of active flows on this interface. |

### Host listing

| Lua call | Returns | Description |
|---|---|---|
| `interface.getHostsInfo([params])` | `table` | Returns information for all hosts (local + remote) on the interface. `params` table supports: `currentPage`, `perPage`, `sortColumn`, `sortOrder`, `host`, `vlan`, `country`, `os`, `asn`, `vlan_id`, `pool`, `network`, `filter`. |
| `interface.getLocalHostsInfo([params])` | `table` | Returns information for local hosts only. Same `params` as `getHostsInfo`. |
| `interface.getLocalHostsInfoNoTX([params])` | `table` | Returns local hosts that have received but not sent any traffic. |
| `interface.getLocalHostsInfoNoTXTCP([params])` | `table` | Returns local hosts that have not sent any TCP traffic. |
| `interface.getRemoteHostsInfo([params])` | `table` | Returns information for remote (non-local) hosts only. |
| `interface.getRemoteHostsInfoNoTX([params])` | `table` | Returns remote hosts that have received but not sent any traffic. |
| `interface.getRemoteHostsInfoNoTXTCP([params])` | `table` | Returns remote hosts that have not sent any TCP traffic. |
| `interface.getRxOnlyHostsList()` | `table` | Returns hosts that have only been seen in the receive direction. |
| `interface.getBroadcastDomainHostsInfo([params])` | `table` | Returns hosts that are part of broadcast domains on this interface. |
| `interface.getBroadcastMulticastHostsInfo([params])` | `table` | Returns broadcast/multicast group hosts on this interface. |
| `interface.getPublicHostsInfo([params])` | `table` | Returns hosts with public (routable) IP addresses. |
| `interface.getInterfaceHosts([include_details])` | `table` | Returns all active hosts as a flat array. |
| `interface.getBatchedHostsInfo(cursor, count)` | `table` | Returns a paginated batch of host records for all hosts. |
| `interface.getBatchedLocalHostsInfo(cursor, count)` | `table` | Returns a paginated batch of local host records. |
| `interface.getBatchedRemoteHostsInfo(cursor, count)` | `table` | Returns a paginated batch of remote host records. |
| `interface.getBatchedLocalHostsTs(cursor, count)` | `table` | Returns a paginated batch of local host time-series data. |

### Single-host queries

| Lua call | Returns | Description |
|---|---|---|
| `interface.isHostActive(host[,vlan])` | `boolean` | Returns `true` if the specified host is currently active. |
| `interface.getHostInfo(host[,vlan])` | `table` | Returns comprehensive information for a specific host (bytes, packets, flows, nDPI breakdown, alerts, score, etc.). |
| `interface.getHostMinInfo(host[,vlan])` | `table` | Returns minimal host info (bytes, packets, score) for lightweight polling. |
| `interface.getHostCountry(host[,vlan])` | `string` | Returns the 2-letter ISO country code for a host's IP via GeoIP. |
| `interface.findHost(host[,vlan])` | `table` | Finds a host by IP or name and returns its info, or `nil` if not active. |
| `interface.findHostByMac(mac)` | `table` | Finds a host by its MAC address and returns its info. |
| `interface.getHostAttributes(host, vlan)` | `table` | Returns classification attributes for a host (device type, OS, category). |
| `interface.getHostsByPort(port, proto)` | `table` | Returns hosts using the specified server port and transport protocol. |
| `interface.getHostsByService(service_name)` | `table` | Returns hosts using a specific application service. |
| `interface.getHostsPorts(params)` | `table` | Returns a list of server ports used by hosts on this interface. |
| `interface.getnDPIHostStats(host, vlan)` | `table` | Returns per-protocol nDPI traffic statistics for a specific host. |
| `interface.getAddressInfo(ip_or_name)` | `table` | Returns comprehensive address information (DNS, geolocation, ASN) for an IP or hostname. |

### Host modification

| Lua call | Returns | Description |
|---|---|---|
| `interface.setHostOperatingSystem(host, vlan, os_id)` | `nil` | Overrides the detected operating system for a host. |
| `interface.setHostResolvedName(host, vlan, name)` | `nil` | Sets the resolved DNS name for a host. |
| `interface.resetHostStats(host, vlan)` | `nil` | Resets all traffic statistics for a specific host. |
| `interface.resetHostTopSites(host, vlan)` | `nil` | Resets the top-sites statistics for a specific host. |
| `interface.deleteHostData(host, vlan)` | `nil` | Permanently deletes all stored data for a specific host. |
| `interface.updateHostTrafficPolicy(host, vlan)` | `nil` | Forces a traffic policy refresh for a specific host. |
| `interface.reloadHostPrefs(host[,vlan])` | `nil` | Reloads per-host preference overrides from Redis for a specific host. |
| `interface.dropHostTraffic(host, vlan)` | `nil` | Marks all traffic for a host for dropping (nEdge inline mode). |
| `interface.addDataToLocalHostAssets(ip, data_table)` | `nil` | Adds asset attributes to a local host's discovery record. |
| `interface.removeDataFromLocalHostAssets(ip)` | `nil` | Removes a local host's asset discovery record. |
| `interface.addMacsIpAddresses()` | `nil` | Forces re-association of MAC addresses with their known IP addresses. |

---

## 7. Flow Information

### Flow listing & search

| Lua call | Returns | Description |
|---|---|---|
| `interface.getFlowsInfo([params_table])` | `table` | Returns detailed information for all active flows. `params_table` supports `currentPage`, `perPage`, `sortColumn`, `sortOrder`, `host`, `vlan`, `application`, `category`, `l4proto`, `status`, `alert_type`, `traffic_type`. |
| `interface.getBatchedFlowsInfo(cursor, count[,filter])` | `table` | Returns a paginated batch of active flow records. |
| `interface.getGroupedFlows(params_table)` | `table` | Returns flows aggregated (grouped) by a specified key field. |
| `interface.getFlowsStats()` | `table` | Returns aggregate flow statistics counts for the interface. |
| `interface.getFlowsStatus()` | `table` | Returns flow status distribution (normal, warning, alert) for this interface. |
| `interface.getLocalServerPorts(proto)` | `table` | Returns server ports observed on local hosts for a given L4 protocol. |
| `interface.listHTTPhosts([filter])` | `table` | Returns a list of hosts with active HTTP/HTTPS flows. |
| `interface.findFlowByKeyAndHashId(key, hash_id)` | `table` | Finds and returns an active flow by its hash key and bucket ID. |
| `interface.findFlowByTuple(src_ip, src_port, dst_ip, dst_port, proto[,vlan])` | `table` | Finds and returns an active flow by its 5-tuple. |
| `interface.getFlowKey(src_ip, src_port, dst_ip, dst_port, proto[,vlan])` | `integer` | Computes the hash key for a flow 5-tuple. |
| `interface.findPidFlows(pid)` | `table` | Returns active flows associated with a specific process ID (eBPF). |
| `interface.findNameFlows(proc_name)` | `table` | Returns active flows associated with a process name (eBPF). |

### Flow manipulation

| Lua call | Returns | Description |
|---|---|---|
| `interface.dropFlowTraffic(key, hash_id)` | `nil` | Marks a specific flow for traffic dropping (nEdge inline mode). |
| `interface.dropMultipleFlowsTraffic(flows_table)` | `nil` | Drops traffic for multiple flows at once (nEdge inline mode). |
| `interface.processFlow(flow_table)` | `nil` | Injects a flow record from ZMQ/sFlow into the interface for processing (non-nEdge). |

### ZMQ flow fields

| Lua call | Returns | Description |
|---|---|---|
| `interface.getAllZMQFlowFieldDescr()` | `table` | Returns descriptions of all ZMQ flow template fields (non-nEdge). |
| `interface.getZMQFlowFieldDescr(field_id)` | `table` | Returns description of a specific ZMQ flow field (non-nEdge). |

---

## 8. MAC Address Information

| Lua call | Returns | Description |
|---|---|---|
| `interface.getActiveMacs([vlan_id])` | `table` | Returns currently active MAC addresses on the interface. |
| `interface.getMacsInfo([params])` | `table` | Returns detailed information for MAC addresses on the interface. |
| `interface.getBatchedMacsInfo(cursor, count)` | `table` | Returns a paginated batch of MAC address records. |
| `interface.isMacActive(mac)` | `boolean` | Returns `true` if the given MAC address is currently active. |
| `interface.getMacInfo(mac)` | `table` | Returns detailed information for a specific MAC address. |
| `interface.getMacHosts(mac)` | `table` | Returns all hosts associated with a given MAC address. |
| `interface.getMacManufacturers([params])` | `table` | Returns a grouped count of MAC addresses by their OUI manufacturer. |
| `interface.getMacDeviceTypes()` | `table` | Returns a mapping of MAC device type IDs to their names and counts. |
| `interface.isMulticastMac(mac)` | `boolean` | Returns `true` if the given MAC address is a multicast/broadcast address. |
| `interface.appendMacEvent(mac, event_type)` | `nil` | Appends a captive-portal event (login/logout) for a MAC address (nEdge). |
| `interface.findMacPool(mac)` | `integer` | Returns the host pool ID that a MAC address belongs to. |
| `interface.findMemberPool(host[,vlan])` | `integer` | Returns the host pool ID that a host belongs to. |
| `interface.resetMacStats(mac)` | `nil` | Resets all traffic statistics for a specific MAC address. |
| `interface.deleteMacData(mac)` | `nil` | Permanently deletes all stored data for a specific MAC address. |

---

## 9. nDPI Protocol & Category

### Protocol/category lookup

| Lua call | Returns | Description |
|---|---|---|
| `interface.getnDPIProtocols([category_id])` | `table` | Returns all nDPI protocol IDs and names, optionally filtered by category. |
| `interface.getnDPICategories()` | `table` | Returns all nDPI category IDs and their names. |
| `interface.getnDPIProtoName(proto_id)` | `string` | Returns the human-readable name for an nDPI protocol ID. |
| `interface.getnDPIFullProtoName(proto_id)` | `string` | Returns the full hierarchical name (e.g. `'HTTP.Facebook'`) for an nDPI protocol. |
| `interface.getnDPIProtoId(proto_name)` | `integer` | Returns the nDPI protocol ID for a given protocol name string. |
| `interface.getnDPICategoryId(category_name)` | `integer` | Returns the nDPI category ID for a given category name string. |
| `interface.getnDPICategoryName(category_id)` | `string` | Returns the human-readable name for an nDPI category ID. |
| `interface.getnDPIProtoBreed(proto_id)` | `string` | Returns the nDPI breed (e.g. `'Safe'`, `'Unsafe'`) for a protocol. |

### Protocol traffic statistics

| Lua call | Returns | Description |
|---|---|---|
| `interface.getnDPIFlowsCount()` | `table` | Returns per-protocol flow count statistics for this interface. |
| `interface.getnDPIStats([host,vlan])` | `table` | Returns per-protocol byte/flow statistics, optionally filtered to a specific host. |
| `interface.getnDPIHostStats(host, vlan)` | `table` | Returns per-protocol nDPI traffic statistics for a specific host. |

### nDPI data recording

| Lua call | Returns | Description |
|---|---|---|
| `interface.dumpnDPIProtocolId(host, vlan, proto_id)` | `nil` | Records a protocol observation for a host to the nDPI dump table. |
| `interface.dumpnDPICategoryId(host, vlan, cat_id)` | `nil` | Records a category observation for a host to the nDPI dump table. |

---

## 10. Alerts

### Alert store queries

| Lua call | Returns | Description |
|---|---|---|
| `interface.getAlerts(params_table)` | `table` | Returns alerts matching the given filter criteria. `params_table` supports `status` (`"engaged"`, `"past"`), `alert_type`, `alert_severity`, `entity`, `entity_val`, `page`, `perPage`, `order_by`. |
| `interface.getEngagedAlerts([params_table])` | `table` | Returns all currently engaged (active/unresolved) alerts for this interface. |
| `interface.alert_store_query(query[,limit_rows])` | `nil` | Executes a raw SQL query on the interface alert database and streams JSON to the HTTP response. |

### Alert lifecycle

| Lua call | Returns | Description |
|---|---|---|
| `interface.storeTriggeredAlert(alert_table)` | `nil` | Stores a triggered alert record in the interface alert database. |
| `interface.releaseTriggeredAlert(alert_id)` | `nil` | Marks a triggered alert as resolved/released. |
| `interface.triggerExternalAlert(alert_table)` | `nil` | Stores an externally generated alert into the interface alert store. |
| `interface.releaseExternalAlert(alert_id)` | `nil` | Marks an external alert as resolved/released. |
| `interface.releaseEngagedAlerts(script_key, subtype, alert_type)` | `nil` | Bulk-releases engaged alerts matching a script key and type. |
| `interface.triggerTrafficAlert(params_table)` | `nil` | Triggers a traffic-threshold alert with configurable severity and details. |

### Alert context (script helpers)

| Lua call | Returns | Description |
|---|---|---|
| `interface.getCachedAlertValue(key)` | `string` | Retrieves a cached alert context value by key for this interface. |
| `interface.setCachedAlertValue(key, value[, expiry])` | `nil` | Stores a cached alert context value for this interface. |
| `interface.checkContext(context_key)` | `nil` | Validates and initializes alert context for a script execution. |

---

## 11. SNMP & Flow Devices

| Lua call | Returns | Description |
|---|---|---|
| `interface.getSNMPStats()` | `table` | Returns SNMP-polled statistics for the current interface (Pro only). |
| `interface.getFlowDevices()` | `table` | Returns flow exporters (NetFlow/IPFIX probes) seen on this interface (Pro). |
| `interface.getFlowDeviceInfo(device_ip)` | `table` | Returns detailed information for a specific flow-exporting device (Pro). |
| `interface.getFlowDeviceInfoByIP(ip)` | `table` | Returns flow device information looked up by IP address (Pro). |

---

## 12. Host Pools & Quotas

| Lua call | Returns | Description |
|---|---|---|
| `interface.getHostPoolsInfo()` | `table` | Returns configuration and member counts for all host pools on this interface. |
| `interface.getHostPoolsStats()` | `table` | Returns traffic statistics for all host pools on this interface. |
| `interface.getHostPoolStats(pool_id)` | `table` | Returns traffic statistics for a specific host pool. |
| `interface.getHostUsedQuotasStats(host, vlan)` | `table` | Returns quota usage statistics for a specific host (nEdge Pro). |
| `interface.resetPoolsQuotas([pool_id])` | `nil` | Resets traffic quota counters for all or a specific host pool (nEdge Pro). |
| `interface.flushPoolDynamicBlacklist(pool_id)` | `nil` | Clears the dynamic blacklist for a host pool (nEdge Pro). |
| `interface.getPoolDynamicBlacklistStats(pool_id)` | `table` | Returns blacklist statistics for a host pool (nEdge Pro). |
| `interface.getPoolDynamicBlacklistMembers(pool_id)` | `table` | Returns the current dynamic blacklist members for a pool (nEdge Pro). |

---

## 13. Network / AS / VLAN / Country Statistics

### Networks

| Lua call | Returns | Description |
|---|---|---|
| `interface.getNetworksStats()` | `table` | Returns per-local-network traffic statistics. |
| `interface.getNetworkStats(network_id)` | `table` | Returns traffic statistics for a specific local network by ID. |

### Autonomous Systems

| Lua call | Returns | Description |
|---|---|---|
| `interface.getASesInfo([params])` | `table` | Returns statistics for all Autonomous Systems observed on this interface. |
| `interface.getASInfo(asn)` | `table` | Returns traffic statistics for a specific Autonomous System number. |
| `interface.aggregateASNFlows()` | `nil` | Triggers aggregation of flows by Autonomous System Number. |
| `interface.aggregateSiteFlows()` | `nil` | Triggers aggregation of flows by site/organization (Pro). |

### VLANs

| Lua call | Returns | Description |
|---|---|---|
| `interface.getVLANsList()` | `table` | Returns a list of VLAN IDs seen on this interface. |
| `interface.getVLANsInfo([params])` | `table` | Returns per-VLAN traffic statistics for this interface. |
| `interface.getVLANInfo(vlan_id)` | `table` | Returns traffic statistics for a specific VLAN. |

### Countries

| Lua call | Returns | Description |
|---|---|---|
| `interface.getCountriesInfo([params])` | `table` | Returns per-country traffic statistics observed on this interface. |
| `interface.getCountryInfo(country_code)` | `table` | Returns traffic statistics for a specific country on this interface. |
| `interface.convertCountryCode2U16(code)` | `integer` | Converts a 2-letter ISO country code string to a 16-bit integer. |
| `interface.convertCountryU162Code(n)` | `string` | Converts a 16-bit country integer back to its ISO country code string. |

### Observation Points

| Lua call | Returns | Description |
|---|---|---|
| `interface.getObsPointsInfo([params])` | `table` | Returns statistics for all observation points seen on this interface. |
| `interface.getObsPointInfo(obs_point_id)` | `table` | Returns statistics for a specific observation point. |
| `interface.prepareDeleteObsPoint(obs_point_id)` | `nil` | Marks an observation point for deletion (first step of two-step delete). |
| `interface.deleteObsPoint(obs_point_id)` | `nil` | Completes deletion of a previously prepared observation point. |

---

## 14. Service & Periodicity Maps

These functions are available in Pro/Enterprise editions with behavioral analysis enabled.

| Lua call | Returns | Description |
|---|---|---|
| `interface.isBehaviourAnalysisAvailable()` | `boolean` | Returns `true` if behavioral analysis (periodicity/service maps) is available. |
| `interface.periodicityMap([params])` | `table` | Returns the periodicity map data for hosts and protocols on this interface. |
| `interface.flushPeriodicityMap()` | `nil` | Clears all learned periodicity map data for this interface. |
| `interface.periodicityMapFilterList()` | `table` | Returns available filter options for the periodicity map view. |
| `interface.serviceMap([params])` | `table` | Returns the service map data (host-to-service relationships) for this interface. |
| `interface.flushServiceMap()` | `nil` | Clears all learned service map data for this interface. |
| `interface.serviceMapFilterList()` | `table` | Returns available filter options for the service map view. |
| `interface.serviceMapLearningStatus()` | `table` | Returns whether the service map is in learning or enforcement mode. |
| `interface.serviceMapSetStatus(key, status)` | `nil` | Sets the learning/active status for a single service map entry. |
| `interface.serviceMapSetMultipleStatus(entries_table)` | `nil` | Sets status for multiple service map entries in a single call. |

---

## 15. ACL Management

| Lua call | Returns | Description |
|---|---|---|
| `interface.insertIPACL(cidr, is_allow)` | `nil` | Inserts an IP CIDR rule into the interface ACL. Pass `true` for allow, `false` for block. |
| `interface.removeIPACL(cidr)` | `nil` | Removes an IP CIDR rule from the interface ACL. |
| `interface.insertMacACL(mac, is_allow)` | `nil` | Inserts a MAC address rule into the interface ACL. |
| `interface.removeMacACL(mac)` | `nil` | Removes a MAC address rule from the interface ACL. |
| `interface.getACLInfo()` | `table` | Returns the current IP and MAC ACL rules for this interface. |

---

## 16. Network Discovery (mDNS / ARP / Ping)

| Lua call | Returns | Description |
|---|---|---|
| `interface.discoverHosts(timeout_ms)` | `table` | Triggers active host discovery (ping sweep) on the interface. |
| `interface.arpScanHosts()` | `table` | Triggers ARP scan discovery of hosts on the interface. |
| `interface.mdnsQueueAnyQuery(service_type)` | `nil` | Queues an mDNS ANY query for a service type for background resolution. |
| `interface.mdnsQueueNameToResolve(name)` | `nil` | Queues an mDNS/Bonjour name resolution request. |
| `interface.mdnsReadQueuedResponses()` | `table` | Reads and returns pending mDNS resolution results. |

---

## 17. Live Capture & PCAP

| Lua call | Returns | Description |
|---|---|---|
| `interface.liveCapture(params_table)` | `table` | Starts a live packet capture session on the interface; returns session info. |
| `interface.stopLiveCapture(capture_id)` | `nil` | Stops a running live capture session by its ID. |
| `interface.dumpLiveCaptures()` | `table` | Returns a table listing active live-capture sessions on this interface. |
| `interface.captureToPcap(params_table)` | `nil` | Starts a PCAP file capture session with BPF filter and duration. |
| `interface.isCaptureRunning()` | `boolean` | Returns `true` if a PCAP file capture session is currently active. |
| `interface.stopRunningCapture()` | `nil` | Stops the currently running PCAP file capture session. |

---

## 18. RRD Queue

The RRD queue is used by periodic scripts to asynchronously persist time-series data.

| Lua call | Returns | Description |
|---|---|---|
| `interface.rrd_enqueue(rrd_path, value, step)` | `nil` | Enqueues an RRD update for background writing. |
| `interface.rrd_dequeue()` | `table` | Dequeues a pending RRD update task. |
| `interface.rrd_queue_length()` | `integer` | Returns the number of pending items in the RRD update queue. |
| `interface.appendInfluxDB(json_points)` | `nil` | Appends time-series data points to the InfluxDB write queue. |

---

## 19. ClickHouse

Available in Enterprise/Pro editions with ClickHouse integration enabled.

| Lua call | Returns | Description |
|---|---|---|
| `interface.clickhouseExecCSVQuery(sql)` | `nil` | Executes a ClickHouse SQL query and streams CSV results to the HTTP response. |
| `interface.clickhouseArchiveData()` | `nil` | Triggers archival of old interface data to ClickHouse storage. |
| `interface.execSQLWrite(sql)` | `nil` | Executes a SQL write statement on the ClickHouse interface database. |
| `interface.chTsEnqueue(json_data)` | `nil` | Enqueues a ClickHouse time-series data batch for async insertion. |
| `interface.chTsDequeue()` | `string` | Dequeues a pending ClickHouse time-series data batch. |
| `interface.chTsQueueLen()` | `integer` | Returns the number of pending ClickHouse time-series batches in the queue. |
| `interface.execInMemoryQuery(sql)` | `table` | Executes a SQL query against the in-memory flow/host tables. |
| `interface.execSQLQuery(sql)` | `table` | Executes a SQL query against the interface's local SQLite database. |

---

## 20. sFlow

| Lua call | Returns | Description |
|---|---|---|
| `interface.getSFlowDevices()` | `table` | Returns sFlow agent devices seen on this interface. |
| `interface.getSFlowDeviceInfo(agent_ip)` | `table` | Returns per-port statistics for a specific sFlow agent. |

---

## 21. eBPF / Containers

| Lua call | Returns | Description |
|---|---|---|
| `interface.getPodsStats()` | `table` | Returns statistics for Kubernetes pods observed on this interface (eBPF). |
| `interface.getContainersStats()` | `table` | Returns statistics for containers observed on this interface (eBPF). |
| `interface.reloadCompanions()` | `nil` | Reloads companion interface assignments from Redis configuration. |

---

## 22. nEdge / L7 Shaping & Policy

These functions are available only in nEdge (inline/bridge) deployments.

| Lua call | Returns | Description |
|---|---|---|
| `interface.reloadL7Rules(pool_id)` | `nil` | Reloads L7 (nDPI-based) shaping rules for a host pool. |
| `interface.reloadShapers()` | `nil` | Reloads traffic shaper configurations from Redis. |
| `interface.updateFlowsShapers()` | `nil` | Triggers an update of traffic shaper state for all active flows. |
| `interface.getPolicyChangeMarker()` | `integer` | Returns a monotonic counter incremented on each policy change. |
| `interface.getl7PolicyInfo(pool_id)` | `table` | Returns the L7 policy rules for a host pool. |
| `interface.addLanIPAddress(ip_cidr)` | `nil` | Adds an IP/CIDR to the LAN address list for nEdge routing decisions. |
| `interface.updateTrafficMirrored(enabled)` | `nil` | Updates the traffic-mirrored flag for the interface. |
| `interface.updateSmartRecording(enabled)` | `nil` | Updates the smart-recording setting for the interface. |
| `interface.updateDynIfaceTrafficPolicy(policy)` | `nil` | Updates the dynamic traffic policy for this interface. |
| `interface.updatePushFiltersSettings(params)` | `nil` | Updates push-filter settings (e.g. BPF rules) for the interface. |
| `interface.updateLbdIdentifier(use_mac)` | `nil` | Updates the local broadcast domain host identifier (IP vs MAC). |
| `interface.updateFlowsOnlyInterface(enabled)` | `nil` | Sets the flows-only flag (no host tracking) on the interface. |
| `interface.loadScalingFactorPrefs()` | `nil` | Reloads interface throughput scaling factor preferences from Redis. |
| `interface.reloadGwMacs()` | `nil` | Reloads the list of known gateway MAC addresses from Redis. |
| `interface.reloadDhcpRanges()` | `nil` | Reloads DHCP address ranges from Redis configuration. |

---

## 23. RADIUS Accounting (nEdge)

Used by captive portal integrations to send RADIUS accounting packets.

| Lua call | Returns | Description |
|---|---|---|
| `interface.radiusAccountingStart(params)` | `nil` | Sends a RADIUS Accounting-Start packet for a captive-portal session. |
| `interface.radiusAccountingStop(params)` | `nil` | Sends a RADIUS Accounting-Stop packet for a captive-portal session. |
| `interface.radiusAccountingUpdate(params)` | `nil` | Sends a RADIUS Accounting-Update (Interim-Update) for an active session. |

---

## 24. Miscellaneous

| Lua call | Returns | Description |
|---|---|---|
| `interface.updateSyslogProducers()` | `nil` | Reloads syslog producer configuration for this interface (non-nEdge). |
| `interface.updateIPReassignment(params_table)` | `nil` | Handles an IP address reassignment event (DHCP lease change). |
| `interface.updateRanking(ranking_table)` | `nil` | Updates the site/host ranking data for this interface (Pro). |
| `interface.swapHostnameIPCache()` | `nil` | Swaps the hostname-to-IP cache with a newly built version. |
| `interface.incSyslogStats(stat_name, n)` | `nil` | Increments a named syslog processing statistics counter. |

---

## Appendix: Complete Function Index

All 245 `interface.*` functions in alphabetical order:

`addDataToLocalHostAssets` · `addLanIPAddress` · `addMacsIpAddresses` ·
`aggregateASNFlows` · `aggregateSiteFlows` · `alert_store_query` ·
`appendInfluxDB` · `appendMacEvent` · `arpScanHosts` ·
`captureToPcap` · `checkContext` · `chTsDequeue` · `chTsEnqueue` · `chTsQueueLen` ·
`clickhouseArchiveData` · `clickhouseExecCSVQuery` · `convertCountryCode2U16` · `convertCountryU162Code` ·
`deleteHostData` · `deleteMacData` · `deleteObsPoint` · `discoverHosts` ·
`dropFlowTraffic` · `dropHostTraffic` · `dropMultipleFlowsTraffic` ·
`dumpLiveCaptures` · `dumpnDPICategoryId` · `dumpnDPIProtocolId` ·
`execInMemoryQuery` · `execSQLQuery` · `execSQLWrite` ·
`findFlowByKeyAndHashId` · `findFlowByTuple` · `findHost` · `findHostByMac` ·
`findMacPool` · `findMemberPool` · `findNameFlows` · `findPidFlows` ·
`flushPeriodicityMap` · `flushPoolDynamicBlacklist` · `flushServiceMap` ·
`getACLInfo` · `getASesInfo` · `getASInfo` ·
`getActiveMacs` · `getActiveFlowsStats` · `getAddressInfo` · `getAnomalies` ·
`getAlerts` · `getAllZMQFlowFieldDescr` · `getBatchedFlowsInfo` · `getBatchedHostsInfo` ·
`getBatchedLocalHostsInfo` · `getBatchedLocalHostsTs` · `getBatchedMacsInfo` ·
`getBatchedRemoteHostsInfo` · `getBroadcastDomainHostsInfo` · `getBroadcastMulticastHostsInfo` ·
`getContainersStats` · `getCountriesInfo` · `getCountryInfo` ·
`getEndpoint` · `getEngagedAlerts` · `getFirstInterfaceId` · `getFlowDeviceInfo` ·
`getFlowDeviceInfoByIP` · `getFlowDevices` · `getFlowKey` · `getFlowsInfo` ·
`getFlowsStats` · `getFlowsStatus` · `getGroupedFlows` · `getHashTablesStats` ·
`getHostAttributes` · `getHostCountry` · `getHostInfo` · `getHostMinInfo` ·
`getHostPoolStats` · `getHostPoolsInfo` · `getHostPoolsStats` · `getHostUsedQuotasStats` ·
`getHostsByPort` · `getHostsByService` · `getHostsPorts` · `getHostsInfo` ·
`getId` · `getIfMac` · `getIfNames` · `getInterfaceHosts` ·
`getLocalHostsInfo` · `getLocalHostsInfoNoTX` · `getLocalHostsInfoNoTXTCP` ·
`getLocalServerPorts` · `getLiveASNStats` · `getMacDeviceTypes` · `getMacHosts` ·
`getMacInfo` · `getMacManufacturers` · `getMacsInfo` · `getMasterInterfaceId` ·
`getMaxIfSpeed` · `getName` · `getNetworkStats` · `getNetworksStats` ·
`getNumFlows` · `getNumHosts` · `getNumLocalHosts` · `getNumLocalRxOnlyHosts` ·
`getObsPointInfo` · `getObsPointsInfo` · `getPeriodicActivitiesStats` ·
`getPolicyChangeMarker` · `getPoolDynamicBlacklistMembers` · `getPoolDynamicBlacklistStats` ·
`getPodsStats` · `getProtocolFlowsStats` · `getPublicHostsInfo` ·
`getQueuesStats` · `getRemoteHostsInfo` · `getRemoteHostsInfoNoTX` ·
`getRemoteHostsInfoNoTXTCP` · `getRxOnlyHostsList` · `getSFlowDeviceInfo` ·
`getSFlowDevices` · `getSNMPStats` · `getScore` · `getSecsToFirstData` ·
`getStats` · `getStatsUpdateFreq` · `getThroughput` ·
`getVLANFlowsStats` · `getVLANInfo` · `getVLANsList` · `getVLANsInfo` ·
`getZMQFlowFieldDescr` · `getl7PolicyInfo` ·
`getnDPICategories` · `getnDPICategoryId` · `getnDPICategoryName` ·
`getnDPIFlowsCount` · `getnDPIFullProtoName` · `getnDPIHostStats` ·
`getnDPIProtoBreed` · `getnDPIProtoId` · `getnDPIProtoName` ·
`getnDPIProtocols` · `getnDPIStats` ·
`hasEBPF` · `hasExternalAlerts` · `hasVLANs` ·
`insertIPACL` · `insertMacACL` · `isBehaviourAnalysisAvailable` ·
`isBridgeInterface` · `isCaptureRunning` · `isDatabaseViewInterface` ·
`isDiscoverableInterface` · `isHostActive` · `isIdle` · `isLoopback` ·
`isMacActive` · `isMulticastMac` · `isPacketInterface` ·
`isPcapDumpInterface` · `isRunning` · `isSubInterface` · `isSyslogInterface` ·
`isValidIfId` · `isView` · `isViewed` · `isZMQInterface` ·
`liveCapture` · `listHTTPhosts` · `loadScalingFactorPrefs` ·
`mdnsQueueAnyQuery` · `mdnsQueueNameToResolve` · `mdnsReadQueuedResponses` ·
`name2id` ·
`periodicityMap` · `periodicityMapFilterList` · `prepareDeleteObsPoint` ·
`processFlow` ·
`radiusAccountingStart` · `radiusAccountingStop` · `radiusAccountingUpdate` ·
`releaseEngagedAlerts` · `releaseExternalAlert` ·
`releaseTriggeredAlert` · `reloadCompanions` · `reloadDhcpRanges` ·
`reloadGwMacs` · `reloadHostPrefs` · `reloadL7Rules` · `reloadShapers` ·
`removeDataFromLocalHostAssets` · `removeIPACL` · `removeMacACL` ·
`resetBroadcastDomains` · `resetCounters` · `resetHostStats` ·
`resetHostTopSites` · `resetMacStats` · `resetPoolsQuotas` ·
`rrd_dequeue` · `rrd_enqueue` · `rrd_queue_length` ·
`select` · `serviceMap` · `serviceMapFilterList` · `serviceMapLearningStatus` ·
`serviceMapSetMultipleStatus` · `serviceMapSetStatus` ·
`setCachedAlertValue` · `setHostOperatingSystem` · `setHostResolvedName` ·
`setInterfaceIdleState` · `setPeriodicActivityProgress` ·
`stopLiveCapture` · `stopRunningCapture` · `storeTriggeredAlert` ·
`swapHostnameIPCache` ·
`triggerExternalAlert` · `triggerTrafficAlert` ·
`updateDirectionStats` · `updateDynIfaceTrafficPolicy` · `updateFlowsOnlyInterface` ·
`updateFlowsShapers` · `updateHostTrafficPolicy` · `updateIPReassignment` ·
`updateLbdIdentifier` · `updatePushFiltersSettings` · `updateRanking` ·
`updateSmartRecording` · `updateSyslogProducers` · `updateTopSites` ·
`updateTrafficMirrored` ·
`viewedBy`
