<!--
  (C) 2013-25 - ntop.org
-->

<template>
    <div>
        <TimeseriesChart ref="chart" :id="id" :chart_type="chart_type" :base_url_request="base_url"
            :get_custom_chart_options="get_chart_options" :register_on_status_change="false"
            :disable_fixed_height="true" @chart-updated="chartUpdatedCallback" @update-requested="updateRequestedCallback">
        </TimeseriesChart>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, watch, computed } from "vue";
import metricsManager from "../utilities/metrics-manager.js";
import { default as TimeseriesChart } from "./timeseries-chart.vue";
import timeseriesUtils from "../utilities/timeseries-utils.js";

/* *************************************************** */
/* Constants and reactive variables */
/* *************************************************** */

const height_per_row = 62 /* px */  // Base height per row of the component
const chart_type = ref(ntopChartApex.typeChart.TS_LINE);  // Chart type (line chart)
const chart = ref(null);  // Reference to the child TimeseriesChart component
const timeseries_groups = ref([]);  // Timeseries groups to display
const group_option_mode = timeseriesUtils.getGroupOptionMode('1_chart_x_yaxis');  // Grouping mode for chart options
const height = ref(null);  // Calculated height of the component
const ts_request = ref([]);  // Timeseries requests to be processed
const multi_ts_requests = ref([]);  // Multiple timeseries requests for bulk operations
const ts_preferences = ref({})  // User preferences for timeseries display
const emit = defineEmits(['chart-updated', 'update-requested']);  // Events emitted to parent component

/* *************************************************** */
/* Component props */
/* *************************************************** */

const props = defineProps({
    id: String,          /* Unique component ID */
    i18n_title: String,  /* Title (i18n) for internationalization */
    ifid: String,        /* Interface ID */
    epoch_begin: Number, /* Time interval begin (Unix timestamp) */
    epoch_end: Number,   /* Time interval end (Unix timestamp) */
    max_width: Number,   /* Component Width (4, 8, 12) - grid system */
    max_height: Number,  /* Component Height (4, 8, 12) - grid system */
    params: Object,      /* Component-specific parameters from the JSON template definition */
    get_component_data: Function, /* Callback to request data from REST API */
    csrf: String,        /* CSRF token for security */
    filters: Object,     /* Additional filters for data query */
});

/* *************************************************** */
/* Callback methods */
/* *************************************************** */

const chartUpdatedCallback = (options) => {
    emit("chart-updated", options)
}

/* *************************************************** */

const updateRequestedCallback = (options) => {
    emit("update-requested", options)
}

/* *************************************************** */

/* Returns the base URL of the REST API */
const base_url = computed(() => {
    return `${http_prefix}${props.params.url}`;
});

/* *************************************************** */
/* Parameter substitution functions */
/* *************************************************** */

/* Substitutes $IFID$ placeholder with the actual interface ID in all parameters */
function substitute_ifid(params_to_format, current_ifid) {
    let new_formatted_params = {};
    for (const param in (params_to_format)) {
        if (params_to_format[param].contains('$IFID$')) {
            /* Contains $IFID$, substitute with the interface id */
            new_formatted_params[param] = params_to_format[param].replace('$IFID$', current_ifid);
        } else {
            /* Does NOT contain $IFID$, add the plain parameter */
            new_formatted_params[param] = params_to_format[param];
        }
    }

    return new_formatted_params;
}

/* *************************************************** */

/* Substitutes $EXPORTER$ placeholder with the actual exporter IP in all parameters */
function substitute_exporter(params_to_format, current_exporter) {
    let new_formatted_params = {};
    for (const param in (params_to_format)) {
        if (params_to_format[param].contains('$EXPORTER$')) {
            /* Contains $EXPORTER$, substitute with the exporter IP */
            new_formatted_params[param] = params_to_format[param].replace('$EXPORTER$', current_exporter);
        } else {
            /* Does NOT contain $EXPORTER$, add the plain parameter */
            new_formatted_params[param] = params_to_format[param];
        }
    }

    return new_formatted_params;
}

