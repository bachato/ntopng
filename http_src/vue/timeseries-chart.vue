<!-- (C) 2026 - ntop.org -->
<template>
    <div class="mb-2" style="overflow-x: auto; white-space: nowrap;"> <!-- legend-wrapper -->
        <div class="d-flex align-items-center"> <!-- legend-div -->
            <div v-if="!$props.hide_stacked" class="form-check form-switch form-control-sm ms-1"
                data-bs-toggle="tooltip"
                :title="block_stacked ? _i18n('stacked_blocked_title') : _i18n('stacked_unblocked_title')">
                <input type="checkbox" class="form-check-input" @click="changeStacked" :checked="stacked"
                    :disabled="block_stacked">
                <label class="form-check-label">
                    {{ _i18n('stacked') }}
                </label>
            </div>
            <div class="ms-auto">
                <label class="form-check-label form-control-sm" v-for="(item, i) in timeseries_list">
                    <input type="checkbox" class="form-check-input align-middle mt-0"
                        @click="changeVisibility(!item.checked, i)" :checked="item.checked"
                        style="border-color: #0d6efd;" :style="{ backgroundColor: item.color }">
                    {{ item.name }}
                </label>
            </div>
        </div>
    </div>
    <div ref="graph_container" style="position: relative;">
        <template v-if="disable_fixed_height == true">
            <div class="mb-3 w-100" ref="chart_shown"></div>
            <div class="mb-3 w-100 d-none" ref="chart_hidden"></div>
        </template>
        <template v-else>
            <div class="mb-3 w-100" style="min-height:320px;" ref="chart_shown"></div>
            <div class="mb-3 w-100 d-none" style="min-height:320px;" ref="chart_hidden"></div>
        </template>
    </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from "vue";
import { ntopng_utility, ntopng_status_manager, ntopng_url_manager } from "../services/context/ntopng_globals_services";
import { Dygraph } from '../utilities/graph/dygraph';

const emit = defineEmits(["apply", "hidden", "showed", "chart_reloaded", "zoom"]);
const props = defineProps({
    id: String,
    chart_type: String,
    register_on_status_change: Boolean,
    base_url_request: String,
    get_params_url_request: Function,
    get_custom_chart_options: Function,
    disable_fixed_height: Boolean,
    hide_stacked: Boolean,
});

const chart = ref(null)
const graph_container = ref(null)
const chart_shown = ref(null)
const chart_hidden = ref(null)
const stacked = ref(null)
const block_stacked = ref(false)
const from_zoom = ref(false)
const timeseries_list = ref([])
const _i18n = (t) => i18n(t)

/* *************************************************** */

const get_url_request = function (status) {
    let url_params = '';
    if (props.get_params_url_request != null) {
        if (status == null) {
            status = ntopng_status_manager.get_status();
        }
        url_params = props.get_params_url_request(status);
    } else {
        url_params = ntopng_url_manager.get_url_params();
    }

    return `${props.base_url_request || ''}?${url_params}`;
}

/* *************************************************** */

const register_status = function (status) {
    let url_request = get_url_request(status);
    ntopng_status_manager.on_status_change(props.id, (new_status) => {
        if (from_zoom.value == true) {
            from_zoom.value = false;
        }
        const new_url_request = get_url_request(new_status);
        if (new_url_request === url_request) {
            url_request = new_url_request;
            return;
        }
        url_request = new_url_request;
        updateChart(new_url_request);
    }, false);
}

/* *************************************************** */

const init = function () {
    const status = ntopng_status_manager.get_status();
    const url_request = get_url_request(status);
    if (props.register_on_status_change) {
        register_status(status);
    }
    retrieveOptionsAndDraw(url_request);
}

/* *************************************************** */

const changeStacked = function () {
    stacked.value = !stacked.value;
    localStorage.setItem('ntopng.timeseries.chartStackedOption.' + props.id, stacked.value)
    updateIntoStackedChart(stacked.value);
}

/* *************************************************** */

const changeVisibility = function (visible, id) {
    if (timeseries_list.value[id] != null) {
        timeseries_list.value[id]["checked"] = visible
        chart.value.setVisibility(id, visible);
    }
}

/* *************************************************** */

const ensurePath = function (obj, path) {
    return path.reduce((acc, key) => (acc[key] ??= {}), obj);
}

/* *************************************************** */

const updateStackedOption = function (chart_options) {
    if (stacked.value === null && !chart_options.blockStacked) {
        // First loading of the chart
        const is_stacked_option_found = localStorage.getItem('ntopng.timeseries.chartStackedOption.' + props.id)
        if (is_stacked_option_found !== null) {
            stacked.value = (is_stacked_option_found == 'true');
            chart_options.stackedGraph = stacked.value;
        } else {
            stacked.value = chart_options.stackedGraph;
        }
    } else {
        if (chart_options.blockStacked)
            stacked.value = false;
        chart_options.stackedGraph = stacked.value;
    }
    return chart_options;
}

/* *************************************************** */

