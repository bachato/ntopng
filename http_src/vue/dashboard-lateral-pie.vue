<!--
  (C) 2013-22 - ntop.org
-->

<template>
    <div>
        <Chart ref="chart" :id="id" :chart_type="chart_type" :base_url_request="base_url"
            :get_custom_chart_options="get_chart_options" :register_on_status_change="false">
        </Chart>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, watch, computed } from "vue";
import { default as Chart } from "./chart.vue";
import dataUtils from "../utilities/data-utils";

const _i18n = (t) => i18n(t);

const chart_type = ref(ntopChartApex.typeChart.DONUT);
const chart = ref(null);
const url_list = ref(null);

const props = defineProps({
    id: String,          /* Component ID */
    i18n_title: String,  /* Title (i18n) */
    ifid: String,        /* Interface ID */
    epoch_begin: Number, /* Time interval begin */
    epoch_end: Number,   /* Time interval end */
    max_width: Number,   /* Component Width (4, 8, 12) */
    max_height: Number,  /* Component Hehght (4, 8, 12)*/
    params: Object,      /* Component-specific parameters from the JSON template definition */
    get_component_data: Function, /* Callback to request data (REST) */
    filters: Object
});

const base_url = computed(() => {
    return `${http_prefix}${props.params.url}`;
});

const get_url_params = () => {
    const url_params = {
        ifid: props.ifid,
        epoch_begin: props.epoch_begin,
        epoch_end: props.epoch_end,
        new_charts: true,
        ...props.params.url_params,
        ...props.filters
    }
    return url_params;
}

function get_chart_options() {
    const url = base_url.value;
    const url_params = get_url_params();
    const options = props.get_component_data(url, url_params, undefined, props.epoch_begin);
    Promise.resolve(options).then(response => {
        response.legend = {
            position: 'left',
            fontSize: '14px'
        }
        response.chart = {
            height: 300
        }
        response.responsive = [
            {
                breakpoint: 1800,
                options: {
                    chart: {
                        height: 200 // Reduce the height on small screens
                    },
                    legend: {
                        position: 'bottom'
                    }
                }
            }
        ]
        response.chart = {
            events: {
                dataPointSelection: function (event, chartContext, config) {
                    const selectedIndex = config.dataPointIndex;
                    if (!dataUtils.isEmptyString(url_list.value[selectedIndex])) {
                        window.location.href = url_list.value[selectedIndex];
                    }
                }
            }
        };
        url_list.value = response.urls;
    });
    return options;
}

/* Watch - detect changes on epoch_begin / epoch_end and refresh the component */
watch(() => [props.epoch_begin, props.epoch_end, props.filters], (cur_value, old_value) => {
    refresh_chart();
}, { flush: 'pre', deep: true });

onBeforeMount(() => {
    init();
});

onMounted(() => {
});

function init() {
    //refresh_chart();
}

async function refresh_chart() {
    chart.value.update_chart();
}
</script>

<style>
.apexcharts-legend-text {
    white-space: normal !important;
    overflow-wrap: break-word !important;
    max-width: 190px;
    display: block;
}
</style>