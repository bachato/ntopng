<template>
    <div class="m-2 mb-3 row">
        <div class="row">
            <div class="col-6">
                <Transition name="add-effect" mode="out-in">
                    <div class="position-relative">
                        <div class="card card-shadow">
                            <div class="card-body">
                                <NetworkMap ref="profinet_map" :empty_message="no_transitions_message" :height="'30vh'"
                                    :page_csrf="props.context.csrf" :url="profinet_map_url"
                                    :url_params="getExtraParameters()" :map_id="'profinet_transition_map'">
                                </NetworkMap>
                            </div>
                        </div>
                    </div>
                </Transition>
            </div>
            <div class="col-6">
                <div class="row">
                    <div class="col-12 mb-3">
                        <Transition name="add-effect" mode="out-in">
                            <BootstrapTable id="profinet_general_info" :columns="stats_columns"
                                :rows="general_info_stats_rows" :print_html_column="(col) => print_stats_column(col)"
                                :print_html_row="(col, row) => print_stats_row(col, row)">
                            </BootstrapTable>
                        </Transition>
                    </div>
                    <div class="col-12">
                        <Transition name="add-effect" mode="out-in">
                            <BootstrapTable id="profinet_dce_rpc_operations" :columns="stats_columns"
                                :rows="dce_rpc_operations_stats_rows"
                                :print_html_column="(col) => print_stats_column(col)"
                                :print_html_row="(col, row) => print_stats_row(col, row)">
                            </BootstrapTable>
                        </Transition>
                    </div>
                </div>
            </div>
        </div>
        <div class="mt-2 row">
            <Transition name="add-effect" mode="out-in">
                <div class="position-relative col-6">
                    <TableWithConfig ref="table_profinet_function_codes" :table_id="'profinet_function_codes'"
                        :showLoading="true" :f_map_columns="mapTableColumns" :f_sort_rows="columnsSorting"
                        :get_extra_params_obj="getExtraParameters">
                        <template v-slot:custom_header>
                            <div class="dropdown me-3 d-inline-block">
                                <h4>{{ _i18n('flow_details.profinet_functions') }}</h4>
                            </div>
                        </template> <!-- Dropdown filters -->
                    </TableWithConfig>
                </div>
            </Transition>
            <Transition name="add-effect" mode="out-in">
                <div class="position-relative col-6">
                    <TableWithConfig ref="table_profinet_operations" :table_id="'profinet_operations'"
                        :showLoading="true" :f_map_columns="mapTableColumns" :f_sort_rows="columnsSorting"
                        :get_extra_params_obj="getExtraParameters">
                        <template v-slot:custom_header>
                            <div class="dropdown me-3 d-inline-block">
                                <h4>{{ _i18n('flow_details.profinet_operations') }}</h4>
                            </div>
                        </template> <!-- Dropdown filters -->
                    </TableWithConfig>
                </div>
            </Transition>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as NetworkMap } from "./network-map.vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import FormatterUtils from "../utilities/formatter-utils.js";
import { ntopng_url_manager, ntopng_utility } from "../services/context/ntopng_globals_services.js";

const props = defineProps({
    context: Object,
});

const _i18n = (t) => i18n(t);
const table_profinet_function_codes = ref(null);
const table_profinet_operations = ref(null);
const general_info_stats_rows = ref([]);
const no_transitions_message = i18n('flow_details.s7comm_no_transitions')
const dce_rpc_operations_stats_rows = ref([]);
const profinet_map = ref(null)
const profinet_map_url = `${http_prefix}/lua/pro/rest/v2/get/flow/profinet/map.lua`
const profinet_general_stats_url = '/lua/pro/rest/v2/get/flow/profinet/general_stats.lua'
const profinet_dce_rpc_stats_url = '/lua/pro/rest/v2/get/flow/profinet/dce_rpc_stats.lua'
const stats_columns = ref([{
    name: _i18n("map_page.info"),
    id: "info"
}, {
    class: "text-center w-50",
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
    let stats = await ntopng_utility.http_request(`${http_prefix}${profinet_general_stats_url}?${params}`);
    general_info_stats_rows.value = stats
    stats = await ntopng_utility.http_request(`${http_prefix}${profinet_dce_rpc_stats_url}?${params}`);
    dce_rpc_operations_stats_rows.value = stats
}

/* ************************************** */

onMounted(() => {
    refreshBSTable()
})

/* ************************************** */

onBeforeMount(() => { })

/* ************************************** */

function reloadTables() {
    table_profinet_function_codes.value.refresh_table()
    table_profinet_operations.value.refresh_table()
}

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

/* ************************************** */

function columnsSorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "profinet_function_code") {
            return sortingFunctions.sortByName(r0.profinet_function_code, r1.profinet_function_code, col.sort);
        } else if (col.id == "operation") {
            return sortingFunctions.sortByName(r0.operation, r1.operation, col.sort);
        } else if (col.id == "num_uses") {
            return sortingFunctions.sortByNumber(r0.num_uses, r1.num_uses, col.sort);
        } else if (col.id == "num_requests") {
            return sortingFunctions.sortByNumber(r0.num_requests, r1.num_requests, col.sort);
        } else if (col.id == "num_responses_errored") {
            return sortingFunctions.sortByNumber(r0.num_responses_errored, r1.num_responses_errored, col.sort);
        } else if (col.id == "num_responses_ok") {
            return sortingFunctions.sortByNumber(r0.num_responses_ok, r1.num_responses_ok, col.sort);
        }
    }
    /* Default sorting */
    return sortingFunctions.sortByNumber(r0.num_uses, r1.num_uses, col.sort);
}

/* ************************************** */

const mapTableColumns = (columns) => {
    let map_columns = {
        "profinet_function_code": (value) => {
            return value;
        },
        "num_uses": (value) => {
            return FormatterUtils.getFormatter("full_number")(value || 0);
        },
        "operation": (value) => {
            return value;
        },
        "num_requests": (value) => {
            return FormatterUtils.getFormatter("full_number")(value || 0);
        },
        "num_responses_errored": (value) => {
            return FormatterUtils.getFormatter("full_number")(value || 0);
        },
        "num_responses_ok": (value) => {
            return FormatterUtils.getFormatter("full_number")(value || 0);
        },
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
    });

    return columns;
};
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
