<template>
    <div class="m-2 mb-3 row">
        <Transition name="add-effect" mode="out-in">
            <div class="position-relative col-sm-6">
                <!-- no data -->
                <h5>{{ _i18n('flow_details.bgp_client_info') }}</h5>
                <NoData :show="no_client_data"></NoData>
                <BootstrapTable id="bgp_client_info" :columns="stats_columns" :rows="stats_rows_client"
                    :hide_head="true" :wrap_columns="true" :print_html_column="(col) => print_stats_column(col)"
                    :print_html_row="(col, row) => print_stats_row(col, row)">
                </BootstrapTable>
            </div>
        </Transition>
        <Transition name="add-effect" mode="out-in">
            <div class="position-relative col-sm-6">
                <!-- no data -->
                <h5>{{ _i18n('flow_details.bgp_server_info') }}</h5>
                <NoData :show="no_server_data"></NoData>
                <BootstrapTable id="bgp_server_info" :columns="stats_columns" :rows="stats_rows_server"
                    :hide_head="true" :wrap_columns="true" :print_html_column="(col) => print_stats_column(col)"
                    :print_html_row="(col, row) => print_stats_row(col, row)">
                </BootstrapTable>
            </div>
        </Transition>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import NoData from './components/no-data.vue'
import { default as BootstrapTable } from "./bootstrap-table.vue";
import { ntopng_url_manager, ntopng_utility } from "../services/context/ntopng_globals_services.js";

const props = defineProps({
    context: Object,
});

const _i18n = (t) => i18n(t);
const stats_rows_client = ref([]);
const stats_rows_server = ref([]);
const no_client_data = ref(true);
const no_server_data = ref(true);
const bgp_info_url = '/lua/rest/v2/get/flow/bgp/general_stats.lua'
const stats_columns = ref([{
    class: "nowrap col-4",
    name: _i18n("map_page.info"),
    id: "info",
}, {
    name: _i18n("value"),
    id: "value"
}
])

/* ***************************************************** */

const getExtraParameters = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ***************************************************** */

const getExtraParametersUrl = () => {
    const extra_params = getExtraParameters()
    return ntopng_url_manager.obj_to_url_params(extra_params);
};

/* ************************************** */

const refreshBSTable = async () => {
    const params = getExtraParametersUrl()
    const stats = await ntopng_utility.http_request(`${http_prefix}${bgp_info_url}?${params}`);
    
    if (stats.client_info.length > 0)
        no_client_data.value = false
    if (stats.server_info.length > 0)
        no_server_data.value = false

    stats_rows_client.value = stats.client_info
    stats_rows_server.value = stats.server_info
}

/* ************************************** */

onMounted(() => {
    refreshBSTable()
})

/* ************************************** */

onBeforeMount(() => { })

/* ***************************************************** */

function print_stats_column(col) {
    return col.name;
}

/* ***************************************************** */

function print_stats_row(col, row) {
    if (row[col.id] == null) {
        return `<b>${i18n('flow_details.' + row.name)}</b>`
    } else {
        const info = row[col.id]
        if (typeof info === "object") {
            let formattedInfo = ""
            info.forEach((el) => {
                let singleElementInfo = ""
                if (el.url) {
                    singleElementInfo = `<a href='${el.url}'>${el.name}</a>`
                } else {
                    singleElementInfo = el.name
                }
                formattedInfo = `${formattedInfo}${singleElementInfo}<br>`
            })
            return formattedInfo
        } else {
            return row[col.id];
        }
    }
}
</script>

<style scoped>
.add-effect-move,
/* apply transition to moving elements */
.add-effect-enter-active,
.add-effect-leave-active {
    transition: all 0.35s ease;
}

/* Transform: positive pixels, the effects let enters the component
 * from the right, negative pixels from the left
 */
.add-effect-enter-from {
    opacity: 0;
    transform: translateX(-60px);
}

.add-effect-leave-to {
    opacity: 0;
    transform: translateX(0px);
}

/* ensure leaving items are taken out of layout flow so that moving
   animations can be calculated correctly. */
.add-effect-leave-active {
    position: absolute;
}

.slider-connect {
    background: none !important;
}
</style>