/* *************************************************** */

/* Substitutes $NETWORK$ placeholder with the actual network ID in all parameters */
function substitute_network(params_to_format, current_network) {
    let new_formatted_params = {};
    for (const param in (params_to_format)) {
        if (params_to_format[param].contains('$NETWORK$')) {
            /* Contains $NETWORK$, substitute with the network ID */
            new_formatted_params[param] = params_to_format[param].replace('$NETWORK$', current_network);
        } else {
            /* Does NOT contain $NETWORK$, add the plain parameter */
            new_formatted_params[param] = params_to_format[param];
        }
    }

    return new_formatted_params;
}

/* *************************************************** */
/* ANY parameter resolution functions */
/* *************************************************** */

/* Resolves $CURRENT_IFID$ parameter using the current interface ID from props */
async function format_current_ifid(params_to_format) {
    if (ts_request.value.length > 0) {
        /* Already populated, return early to avoid duplicate processing */
        return;
    }
    // The ifid is already available from the props, no request is needed
    let new_formatted_params = substitute_ifid(params_to_format, props.ifid);
    new_formatted_params.source_def = [props.ifid]  // Store source definition for later use
    ts_request.value.push(new_formatted_params);
}

/* *************************************************** */

/* Resolves $ANY_EXPORTER$ parameters by fetching all flow exporters and creating requests for each */
async function format_exporters(params_to_format) {
    if (ts_request.value.length > 0) {
        /* Already populated, return early to avoid duplicate processing */
        return;
    }

    const exporters_url = "lua/pro/rest/v2/get/flowdevices/stats.lua"
    const exporters_list = await ntopng_utility.http_request(`${http_prefix}/${exporters_url}?ifid=${props.ifid}&gui=true`) || [];
    if (exporters_list) {
        exporters_list.forEach((exporter) => {
            if (exporter) {
                let new_formatted_params = substitute_exporter(params_to_format, exporter.probe_ip);
                new_formatted_params = substitute_ifid(new_formatted_params, exporter.ifid);
                new_formatted_params.source_def = [exporter.ifid, exporter.probe_ip]  // Store source definition
                ts_request.value.push(new_formatted_params);
            }
        });
    }
}

/* *************************************************** */

/* Resolves $ANY_NETWORK$ parameters by fetching all networks and creating requests for each */
async function format_networks(params_to_format) {
    if (ts_request.value.length > 0) {
        /* Already populated, return early to avoid duplicate processing */
        return;
    }
    const networks_url = "lua/rest/v2/get/network/networks.lua"
    const networks_list = await ntopng_utility.http_request(`${http_prefix}/${networks_url}?ifid=${props.ifid}`) || [];
    if (networks_list) {
        networks_list.forEach((network) => {
            if (network) {
                let new_formatted_params = substitute_network(params_to_format, network.id);
                new_formatted_params = substitute_ifid(new_formatted_params, props.ifid);
                new_formatted_params.source_def = [props.ifid, network.id];  // Store source definition
                ts_request.value.push(new_formatted_params);
            }
        });
    }
}

/* *************************************************** */

/* Main function to resolve all ANY parameters in the configuration */
async function resolve_any_params() {
    /* Clear the Array */
    ts_request.value = [];
    /* Handle possible ANY parameters found in the post_params */
    const params = props.params.post_params?.ts_requests;
    for (const any_param in (params || {})) {
        switch (any_param) {
            case '$CURRENT_IFID$':
                await format_current_ifid(params[any_param]);
                break;
            case '$ANY_EXPORTER$':
                await format_exporters(params[any_param]);
                break;
            case '$ANY_NETWORK$':
                await format_networks(params[any_param]);
                break;
            default:
                // Handle regular parameters (no ANY substitution needed)
                let new_formatted_params = substitute_ifid(params[any_param], props.ifid);
                new_formatted_params.source_def = [props.ifid];
                ts_request.value.push(new_formatted_params);
                break;
        }
    }
}

