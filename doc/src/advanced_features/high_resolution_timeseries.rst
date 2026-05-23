.. _HighResolutionTimeseries:

High-Resolution Timeseries
##########################

Overview
--------

Standard flow records summarise all traffic for the lifetime of a connection into a pair of byte
and packet counters. This is sufficient for long-term trend analysis, but it hides short-lived
spikes and makes it impossible to plot throughput at sub-minute granularity.

High-Resolution (HR) timeseries solve this by recording byte counts in **15-second slots** for
every active flow. Each completed flow stored in ClickHouse therefore carries an embedded timeline
of its own throughput history, enabling charts at 15-second granularity without a separate
timeseries database.

.. note::

   High-Resolution timeseries require:

   - An **ntopng Enterprise M** (or better) license.
   - **ClickHouse** configured as the flow dump backend (``-F clickhouse``). See :ref:`ClickHouse`.
   - **nProbe** with HR counters support.

Data Flow
---------

.. code-block:: text

   Physical/virtual interface
          │
          ▼
      nProbe (live capture)
          │  exports @NTOPNG@ template
          │  + HR_SRC_TO_DST_BYTES (array of 15s byte buckets)
          │  + HR_DST_TO_SRC_BYTES (array of 15s byte buckets)
          │  via ZMQ
          ▼
      ntopng (ZMQ collector)
          │  auto-detects HR fields
          │  writes consolidated flow record
          ▼
      ClickHouse flows table
          HR_SRC2DST_BYTES  Array(UInt64)
          HR_DST2SRC_BYTES  Array(UInt64)
          │
          ▼
      Grafana dashboard
          per-flow bidirectional throughput at 15-second resolution

nProbe Configuration
--------------------

To enable HR timeseries, add the two HR information elements to the nProbe export template.
No other nProbe option is required:

.. code-block:: bash

   nprobe -i enp1s0 -n none --zmq "tcp://*:5556" -T "@NTOPNG@ %HR_DST_TO_SRC_BYTES %HR_SRC_TO_DST_BYTES"

ntopng Configuration
--------------------

No ntopng configuration change is required. ntopng **automatically detects** the presence of HR counters
in the incoming ZMQ flow records and writes consolidated data to the corresponding ClickHouse columns.

ntopng must be configured to use ClickHouse as the flow dump backend:

.. code-block:: bash

   ntopng -i "tcp://127.0.0.1:5556" -F clickhouse

See :ref:`ClickHouse` for full ClickHouse setup instructions.

ClickHouse Schema
-----------------

When HR data is present, ntopng stores it in additional columns of the ``flows`` table. Example:

.. list-table::
   :header-rows: 1
   :widths: 25 20 55

   * - Column
     - Type
     - Description
   * - ``HR_SRC2DST_BYTES``
     - ``Array(UInt64)``
     - 15-second delta byte counters, source-to-destination direction. Element *i* covers the
       interval ``[FIRST_SEEN + (i·15s), FIRST_SEEN + ((i+1)·15s))``.
   * - ``HR_DST2SRC_BYTES``
     - ``Array(UInt64)``
     - 15-second delta byte counters, destination-to-source direction.

Those columns are empty arrays (``[]``) for flows that were not captured by nProbe with HR
counters enabled. Existing deployments without HR support are therefore unaffected.

Sample ClickHouse query to read the per-slot throughput of a specific flow:

.. code-block:: sql

   SELECT
       FLOW_ID,
       arrayEnumerate(HR_SRC2DST_BYTES) AS slot,
       arrayElement(HR_SRC2DST_BYTES, slot) AS src2dst_bytes,
       arrayElement(HR_DST2SRC_BYTES, slot) AS dst2src_bytes
   FROM flows
   ARRAY JOIN HR_SRC2DST_BYTES
   WHERE FLOW_ID = <flow_id>
   ORDER BY slot;

Grafana Dashboard
-----------------

Sample Grafana dashboards are available at:

.. code-block:: text

   https://github.com/ntop/ntopng/tree/dev/httpdocs/misc/grafana

The **ntopng High-Resolution Charts** sample dashboard (hr-flow-throughput-dashboard.json)
is a simple example demonstrating how to use High-Resolution timeseries in Grafana.

The dashboard provides two panels:

- **Service Flow Throughput** — bidirectional throughput for a specific flow, filtered by
  source IP, destination IP, and destination port. Each data point represents one 15-second slot.
- **Application Protocol Throughput (All Traffic)** — aggregate throughput broken down by
  application protocol across all flows in the selected time window.

To import the dashboard into Grafana:

1. In Grafana, go to **Dashboards → Import**.
2. Upload ``hr-flow-throughput-dashboard.json`` or paste its contents.
3. When prompted, select the ClickHouse datasource that points to the ntopng database.

The dashboard requires the `Grafana ClickHouse plugin
<https://grafana.com/grafana/plugins/grafana-clickhouse-datasource/>`_. See
:ref:`GrafanaIntegration` for general Grafana integration instructions.

