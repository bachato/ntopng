<template>
    <div class="m-2 mb-3 row">
        <div class="row">
            <Transition name="add-effect" mode="out-in">
                <div class="position-relative col-6">
                    <BootstrapTable id="bgp_client_info" :columns="stats_columns" :rows="stats_rows_client"
                        :print_html_column="(col) => print_stats_column(col)"
                        :print_html_row="(col, row) => print_stats_row(col, row)">
                    </BootstrapTable>
                </div>
            </Transition>
            <Transition name="add-effect" mode="out-in">
                <div class="position-relative col-6">
                    <BootstrapTable id="bgp_server_info" :columns="stats_columns" :rows="stats_rows_server"
                        :print_html_column="(col) => print_stats_column(col)"
                        :print_html_row="(col, row) => print_stats_row(col, row)">
                    </BootstrapTable>
                </div>
            </Transition>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";
import FormatterUtils from "../utilities/formatter-utils.js";
import { ntopng_url_manager, ntopng_utility } from "../services/context/ntopng_globals_services.js";

const props = defineProps({
    context: Object,
});

const _i18n = (t) => i18n(t);
const stats_rows_client = ref([]);
const stats_rows_server = ref([]);
const bgp_info_url = '/lua/pro/rest/v2/get/flow/bgp/general_stats.lua'
const stats_columns = ref([{
    name: _i18n("map_page.info"),
    id: "info"
}, {
    class: "text-center w-25",
    name: _i18n("value"),
    id: "num"
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
    debugger;
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
        return i18n('flow_details.' + row.name)
    } else {
        return FormatterUtils.getFormatter("full_number")(row[col.id] || 0);
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
