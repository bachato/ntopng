<template>
    <div class="m-2 mb-3 row">
        <div class="row">
            <Transition name="add-effect" mode="out-in">
                <div class="position-relative col-7 ">
                    <div class="card card-shadow">
                        <div class="card-body">
                            <NetworkMap ref="modbus_map" :empty_message="no_transitions_message" :height="'30vh'"
                                :page_csrf="props.context.csrf" :url="modbus_map_url" :url_params="getExtraParameters()"
                                :map_id="'modbus_transition_map'">
                            </NetworkMap>
                        </div>
                    </div>
                </div>
            </Transition>

            <Transition name="add-effect" mode="out-in">
                <div class="position-relative col-5">
                    <BootstrapTable id="modbus_bootstrap_table" :columns="stats_columns" :rows="stats_rows"
                        :print_html_column="(col) => print_stats_column(col)"
                        :print_html_row="(col, row) => print_stats_row(col, row)">
                    </BootstrapTable>
                </div>
            </Transition>
        </div>
        <div class="mt-2 row">
            <Transition name="add-effect" mode="out-in">
                <div class="position-relative col-6">
                    <TableWithConfig ref="table_modbus_function_codes" :table_id="'modbus_function_codes'"
                        :showLoading="true" :f_map_columns="mapTableColumns" :f_sort_rows="columnsSorting"
                        :get_extra_params_obj="getExtraParameters">
                        <template v-slot:custom_header>
                            <div class="dropdown me-3 d-inline-block">
                                <h4>{{ _i18n('flow_details.modbus_function_codes') }}</h4>
                            </div>
                        </template> <!-- Dropdown filters -->
                    </TableWithConfig>
                </div>
            </Transition>
            <Transition name="add-effect" mode="out-in">
                <div class="position-relative col-6">
                    <TableWithConfig ref="table_modbus_registers" :table_id="'modbus_registers'" :showLoading="true"
                        :f_map_columns="mapTableColumns" :f_sort_rows="columnsSorting"
                        :get_extra_params_obj="getExtraParameters">
                        <template v-slot:custom_header>
                            <div class="dropdown me-3 d-inline-block">
                                <h4>{{ _i18n('flow_details.modbus_registers') }}</h4>
                            </div>
                        </template> <!-- Dropdown filters -->
                    </TableWithConfig>
                </div>
            </Transition>
        </div>
        <div class="card-footer">
            <NoteList :note_list="note_list"> </NoteList>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed } from "vue";
import { default as NetworkMap } from "./network-map.vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";
import { default as NoteList } from "./note-list.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import FormatterUtils from "../utilities/formatter-utils.js";
import { ntopng_url_manager, ntopng_utility } from "../services/context/ntopng_globals_services.js";

const props = defineProps({
    context: Object,
});

const _i18n = (t) => i18n(t);
const table_modbus_registers = ref(null);
const table_modbus_function_codes = ref(null);
const stats_rows = ref([]);
const modbus_general_stats_url = '/lua/pro/rest/v2/get/flow/modbus/general_stats.lua'
const no_transitions_message = i18n('flow_details.modbus_no_transitions')
const modbus_map = ref(null)
const modbus_map_url = `${http_prefix}/lua/pro/rest/v2/get/flow/modbus/map.lua`
const stats_columns = ref([{
    name: _i18n("map_page.info"),
    id: "info"
}, {
    class: "text-center w-25",
    name: _i18n("value"),
    id: "num"
}
])
const note_list = [
    _i18n("flow_details.modbus_notes"),
    _i18n("flow_details.modbus_notes_map"),
];

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
    const stats = await ntopng_utility.http_request(`${http_prefix}${modbus_general_stats_url}?${params}`);
    stats_rows.value = stats
}

/* ************************************** */

onMounted(() => {
    refreshBSTable()
})

/* ************************************** */

onBeforeMount(() => { })

/* ************************************** */

function reloadTables() {
    table_modbus_registers.value.refresh_table()
    table_modbus_function_codes.value.refresh_table()
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
        if (col.id == "modbus_function_code") {
            return sortingFunctions.sortByName(r0.modbus_function_code, r1.modbus_function_code, col.sort);
        } else if (col.id == "modbus_register") {
            return sortingFunctions.sortByName(r0.modbus_register, r1.modbus_register, col.sort);
        } else if (col.id == "num_uses") {
            return sortingFunctions.sortByNumber(r0.num_uses, r1.num_uses, col.sort);
        }
    }
    /* Default sorting */
    return sortingFunctions.sortByNumber(r0.num_uses, r1.num_uses, col.sort);
}

/* ************************************** */

const mapTableColumns = (columns) => {
    let map_columns = {
        "modbus_function_code": (value) => {
            return value;
        },
        "modbus_register": (value) => {
            return value;
        },
        "num_uses": (value) => {
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
