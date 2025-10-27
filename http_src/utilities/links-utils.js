/*
  (C) 2013-23 - ntop.org
 */

/*
 * Here a list of functions used to retrieve URLs; in this way
 * only here needs to change the URL in case of changes 
 */

/* ***** IMPORTANT: http_prefix is not returned ***** */

/* Returns the URL of the exporters details */
const getExporterDetailsPageURL = (exporter_info, http_prefix) => {
    const exporter_ip = exporter_info.ip
    let probe_uuid = ''
    let exporter_uuid = ''
    let probe_ip = ''
    
    if (exporter_info.probe_uuid) {
        probe_uuid = exporter_info.probe_uuid
    }
    if (exporter_info.exporter_uuid) {
        exporter_uuid = exporter_info.exporter_uuid
    }
    if (exporter_info.probe_ip) {
        probe_ip = exporter_info.probe_ip
    }
    return `${http_prefix}/lua/pro/enterprise/exporter_interfaces.lua?ip=${exporter_ip}&exporter_uuid=${exporter_uuid}&probe_uuid=${probe_uuid}&probe_ip=${probe_ip}`
}

/* ******************************************************************** */

/* Returns the URL of the exporter details */
const getExporterInterfaceDetailsPageURL = (exporter_ip, interface_id, ifid, http_prefix) => {
    return `${http_prefix}/lua/pro/enterprise/flowdevice_interface_details.lua?ip=${exporter_ip}&snmp_port_idx=${interface_id}&ifid=${ifid}`
}

/* ******************************************************************** */

/* Returns the URL of the exporter details */
const getSNMPDetailsPageURL = (device_ip, http_prefix) => {
    return `${http_prefix}/lua/pro/enterprise/snmp_device_details.lua?host=${device_ip}`
}

/* ******************************************************************** */

/* Returns the URL of the exporter details */
const getSNMPInterfaceDetailsPageURL = (device_ip, interface_id, http_prefix) => {
    return `${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?&host=${device_ip}&snmp_port_idx=${interface_id}`
}

/* ******************************************************************** */

/* Returns the URL of the exporter details */
const getAggregatedFlowsURL = (filters, aggregation_criteria, http_prefix) => {
    let filters_string = ''
    for (const filter in filters) {
        filters_string = `${filters_string}${filter}=${filters[filter]}&`
    }
    return `${http_prefix}/lua/flows_stats.lua?page=analysis&aggregation_criteria=${aggregation_criteria}&${filters_string}`
}

/* ******************************************************************** */

/* Returns the URL of the exporter details */
const getFlowExporterInterfaceOverviewPageURL = (device_ip, interface_id, http_prefix) => {
    return `${http_prefix}/lua/pro/exporter_interface_overview.lua?deviceIP=${device_ip}&ifIdx=${interface_id}`
}

/* ******************************************************************** */

const linksUtils = function () {
    return {
        getExporterDetailsPageURL,
        getExporterInterfaceDetailsPageURL,
        getSNMPDetailsPageURL,
        getSNMPInterfaceDetailsPageURL,
        getAggregatedFlowsURL,
        getFlowExporterInterfaceOverviewPageURL
    };
}();

export default linksUtils;