/* *************************************************** */
/* Timeseries group retrieval functions */
/* *************************************************** */

/* Retrieves timeseries groups from a metric schema and source definition */
async function get_timeseries_groups_from_metric(metric_schema, source_def) {
    const status = {
        epoch_begin: props.epoch_begin,
        epoch_end: props.epoch_end,
    };
    const source_type = metricsManager.get_source_type_from_id(props.params?.source_type);
    const source_array = await metricsManager.get_source_array_from_value_array(http_prefix, source_type, source_def);
    const metric = await metricsManager.get_metric_from_schema(http_prefix, source_type, source_array, metric_schema, null, status, true /* Include empty TS */);
    const ts_group = metricsManager.get_ts_group(source_type, source_array, metric, { past: false });
    return ts_group;
}

/* *************************************************** */

/* Retrieves basic information for timeseries requests, applying user preferences */
async function retrieve_basic_info(request) {
    /* Return the timeseries groups, info found in the JSON */
    if (timeseries_groups.value.length == 0) {
        for (const value of request) {
            let metric_schema = value?.ts_schema;
            // Apply high resolution preference for flow exporters if enabled
            if (metric_schema === "top:flowdev_port:traffic" && ts_preferences.value.highResolutionFlowExportersTimeseries) {
                metric_schema = metric_schema + "_min"
            }
            const source_def = value.source_def;
            const group = await get_timeseries_groups_from_metric(metric_schema, source_def);
            timeseries_groups.value.push(group);
        }
    }
}

/* *************************************************** */

/* Removes temporary properties that shouldn't be sent to the REST API */
function remove_extra_params() {
    for (const value of ts_request.value) {
        if (value.source_def) {
            delete value.source_def
        }
    }
}

/* *************************************************** */
/* Chart options and data fetching */
/* *************************************************** */

/* Main function that fetches data from REST API and formats it for the chart */
async function get_chart_options() {
    emit('beforeUpdate');  // Notify parent that update is starting
    
    // Initialize Tops - this ensures only one request when opening the chart
    await init();
    
    const post_params = {
        csrf: props.csrf,
        epoch_begin: props.epoch_begin,
        epoch_end: props.epoch_end,
        ...props.params.post_params,
        ...{
            ts_requests: ts_request.value
        }
    }
    
    // Use multi timeseries requests for bulk operations
    post_params.ts_requests = multi_ts_requests.value;
    
    const data_url = `${http_prefix}/lua/pro/rest/v2/get/timeseries/ts_multi.lua`;
    props.get_component_data()  // Callback for component data (note: missing await?)
    let result = await ntopng_utility.http_post_request(data_url, post_params);
    
    /* Format the result for Dygraph chart compatibility */
    result = timeseriesUtils.tsArrayToOptionsArray(result, timeseries_groups.value, group_option_mode, '');
    if (result[0]) {
        result[0].height = height.value;
    }
    
    emit('afterUpdate');  // Notify parent that update is complete
    return result?.[0];
}

/* *************************************************** */
/* Lifecycle hooks */
/* *************************************************** */

/* Initialize component before mounting */
onBeforeMount(async () => {
    // Initialize the height of the chart
    height.value = (props.max_height || 4) * height_per_row;
    
    // Fetch user preferences for timeseries display
    const preferences_url = `${http_prefix}/lua/rest/v2/get/timeseries/preferences.lua`;
    const preferences = await ntopng_utility.http_request(`${preferences_url}`);
    if (preferences) {
        ts_preferences.value = preferences
    } 
});

/* *************************************************** */

onMounted(async () => { });  // Mounted hook (currently empty)

/* *************************************************** */
/* Initialization and helper functions */
/* *************************************************** */

