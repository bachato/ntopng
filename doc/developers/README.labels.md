# User-Defined Host Labels

This document describes the implementation of user-defined host labels.

---

## Overview

Host labels allow operators to tag individual hosts with one or more named labels
for filtering, classification, and display purposes.  Labels are stored as a
64-bit bitmap on each host; bits 0–31 are reserved for ntop-internal use, while
**bits 32–63 are user-customizable**.

---

## Architecture

The feature spans three layers: the C++ core, the Lua scripting layer, and the
Vue.js frontend.

```
┌────────────────────────────────────────────────────┐
│  Frontend (Vue)  page-host-config.vue              │
│  REST calls:  GET  /lua/rest/v2/get/host/config.lua│
│               POST /lua/rest/v2/set/host/config.lua│
│               GET  /lua/rest/v2/get/label/         │
│                        labels_list.lua             │
└───────────────────────┬────────────────────────────┘
                        │ HTTP / JSON
┌───────────────────────▼────────────────────────────┐
│  Lua layer                                         │
│  ntop.getHostLabels(ip)  →  bitmap (integer)       │
│  ntop.setHostLabels(ip, bitmap)                    │
└───────────────────────┬────────────────────────────┘
                        │ C-API
┌───────────────────────▼────────────────────────────┐
│  C++ core                                          │
│  Ntop::host_labels_tree  (AddressTree, in-memory)  │
│  Redis  ntopng.prefs.host_labels_bitmap.<ip>       │
│  Host::labels_bitmap  (per-host field)             │
└────────────────────────────────────────────────────┘
```

---

## Bitmap Layout

| Bits  | Owner             | Description                          |
|-------|-------------------|--------------------------------------|
| 0–31  | ntop (reserved)   | Internal / system-defined labels     |
| 32–63 | User-customizable | Operator-defined labels via the UI   |

The default label table (`label_badge_utils.lua`) initialises slots 32–63 with
placeholder entries (`Customizable_Label_<N>`).  Operators customise names and
colors through the Labels page in the GUI.

---

## C++ Layer

### `Ntop` (`include/Ntop.h`, `src/Ntop.cpp`)

| Symbol | Description |
|--------|-------------|
| `AddressTree host_labels_tree` | In-memory radix tree mapping IP → 64-bit bitmap. Shared across all interfaces; guarded by the `AddressTree` read-write lock. |
| `void loadHostLabels()` | Called once from `Ntop::start()`. Scans Redis for all keys matching `ntopng.prefs.host_labels_bitmap.*` and pre-populates `host_labels_tree`. |
| `u_int64_t getHostLabels(const char* ip_str)` | Looks up a bitmap by IP string. Returns `0` when the host is not found. |
| `u_int64_t getHostLabels(const IpAddress* ip)` | Overload for `IpAddress` objects (used during `Host::initialize()`). |
| `void setHostLabels(const char* ip_str, u_int64_t bitmap)` | Updates both the in-memory tree and Redis. Deletes the Redis key when `bitmap == 0`. |

**Redis key format** (defined in `include/ntop_defines.h`):

```
ntopng.prefs.host_labels_bitmap.<ip>   (full key for a specific host)
ntopng.prefs.host_labels_bitmap.       (prefix used for wildcard scan)
```

### `Host` (`include/Host.h`, `src/Host.cpp`)

| Symbol | Description |
|--------|-------------|
| `u_int64_t labels_bitmap` | Per-host field, initialised from `Ntop::getHostLabels(&ip)` inside `Host::initialize()`. Avoids a per-host Redis read at startup. |
| `u_int64_t getLabels() const` | Returns the current bitmap. |
| `void setLabels(u_int64_t bitmap)` | Updates the in-memory field and delegates to `Ntop::setHostLabels()` for persistence. |
| `void lua_get_labels(lua_State* vm)` | Pushes `"labels"` → bitmap into the Lua table built by `Host::lua()`. |

### `Flow` (`include/Flow.h`, `src/Flow.cpp`)

`Flow::getLabels()` ORs the bitmaps of the client and server hosts so that the
combined label set is available for flow-level filtering and display:

