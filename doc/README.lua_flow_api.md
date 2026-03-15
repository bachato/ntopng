# ntopng Lua API Reference (`flow.*` bindings)

This document describes all C→Lua bindings exposed as `flow.*` functions via
`src/LuaEngineFlow.cpp`.  It is intended both for human developers writing Lua
scripts and as a machine-readable reference for AI-assisted code generation (e.g.
Claude Code in this repository).

---

## Table of Contents

1. [How `flow.*` works](#1-how-flow-works)
2. [Usage context](#2-usage-context)
3. [Endpoints & Addresses](#3-endpoints--addresses)
4. [Traffic Counters](#4-traffic-counters)
5. [Protocol Classification](#5-protocol-classification)
6. [Flow Characteristics](#6-flow-characteristics)
7. [L7 Protocol Metadata](#7-l7-protocol-metadata)
8. [Alert Triggering](#8-alert-triggering)
9. [Complete Function Index](#9-complete-function-index)

---

## 1. How `flow.*` works

### Context

`flow.*` functions are available **only inside flow check scripts** — Lua scripts
that are invoked by the ntopng flow-processing engine for each active flow.
They operate on the **current flow** implicitly stored in the Lua VM context
(`NtopngLuaContext::flow`); no arguments are needed to identify the flow.

### C→Lua registration

Every function in `_ntop_flow_reg[]` (bottom of `src/LuaEngineFlow.cpp`) follows
this pattern:

```c
static int ntop_flow_get_xxx(lua_State* vm) {
    NtopngLuaContext* c = getLuaVMContext(vm);
    Flow* f = c ? c->flow : NULL;

    if (f)
        lua_push<type>(vm, f->get_xxx());
    else
        lua_pushnil(vm);

    return ntop_lua_return_value(vm, __FUNCTION__, CONST_LUA_OK);
}

// Registered as:
{ "xxx", ntop_flow_get_xxx },   // called as flow.xxx()
```

### Where flow check scripts live

Flow check scripts are stored in:

```
scripts/lua/modules/flow_checks/
```

Each script is a Lua module that exports a `check()` function called per-flow by
the engine.

---

## 2. Usage context

### Standard boilerplate for a flow check script

```lua
-- scripts/lua/modules/flow_checks/my_flow_check.lua
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local flow_consts = require("flow_consts")

local my_check = {}

-- Called once per active flow by the engine
function my_check.check(flow_info)
    local cli   = flow.cli()          -- client IP string
    local srv   = flow.srv()          -- server IP string
    local proto = flow.protocol()     -- L4 protocol number
    local bytes = flow.bytes()        -- total bytes

    if bytes > 1000000 then
        flow.triggerAlert(flow_consts.alert_types.flow_score, "Large flow detected")
    end
end

return my_check
```

### Important notes

- `flow.*` functions return `nil` if called outside a flow check context (i.e.
  when `NtopngLuaContext::flow` is `NULL`).
- All functions take **no arguments** (except `flow.triggerAlert`).
- `flow.*` is completely separate from `interface.*` — there is no need to call
  `interface.select()` inside flow check scripts.

---

## 3. Endpoints & Addresses

| Lua call | Returns | Description |
|---|---|---|
| `flow.cli()` | `string` | The client (connection initiator) IP address, e.g. `"192.168.1.10"` or `"2001:db8::1"`. Returns `nil` if the flow has no client IP. |
| `flow.cli_port()` | `integer` | The client TCP/UDP source port number. |
| `flow.srv()` | `string` | The server (connection responder) IP address. Returns `nil` if the flow has no server IP. |
| `flow.srv_port()` | `integer` | The server TCP/UDP destination port number. |
| `flow.vlan_id()` | `integer` | The VLAN ID associated with this flow. Returns `0` if the flow is not VLAN-tagged. |

---

## 4. Traffic Counters

| Lua call | Returns | Description |
|---|---|---|
| `flow.bytes()` | `integer` | Total bytes transferred in both directions (cli→srv + srv→cli). |
| `flow.cli2srv_bytes()` | `integer` | Bytes transferred from client to server only. |
| `flow.srv2cli_bytes()` | `integer` | Bytes transferred from server to client only. |

---

## 5. Protocol Classification

### L4 (transport) protocol

| Lua call | Returns | Description |
|---|---|---|
| `flow.protocol()` | `integer` | The L4 protocol number per IANA assignments. Common values: `6` (TCP), `17` (UDP), `1` (ICMP), `58` (ICMPv6), `132` (SCTP). |

### L7 (application) protocol — nDPI IDs

nDPI classifies flows hierarchically as `master_protocol.app_protocol`
(e.g. `HTTP.Facebook`). The two IDs are separate:

| Lua call | Returns | Description |
|---|---|---|
| `flow.l7_master_proto()` | `integer` | The nDPI **master** (encapsulating/transport) protocol ID — e.g. the HTTP protocol ID for `HTTP.Facebook`. Use `interface.getnDPIProtoName()` to convert to a string. |
| `flow.l7_proto()` | `integer` | The nDPI **application** protocol ID — e.g. the Facebook protocol ID for `HTTP.Facebook`. |
| `flow.l7_proto_name()` | `string` | The full human-readable nDPI protocol name string, e.g. `"HTTP.Facebook"` or `"TLS.Google"`. Combines master and app protocol. |

---

## 6. Flow Characteristics

| Lua call | Returns | Description |
|---|---|---|
| `flow.direction()` | `string` | The locality direction of this flow. One of: `"local@local"` (both endpoints are local), `"local@remote"` (client local, server remote), `"remote@local"` (client remote, server local), `"remote2remote"` (neither endpoint is local), or `"unknown"`. |
| `flow.is_oneway()` | `boolean` | `true` if only one direction of the flow has seen traffic (no reply packets observed). Useful for detecting port scans or half-open connections. |
| `flow.is_unicast()` | `boolean` | `true` if both the client and server IP addresses are unicast (not broadcast or multicast). |

---

## 7. L7 Protocol Metadata

These functions return dissected protocol-specific metadata tables.  The returned
table fields are populated only when nDPI has fully dissected the protocol for this
flow; fields may be `nil` if the flow is still being classified or if the protocol
does not apply.

### `flow.http()` — HTTP metadata

Returns a table with HTTP flow details. Common fields:

| Field | Type | Description |
|---|---|---|
| `method` | `string` | HTTP request method (`"GET"`, `"POST"`, etc.) |
| `url` | `string` | Full request URL |
| `content_type` | `string` | HTTP `Content-Type` header value |
| `return_code` | `integer` | HTTP response status code (e.g. `200`, `404`) |
| `server_name` | `string` | HTTP `Host` header value |

### `flow.dns()` — DNS metadata

Returns a table with DNS flow details. Common fields:

| Field | Type | Description |
|---|---|---|
| `last_query` | `string` | The queried domain name |
| `last_query_type` | `integer` | DNS query type code (e.g. `1`=A, `28`=AAAA, `5`=CNAME) |
| `last_return_code` | `integer` | DNS response code (0=NOERROR, 3=NXDOMAIN, etc.) |
| `replies_as_string` | `string` | Comma-separated list of reply IP addresses |
| `invalid_chars_in_query` | `boolean` | `true` if the query contains suspicious non-printable characters |

### `flow.ssh()` — SSH metadata

Returns a table with SSH flow details. Common fields:

| Field | Type | Description |
|---|---|---|
| `client_signature` | `string` | SSH client version string |
| `server_signature` | `string` | SSH server version string |
| `hassh_client` | `string` | HASSH fingerprint of the SSH client |
| `hassh_server` | `string` | HASSH fingerprint of the SSH server |

### `flow.tls_quic()` — TLS/QUIC metadata

Returns a table with TLS or QUIC flow details. Common fields:

| Field | Type | Description |
|---|---|---|
| `client_requested_server_name` | `string` | SNI (Server Name Indication) from the ClientHello |
| `server_names` | `string` | Certificate subject/SAN names from the server certificate |
| `issuerDN` | `string` | Certificate issuer distinguished name |
| `subjectDN` | `string` | Certificate subject distinguished name |
| `ja3_client` | `string` | JA3 TLS client fingerprint |
| `ja3_server` | `string` | JA3S TLS server fingerprint |
| `notBefore` | `integer` | Certificate validity start (Unix timestamp) |
| `notAfter` | `integer` | Certificate validity end (Unix timestamp) |
| `unsafe_cipher` | `boolean` | `true` if an unsafe/deprecated cipher suite was negotiated |

---

## 8. Alert Triggering

| Lua call | Returns | Description |
|---|---|---|
| `flow.triggerAlert(value, msg)` | `nil` | Triggers a custom alert on the current flow. `value` is a numeric severity/score value; `msg` is a descriptive string that will appear in the alert details. Has no effect if called outside a flow check context (when `flow` is `nil`). |

### Example

```lua
-- Detect large DNS responses (possible DNS tunneling)
local dns = flow.dns()
if dns and dns.last_return_code == 0 then
    local srv2cli = flow.srv2cli_bytes()
    if srv2cli > 512 then
        flow.triggerAlert(50, "Large DNS response: " .. tostring(srv2cli) .. " bytes")
    end
end
```

---

## 9. Complete Function Index

All 20 `flow.*` functions:

| Lua function | C implementation | Category |
|---|---|---|
| `flow.bytes()` | `ntop_flow_get_bytes` | Traffic |
| `flow.cli()` | `ntop_flow_get_client` | Endpoints |
| `flow.cli_port()` | `ntop_flow_get_client_port` | Endpoints |
| `flow.cli2srv_bytes()` | `ntop_flow_get_cli2srv_bytes` | Traffic |
| `flow.direction()` | `ntop_flow_get_direction` | Characteristics |
| `flow.dns()` | `ntop_flow_get_l7_proto_dns` | L7 metadata |
| `flow.http()` | `ntop_flow_get_l7_proto_http` | L7 metadata |
| `flow.is_oneway()` | `ntop_flow_is_oneway` | Characteristics |
| `flow.is_unicast()` | `ntop_flow_is_unicast` | Characteristics |
| `flow.l7_master_proto()` | `ntop_flow_get_l7_master_proto` | Protocol |
| `flow.l7_proto()` | `ntop_flow_get_l7_proto` | Protocol |
| `flow.l7_proto_name()` | `ntop_flow_get_l7_proto_name` | Protocol |
| `flow.protocol()` | `ntop_flow_get_protocol` | Protocol |
| `flow.ssh()` | `ntop_flow_get_l7_proto_ssh` | L7 metadata |
| `flow.srv()` | `ntop_flow_get_server` | Endpoints |
| `flow.srv_port()` | `ntop_flow_get_server_port` | Endpoints |
| `flow.srv2cli_bytes()` | `ntop_flow_get_srv2cli_bytes` | Traffic |
| `flow.tls_quic()` | `ntop_flow_get_l7_proto_tls_quic` | L7 metadata |
| `flow.triggerAlert(value, msg)` | `ntop_trigger_flow_alert` | Alerts |
| `flow.vlan_id()` | `ntop_flow_get_vlan_id` | Endpoints |