/* Initializes component by resolving parameters and fetching top information */
async function init() {
    await resolve_any_params();  // Resolve ANY placeholders in parameters
    remove_extra_params();  // Clean up temporary properties
    await getTopInfo();  // Fetch top N information
}

/* *************************************************** */

/* Watches for changes on epoch_begin/epoch_end/filters and refreshes the chart accordingly */
watch(() => [props.epoch_begin, props.epoch_end, props.filters], (cur_value, old_value) => {
    refreshChart();
}, { flush: 'pre', deep: true });

/* *************************************************** */

/* Fetches top N data and constructs multi-timeseries requests */
async function getTopInfo() {
    // This request is done only the first time to avoid redundant API calls
    if (multi_ts_requests.value.length > 0) {
        return;
    }
    
    // Format the GET request for top data
    const url = base_url.value;
    const ts_source = []
    const query_params = {
        ...props.params.url_params,
        ...{}
    };
    query_params.csrf = props.csrf
    query_params.ifid = props.ifid
    query_params.epoch_begin = props.epoch_begin
    query_params.epoch_end = props.epoch_end
    
    const url_params = ntopng_url_manager.obj_to_url_params(query_params);
    const top_url = `${http_prefix}${url}?${url_params}`;
    const top_data = await ntopng_utility.http_request(top_url)
    
    // Retrieve the top data and update the ts_requests used by ts_multi.lua
    let ts_query = {}
    
    // Configure query based on schema type
    if (ts_request.value[0].ts_schema === "top:flowdev_port:traffic") {
        let ts_schema = `flowdev_port:traffic`
        if (ts_preferences.value.highResolutionFlowExportersTimeseries) {
            ts_schema = `flowdev_port:traffic_min`  // Use high resolution if preferred
        }
        ts_query = {
            ts_query: `ifid:$IFID$,device:$DEVICE$,port:$PORT$`,
            ts_schema: ts_schema,
        }
    } else if (ts_request.value[0].ts_schema === "top:asn:traffic") {
        ts_query = {
            ts_query: `ifid:$IFID$,asn:$ASN$`,
            ts_schema: `asn:traffic`,
        }
    }
    
    // Process each top data item and create corresponding timeseries queries
    top_data?.forEach((el, i) => {
        const tmp_query = { ...ts_query };
        
        // Substitute the parameters based on schema type
        if (ts_request.value[0].ts_schema === "top:flowdev_port:traffic") {
            tmp_query.ts_query = tmp_query.ts_query.replace('$IFID$', el.ifid);
            tmp_query.ts_query = tmp_query.ts_query.replace('$DEVICE$', el.exporter_ip);
            tmp_query.ts_query = tmp_query.ts_query.replace('$PORT$', el.interface_id);
            tmp_query.tskey = `${el.interface_id}`;  // Use interface ID as key
        } else if (ts_request.value[0].ts_schema === "top:asn:traffic") {
            tmp_query.ts_query = tmp_query.ts_query.replace('$IFID$', props.ifid);
            tmp_query.ts_query = tmp_query.ts_query.replace('$ASN$', el.asn);
            tmp_query.tskey = `${el.asn}`;  // Use ASN as key
        }
        
        // Add source for the first item (interface-level data)
        if (i == 0) {
            const val = ts_request.value.find((source) =>
                source.ts_query === `ifid:${props.ifid}`
            )
            val.source_def = [props.ifid];
            ts_source.push(val);
        }
        
        tmp_query.ts_unify = true  // Mark for unification in multi-request
        multi_ts_requests.value.push(tmp_query);
    })
    
    // Retrieve basic info for the timeseries sources
    await retrieve_basic_info(ts_source);
}

/* *************************************************** */

/* Refreshes chart data and updates the display */
async function refreshChart() {
    if (chart.value) {
        const result = await get_chart_options();
        chart.value.updateChartSeries(result);
    }
}

/* Expose refreshChart method to parent components */
defineExpose({ refreshChart });

</script>