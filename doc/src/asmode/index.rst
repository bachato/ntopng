ASN and BGP Flow Monitoring
###########################

.. note::
  In order to use the features and methods described in this section, for best results you need to collect flows from a network device rather than capturing packets that do not include contextual information (e.g. network interface index or exporter IP).

Network administrators managing ISP and IXP networks face the critical challenge of maintaining visibility over massive, dynamic traffic flows while controlling peering and transit costs. The main issues include:

- Traffic Blind Spots: High-volume, distributed traffic makes continuous packet capture impossible, requiring complex flow-sampling techniques (like NetFlow or sFlow) to identify traffic origins and destinations.
- BGP Routing Instability: Route flapping, prefix hijacking, and configuration errors can cause sudden traffic shifts, leading to network congestion or service outages.
- Complex Cost Optimization: Network admins must constantly analyze traffic destinations to balance expensive transit providers against cost-effective Internet Exchange Point (IXP) peering links.
- Data Scale and Analytics: Collecting, correlating, and analyzing massive amounts of BGP routing tables and flow data in real-time requires significant computational infrastructure and specialized tools.

.. toctree::
    :maxdepth: 2
    :numbered:

    configuration
    asmode
    
