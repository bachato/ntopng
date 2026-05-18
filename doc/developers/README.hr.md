# High-Resolution Flow Counters

## Overview

ntopng supports ingestion of **high-resolution (HR) byte counters** exported by nProbe.
Instead of a single cumulative byte count per flow update, nProbe can carry per-direction
traffic broken into **15-second slots**, giving ntopng sub-minute visibility into how
traffic was distributed within a flow's lifetime.

## Motivation

Standard NetFlow/IPFIX exports one cumulative byte counter per flow update.  When a
flow is active for several minutes the counter tells you the total transferred, but not
*when* the bytes crossed the wire.  For anomaly detection, capacity planning, and accurate
1-minute timeseries charts you need to know whether 10 MB arrived as a steady stream or
as a burst in the last five seconds of the minute.

HR counters solve this by letting nProbe encode a time-indexed byte vector:

```
HR_SRC_TO_DST_BYTES = "[1024, 512, 0, 8192]"   ← 4 slots × 15 s = 60 s of data
```

## Use Cases

| Use case | Benefit |
|---|---|
| 1-minute timeseries (InfluxDB / ClickHouse) | Each minute point reflects actual per-slot traffic, not just a divided total |
| Intra-minute burst detection | Algorithms can identify whether a spike occurred in slot 0 vs slot 3 |
| Traffic anomaly checks | Smoother baseline per 15-second slot instead of per minute |
| Forensic analysis | Reconstruct the shape of a flow's traffic over time |

## nProbe Configuration

nProbe must be configured to export the two custom Information Elements,
add them to the nProbe template:

```
-T="@NTOPNG@ %HR_SRC_TO_DST_BYTES %HR_DST_TO_SRC_BYTES"
```

Each IE is encoded as a variable-length string containing a JSON-like array of unsigned
64-bit integers, one per 15-second slot, in chronological order:

```
[<slot0_bytes>, <slot1_bytes>, ..., <slotN_bytes>]
```

## Data Flow Through ntopng

```
nProbe  ──ZMQ──►  ZMQParserInterface  ──►  ParsedFlow  ──►  Flow  ──►  timeseries / analytics
```

### Flow storage and merging

The `Flow` object holds two `std::vector<uint64_t>`:

```cpp
std::vector<uint64_t> hr_src2dst_bytes, hr_dst2src_bytes;
```

`mergeHRCounters()` handles the time-alignment problem that arises when a long-lived
flow receives multiple partial updates:

1. Both the flow's `base_first_seen` and the incoming update's `update_first_seen` are
   truncated to the minute boundary.
2. A **padding offset** is computed:
   ```
   padding = (update_minute - base_minute) / HR_COUNTERS_SLOT_DURATION_SECS
   ```
3. The destination vector is grown if needed and the incoming slots are written starting
   at `flow_counters[padding]`.

This ensures that slots from different flow updates are placed at the correct absolute
position regardless of when each update arrived.

## High-Resolution Timeseries Mode

HR counters are stored with raw flows in the ClickHouse backend. There is no need to
explicitly enable them in ntopng, as long as %HR_SRC_TO_DST_BYTES %HR_DST_TO_SRC_BYTES
are exported in nProbe.

