<!-- (C) 2026 - ntop.org -->
<template>
    <div class="row justify-content-center">
        <div class="col-5"></div>
        <div class="col-sm-2 mt-4">
            <input ref="searchInput" name="search" type="text" class="form-control rounded-pill ps-4-5" autocomplete="off"
                autocorrect="off" :placeholder="_i18n('search_host')">
        </div>
        <div class="col-3"></div>
        <div class="col-2"></div>
        <div class="position-relative col-6 m-2">
            <!-- no data -->
            <NoData :show="no_data"></NoData>
            <BootstrapTable id="bgp_info" :columns="stats_columns" :rows="stats_rows" :hide_head="true"
                :wrap_columns="true" :print_html_column="(col) => print_stats_column(col)"
                :print_html_row="(col, row) => print_stats_row(col, row)">
            </BootstrapTable>
        </div>
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
const stats_rows = ref([]);
const no_data = ref(true);
const bgp_info_url = '/lua/rest/v2/get/flow/bgp/looking_glass.lua'
const searchInput = ref(null)
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

    if (stats.length > 0)
        no_data.value = false

    stats_rows.value = stats
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
            let formattedInfo = "<ul>"
            info.forEach((el) => {
                let singleElementInfo = ""
                if (el.url) {
                    singleElementInfo = `<li><a href='${el.url}'>${el.name}</a>`
                } else {
                    singleElementInfo = '<li>' + el.name
                }
                formattedInfo = `${formattedInfo}${singleElementInfo}<br>`
            })
            return formattedInfo + "</ul>"
        } else {
            return row[col.id];
        }
    }
}

/* ************************************** */

onMounted(() => { });

</script>
