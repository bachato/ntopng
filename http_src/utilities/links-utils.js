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
    
    if (exporter_info.probe_uuid) {
        probe_uuid = exporter_info.probe_uuid
    }
    if (exporter_info.exporter_uuid) {
        exporter_uuid = exporter_info.exporter_uuid
    }
    return `/lua/pro/enterprise/exporter_details.lua?ip=${exporter_ip}&exporter_uuid=${exporter_uuid}&probe_uuid=${probe_uuid}`
}

/* ******************************************************************** */

const linksUtils = function () {
    return {
        getExporterDetailsPageURL,
    };
}();

export default linksUtils;

