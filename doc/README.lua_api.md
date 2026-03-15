# ntopng Lua API — Master Reference

This document is the entry point for all ntopng C→Lua bindings documentation.
ntopng exposes five Lua namespaces, each defined in a dedicated C++ source file
and documented in its own reference file.

---

## Namespaces at a glance

| Namespace | Functions | Source file | Reference |
|---|---|---|---|
| `ntop.*` | 334 | `src/LuaEngineNtop.cpp` | [README.lua_ntop_api.md](README.lua_ntop_api.md) |
| `interface.*` | 245 | `src/LuaEngineInterface.cpp` | [README.lua_interface_api.md](README.lua_interface_api.md) |
| `flow.*` | 20 | `src/LuaEngineFlow.cpp` | [README.lua_flow_api.md](README.lua_flow_api.md) |
| `host.*` | 23 | `src/LuaEngineHost.cpp` | [README.lua_host_api.md](README.lua_host_api.md) |
| `network.*` | 9 | `src/LuaEngineNetwork.cpp` | [README.lua_network_api.md](README.lua_network_api.md) |

---

## When to use each namespace

### `ntop.*` — global system functions
Available everywhere.  Covers Redis/cache, preferences, user management, file
system, nDPI, alerts, time, geo/ASN lookups, ZMQ, and more.

```lua
local dirs = ntop.getDirs()
ntop.setCache("my_key", "value", 3600)
ntop.traceEvent(TRACE_INFO, "hello")
```

→ [Full reference](README.lua_ntop_api.md)

---

### `interface.*` — per-interface queries
Available everywhere.  **Requires `interface.select(ifid)` before use.**
Covers host/flow/MAC enumeration, nDPI stats, alerts, SNMP, host pools,
service/periodicity maps, ClickHouse, RRD, live capture, network discovery,
ACLs, nEdge shaping, and more.

```lua
interface.select(tostring(ifid))
local stats = interface.getStats()
local hosts = interface.getHostsInfo({ currentPage = 1, perPage = 10 })
```

→ [Full reference](README.lua_interface_api.md)

---

### `flow.*` — current-flow accessors
Available **only inside flow check scripts** (`scripts/lua/modules/flow_checks/`).
Operates on the implicit current flow.  Covers endpoints, traffic counters, L7
protocol IDs and names, and L7 metadata (HTTP, DNS, SSH, TLS/QUIC).

```lua
local cli   = flow.cli()          -- client IP
local proto = flow.l7_proto_name() -- e.g. "HTTP.Facebook"
local dns   = flow.dns()          -- DNS metadata table
flow.triggerAlert(50, "suspicious flow")
```

→ [Full reference](README.lua_flow_api.md)

---

### `host.*` — current-host accessors
Available **only inside host check scripts** (`scripts/lua/modules/host_checks/`).
Operates on the implicit current host.  Covers identity, address-type flags,
traffic counters, per-protocol stats, peer contact counters, and alert triggering.

```lua
if not host.is_local() then return end
local bytes = host.bytes()
local l7    = host.l7()          -- per-protocol breakdown
host.triggerAlert(80, "anomaly detected")
```

→ [Full reference](README.lua_host_api.md)

---

### `network.*` — current-network accessors
Available **only inside network check scripts** (`scripts/lua/modules/network_checks/`).
Requires `network.select(id)` or `network.checkContext(cidr)` before use.
Covers network statistics, alert lifecycle, and the alert context cache.

```lua
network.checkContext(network_info.network_cidr)
local stats = network.getNetworkStats()
network.setCachedAlertValue("prev_bytes", tostring(bytes), periodicity)
```

→ [Full reference](README.lua_network_api.md)

---

## Availability summary

| Namespace | REST endpoints | Periodic scripts | Flow checks | Host checks | Network checks |
|---|---|---|---|---|---|
| `ntop.*` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `interface.*` | ✓ (after select) | ✓ (after select) | ✓ | ✓ | ✓ |
| `flow.*` | — | — | ✓ | — | — |
| `host.*` | — | — | — | ✓ | — |
| `network.*` | ✓ (after select) | ✓ (after select) | — | — | ✓ |

---

## Standard boilerplate

```lua
-- All Lua scripts start with this
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json       = require("dkjson")
local rest_utils = require("rest_utils")   -- REST endpoints only

-- REST endpoints: select an interface
local ifid = _GET["ifid"] or interface.getFirstInterfaceId()
interface.select(tostring(ifid))
```

---

## Adding a new C→Lua binding

1. Write `static int ntop_my_function(lua_State* vm)` in the appropriate
   `src/LuaEngine*.cpp` file.
2. Add a `/* @brief ... Lua: namespace.FuncName(params) → return_type */`
   comment on the line immediately before the function.
3. Register it in the `_ntop_*_reg[]` table at the bottom of the file.
4. Update the corresponding `doc/README.lua_*_api.md`.