const getChartOptions = async function (url_request) {
    let chart_options = {};
    const date_format = await ntopng_utility.get_date_format(false, props.csrf, http_prefix);

    /* Retrieve the chart options */
    if (props.get_custom_chart_options == null) {
        chart_options = await ntopng_utility.http_request(url_request);
    } else {
        chart_options = await props.get_custom_chart_options(url_request);
    }
    if (!chart_options) {
        chart_options = {}
    }
    const xAxis = ensurePath(chart_options, ["axes", "x"]);
    /* Set the date depending on the server date */
    xAxis.axisLabelFormatter ??= function (date) {
        return ntopng_utility.from_utc_to_server_date_format(date, date_format);
    };
    xAxis.valueFormatter ??= function (date) {
        return ntopng_utility.from_utc_to_server_date_format(date, date_format);
    };
    /* Update the stacked option */
    chart_options = updateStackedOption(chart_options);
    /* Emit the chart_reloaded event */
    emit('chart_reloaded', chart_options);
    return chart_options;
}

/* *************************************************** */

const retrieveOptionsAndDraw = async function (url_request) {
    const chart_options = await getChartOptions(url_request);
    drawChart(chart_options)
}

/* *************************************************** */

const drawChart = async function (options, drawOnHidden) {
    const data = options.data || [];
    options.data = null;
    options.zoomCallback = onZoomed;
    if (options.blockStacked) {
        block_stacked.value = true
    }
    timeseries_list.value = [];
    let visibility = [];
    let id = 0;
    if (!options.disableTsList) {
        for (const key in options.series) {
            timeseries_list.value.push({ name: key, checked: true, id: id, color: options.colors[id] + "!important" });
            id = id + 1;
            visibility.push(true);
        }
    }
    chart.value = new Dygraph((drawOnHidden) ? chart_hidden.value : chart_shown.value, data, options);
}

/* *************************************************** */

const updateChart = async function (url_request) {
    if (chart.value) {
        const chart_options = await getChartOptions(url_request);
        chart.value.updateChart(chart_options);
    }
}

/* *************************************************** */

const updateIntoStackedChart = function (stacked) {
    if (chart.value) {
        chart.value.updateOptions({ 'stackedGraph': stacked });
    }
}

/* *************************************************** */
const getImage = function (image) {
    return Dygraph.Export.asPNG(chart.value, image, chart_shown.value);
}

/* *************************************************** */

const updateChartSeries = async function (options) {
    if (options == null || !chart.value) { return; }
    /* There is a possibility: that the timeseries number changes, for example, before there was the DNS, now there is not
        * for that reason we have to check if the timeseries options are the same or not
        */
    let recreateChart = false;
    for (const serie_name in options.series) {
        if (!timeseries_list.value.find((element) => { return (element.name === serie_name) })) {
            /* Element not found, the list is not the same */
            recreateChart = true;
            break
        }
    }
    timeseries_list.value.forEach((serie) => {
        if (!options.series[serie.name]) {
            recreateChart = true;
            return;
        }
    });
    if (recreateChart) {
        drawChart(options, true)
        await nextTick();
        /* Basically swap the 2 divs */
        chart_shown.value.classList.add('d-none');
        [chart_shown.value, chart_hidden.value] = [chart_hidden.value, chart_shown.value];
        chart_shown.value.classList.remove('d-none');
        chart.value.resize()
        chart_hidden.value.innerHTML = ""
    }
    chart.value.updateOptions({ 'file': options.data, 'colors': options.colors, 'labels': options.labels });
}

/* *************************************************** */

const onZoomed = function (minDate, maxDate) {
    from_zoom.value = true;
    const begin = moment(minDate);
    const end = moment(maxDate);
    // the timestamps are in milliseconds, convert them into seconds
    let new_epoch_status = { epoch_begin: Number.parseInt(begin.unix()), epoch_end: Number.parseInt(end.unix()) };
    ntopng_events_manager.emit_event(ntopng_events.EPOCH_CHANGE, new_epoch_status, props.id);
    emit('zoom', new_epoch_status);
}

/* *************************************************** */

/** This method is the first method called after html template creation. */
onMounted(async () => {
    await init();
    ntopng_sync.ready(props.id);
});

/* *************************************************** */

// expose methods for parent components
defineExpose({ updateChartSeries, getImage });

/* *************************************************** */
</script>

<style>
.dygraph-legend {
    color: var(--ntop-text-color);
    background-color: var(--timeseries-legend-bg-color) !important;
    border-color: var(--timeseries-legend-border-color);
    border-style: solid;
    border-width: thin;
/*  z-index: 80 !important;
    position: absolute; */
    box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, .15);
    border-radius: 0.375rem;
    width: auto;
    word-wrap: break-word;
    padding: 8px !important;
}

.dygraph-legend>span {
    color: #111111;
    padding-left: 5px;
    padding-right: 2px;
    margin-left: -5px;
    background-color: #FFFFFF !important;
}

.dygraph-legend>span:first-child {
    margin-top: 2px;
}

.dygraph-axis-label {
    z-index: 10;
    line-height: normal;
    overflow: hidden;
    color: var(--ntop-text-color);
}
</style>