```cpp
u_int64_t Flow::getLabels() {
    u_int64_t bm = 0;
    if (cli) bm |= cli->getLabels();
    if (srv) bm |= srv->getLabels();
    return bm;
}
```

The combined bitmap is pushed under the keys `"labels"` (top-level flow table),
`"cli.labels"`, and `"srv.labels"` (per-endpoint info table).

### `AddressTree` (`src/AddressTree.cpp`)

`AddressTree::findAddress()` now takes a shared read-lock (`updateLock.rdlock`)
around the `ptree_match()` call so that concurrent reads of `host_labels_tree`
are safe.

---

## Lua Layer

### `ntop.*` C-API bindings (`src/LuaEngineNtop.cpp`)

Two new functions are registered in the `ntop` Lua namespace:

| Lua function | C handler | Signature |
|---|---|---|
| `ntop.getHostLabels(ip)` | `ntop_get_host_labels` | `(string) → integer` |
| `ntop.setHostLabels(ip, bitmap)` | `ntop_set_host_labels` | `(string, number) → nil` |

Both functions accept an optional `@vlan` suffix on the IP string (parsed by
`get_host_vlan_info`).

### `label_badge_utils.lua` (`scripts/lua/modules/label_badge_utils.lua`)

The default label table now covers bits **32–63** (previously 16–31).
Each entry carries `id`, `color`, `description`, `name`, and `reserved` fields.
`getLabels()` returns the configured (non-default) labels that should be shown in
the UI.

### REST endpoints

| Verb | Path | Change |
|------|------|--------|
| `GET`  | `/lua/rest/v2/get/host/config.lua`   | Adds `labels` field (bitmap integer) to the response. |
| `POST` | `/lua/rest/v2/set/host/config.lua`   | Reads `host_labels_bitmap` POST parameter and calls `ntop.setHostLabels()` when the caller is an administrator. |
| `GET`  | `/lua/rest/v2/get/host/active_list.lua` | Accepts optional `label` query parameter (bit index). Filters out hosts whose `labels` bitmap does not have that bit set. (TODO: move filtering to C++.) |
| `GET`  | `/lua/rest/v2/get/host/host_filters.lua` | Appends a `label` filter group built from the configured label list, enabling the active-hosts table to expose a label drop-down. |

### `http_lint.lua` (`scripts/lua/modules/http_lint.lua`)

Two new validated parameters:

| Parameter | Validator | Notes |
|-----------|-----------|-------|
| `label` | `validateNumber` | Bit index for the active-host filter |
| `host_labels_bitmap` | `validateNumber` | 64-bit bitmap submitted from the host-config page |

---

## Data Flow Summary

```
Startup
  Ntop::loadHostLabels()
    Redis scan "ntopng.prefs.host_labels_bitmap.*"
    → populate host_labels_tree (AddressTree)

Host creation
  Host::initialize()
    labels_bitmap = ntop->getHostLabels(&ip)   // radix-tree lookup, no Redis

User assigns labels via GUI
  POST /lua/rest/v2/set/host/config.lua  {host_labels_bitmap: "N"}
    ntop.setHostLabels(ip, N)              // Lua API
      Ntop::setHostLabels()
        host_labels_tree.addAddress()      // update in-memory tree
        redis->set("ntopng.prefs.host_labels_bitmap.<ip>", "N")  // persist
      for each interface:
        host->setLabels(N)                 // update active Host object

Host display / filtering
  Host::lua()  →  "labels" key in Lua table
  Flow::lua()  →  "labels", "cli.labels", "srv.labels" keys
  active_list.lua  →  client-side bit-test filter on "labels"
```

---

## Adding New Labels

1. Add an entry to the label table managed by `label_badge_utils.lua` choosing a
   bit index in the range **32–63**.
2. Assign a `name`, `color`, and optionally `description`.
3. The label will automatically appear in the host-config dropdown and the
   active-hosts filter without any further C++ changes.

To add a system/reserved label (bits 0–31), update the C++ code that sets those
bits on the `Host` object and document the bit index in `ntop_defines.h`.
