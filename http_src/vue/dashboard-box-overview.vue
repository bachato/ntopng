<!--
  (C) 2013-25 - ntop.org
-->

<template>
    <div class="d-flex align-items-center flex-wrap">
        <template v-for="(data, index) in box_data">
            <div class="text-center" :class="[data.text_color || '', data.text_width ? 'col-' + data.text_width : 'col-12']">
                <template v-if="data.add_separator_above">
                    <hr class="hr"/>
                </template>
                <h5 class="mb-1">{{ data.label }}</h5>
                <template v-if="data.num_elements != null">
                    <h5 class="mb-0">{{ data.num_elements }}</h5>
                </template>
                <template v-if="data.add_separator_below">
                    <hr class="hr"/>
                </template>
            </div>
        </template>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, watch } from "vue";
import { ntopng_custom_events, ntopng_events_manager } from "../services/context/ntopng_globals_services";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils";

const _i18n = (t) => i18n(t);

const counter = ref('')
const name = ref('')
const icon = ref('')
const link_url = ref('#')
const box_data = ref([]);

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
    set_component_attr: Function, /* Callback to set component attributes (e.g. Box active color) */
    filters: Object
});

/* Watch - detect changes on epoch_begin / epoch_end and refresh the component */
watch(() => [props.epoch_begin, props.epoch_end, props.filters], (cur_value, old_value) => {
    refresh_component();
}, { flush: 'pre', deep: true });

onBeforeMount(() => {
    init();
});

onMounted(() => {
});

function init() {
    if (props.params.i18n_name) {
        name.value = _i18n(props.params.i18n_name);
    }

    if (props.params.icon) {
        icon.value = props.params.icon + ' fa-2xl';
    }

    refresh_component();
}

async function refresh_component() {
    /* Refresh component */

    if (props.params.url) {

        const url_params = {
            ifid: props.ifid,
            epoch_begin: props.epoch_begin,
            epoch_end: props.epoch_end,
            ...props.params.url_params,
            ...props.filters
        }

        let data = await props.get_component_data(`${http_prefix}${props.params.url}`, url_params, undefined, props.epoch_begin);
        box_data.value = data
    }
}
</script>