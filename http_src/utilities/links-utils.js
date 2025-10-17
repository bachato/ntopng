/*
  (C) 2013-23 - ntop.org
 */

/*
 * Here a list of functions used to retrieve URLs; in this way
 * only here needs to change the URL in case of changes 
 */

/* ***** IMPORTANT: http_prefix is not returned ***** */

/* Returns the URL of the exporters details */
const getExporterDetailsPageURL = (exporter_info) => {
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
    return `/lua/pro/enterprise/exporter_interfaces.lua?ip=${exporter_ip}&exporter_uuid=${exporter_uuid}&probe_uuid=${probe_uuid}&probe_ip=${probe_ip}`
}

/* ******************************************************************** */

/* Returns the URL of the exporter details */
const getExporterInterfaceDetailsPageURL = (exporter_info) => {
    const exporter_ip = exporter_info.ip
    let exporter_interface = ''
    
    if (exporter_info.interface) {
        exporter_interface = exporter_info.interface
    }

    return `/lua/pro/enterprise/flowdevice_interface_details.lua?ip=${exporter_ip}&snmp_port_idx=${exporter_interface}&ifid=${exporter_info.ifid}`
}

/* ******************************************************************** */

const linksUtils = function () {
    return {
        getExporterDetailsPageURL,
        getExporterInterfaceDetailsPageURL,
    };
}();

export default linksUtils;

