<template>
    <div class="button-group mb-2 d-flex align-items-center">
        <div class="dropdown me-2 d-flex"><span class="no-wrap d-flex align-items-center filters-label me-2"><b>{{
            _i18n("view_options")
                    }}: </b></span>
            <SelectSearch v-model:selected_option="active_sankey_type" :options="sankey_format_list"
                @select_option="changeCriteria">
            </SelectSearch>
        </div>
        <div v-if="props.context.isEnterpriseXL && props.context.hasClickHouseSupport"
            class="button-group d-flex align-items-center" :class="{ 'w-100': !toggle_slider, 'w-25': toggle_slider }">
            <div class="w-100 d-flex align-items-center button-group">
                <CustomSwitch v-model:value="toggle_slider" :change_label_side="true" :label="toggle_slider_label"
                    style="" class="me-1" icon="fa-calendar-days" :title="toggle_slider_label"
                    @change_value="saveSwitch">
                </CustomSwitch>
                <div class="w-100 position-relative">
                    <Transition name="add-effect" mode="out-in">
                        <DateTimeRangePicker v-if="!toggle_slider" class="dontprint" id="as-date-time-picker"
                            :round_time="true" :custom_time_interval_list="time_preset_list" min_time_interval_id="live"
                            :custom_change_select_time="changeTime" @epoch_change="setTimeInterval">
                        </DateTimeRangePicker>
                    </Transition>
                    <Transition name="add-effect" mode="out-in">
                        <DateSlider v-if="toggle_slider" id="as-date-slider" :min_epoch="first_date_epoch"
                            @epoch_change="setTimeInterval" style="width: 100%" />
                    </Transition>
                </div>
            </div>
        </div>
    </div>

    <div class="m-2 mb-3">
        <Transition name="add-effect" mode="out-in">
            <div class="position-relative">
                <div class="mb-4 d-flex flex-column" style="height: 60vh;">
                    <Loading :isLoading="loading"></Loading>
                    <Sankey ref="sankey_chart" :no_data_message="no_data_message" :sankey_data="sankey_data"
                        @node_click="onNodeClick" @autorefresh_toggle="onAutoRefreshToggle">
                    </Sankey>
                </div>
            </div>
        </Transition>
        <Transition name="add-effect" mode="out-in"
            v-if="props.context.isEnterpriseXL && props.context.hasClickHouseSupport">
            <div class="position-relative" :key="reRenderTable" style="min-height: 614px;">
                <TableWithConfig ref="table_exporter_as_stats" :table_id="table_id" :showLoading="true"
                    :f_map_columns="mapTableColumns" :f_sort_rows="columnsSorting"
                    :get_extra_params_obj="getExtraParameters">
                </TableWithConfig>
            </div>
        </Transition>
        <div class="card-footer">
            <NoteList :note_list="note_list"> </NoteList>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed } from "vue";
import { default as NoteList } from "./note-list.vue";
import { default as Loading } from "./loading.vue"
import { default as Sankey } from "./sankey.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as DateTimeRangePicker } from "./date-time-range-picker.vue";
import { default as DateSlider } from "./date-slider.vue";
import { default as dataUtils } from "../utilities/data-utils.js";
import { default as SelectSearch } from "./select-search.vue";
import { default as CustomSwitch } from "./custom-switch.vue";
import FormatterUtils from "../utilities/formatter-utils.js";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";

const props = defineProps({
    context: Object,
});

const _i18n = (t) => i18n(t);
const sankey_url = `${http_prefix}/lua/pro/rest/v2/get/exporters/exporter_as_sankey.lua`;
const sankey_chart = ref(null);
const sankey_data = ref({});
const loading = ref(true);
const no_data_message = _i18n("as_overview.no_data")
let intervalId = null;
const table_exporter_as_stats = ref(null);
const reRenderTable = ref(false);
const main_epoch_interval = ref(null);
const first_date_epoch = ref(props.context.first_date_epoch);
const active_sankey_type = ref({})
const toggle_slider = ref(false);
const toggle_slider_label = ref(_i18n("db_search.time_range"));
const time_preset_list = [
    { value: "live", label: i18n('live'), currently_active: true },
    { value: "2_hours", label: i18n('show_alerts.presets.2_hours'), currently_active: false },
    { value: "12_hours", label: i18n('show_alerts.presets.12_hours'), currently_active: false },
    { value: "day", label: i18n('show_alerts.presets.day'), currently_active: false },
    { value: "week", label: i18n('show_alerts.presets.week'), currently_active: false },
    { value: "month", label: i18n('show_alerts.presets.month'), currently_active: false },
    { value: "year", label: i18n('show_alerts.presets.year'), currently_active: false },
    { value: "custom", label: i18n('show_alerts.presets.custom'), currently_active: false, disabled: true, },
]
const sankey_format_list = [
    { key: "criteria_exporter_interface_view", value: 'traffic_with_ases', label: _i18n('exporter_interface_overview.as_view') },
];
const note_list = [
    _i18n("exporter_interface_overview.note_ingress_egress"),
];

/* ************************************** */

const table_id = computed(() => {
    return 'table_exporter_as_stats';
});

/* ************************************** */

onMounted(() => {
    updateSankeyData();
})

/* ************************************** */

onBeforeMount(() => {
    active_sankey_type.value = sankey_format_list[0];
    ntopng_url_manager.set_key_to_url("criteria_exporter_interface_view", active_sankey_type.value.value);
    toggle_slider.value = localStorage.getItem("exporter-as-overview-slider") == "true"
})

/* ************************************** */

const changeTime = (selectedTimeframe) => {
    let interval = 0; // Live
    if (selectedTimeframe !== 'live') {
        const timeframesDict = ntopng_utility.get_timeframes_dict();
        interval = timeframesDict[selectedTimeframe];
    }
    const epoch_end = ntopng_utility.get_utc_seconds(Date.now());
    const epoch_begin = epoch_end - interval;
    return [epoch_begin, epoch_end]
}

/* ************************************** */

/* This function is called upon changing the selected option in the dropdown */
const changeCriteria = async (opt) => {
    ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
    updateSankeyData();
}

/* ************************************** */

const onAutoRefreshToggle = (enabled) => {
    if (enabled) {
        intervalId = setInterval(() => {
            updateSankeyData()
        }, 10000 /* 10 sec refresh */)
    } else {
        clearInterval(intervalId);
    }
}

/* ************************************** */

function reloadTable() {
    table_exporter_as_stats.value.refresh_table()
}

/* ************************************** */

function setTimeInterval(epoch_interval) {
    // Check if it's live
    if (epoch_interval.isToday) {
        ntopng_url_manager.delete_key_from_url("type")
    } else {
        ntopng_url_manager.set_key_to_url("type", "historical")
    }

    if (epoch_interval.timeframe_id === 'live' || (epoch_interval.epoch_begin === epoch_interval.epoch_end)) {
        ntopng_url_manager.delete_key_from_url("type")
        ntopng_url_manager.delete_key_from_url("timeframe_id")
    }
    main_epoch_interval.value = epoch_interval;
    updateSankeyData();
    reloadTable()
}

/* ************************************** */

function saveSwitch() {
    localStorage.setItem("exporter-as-overview-slider", toggle_slider.value);
}

/* ************************************** */

const updateSankeyData = async () => {
    loading.value = true;
    const data = await getSankeyData();
    sankey_data.value = data;
    loading.value = false;
}

/* ************************************** */

const getSankeyData = async () => {
    const url_request = getSankeyUrl();
    let graph = await ntopng_utility.http_request(url_request);
    graph.nodes.forEach((node, i) => {
        node.index = i
    })
    graph.links.forEach((link, i) => {
        if (link.value === 0) {
            link.value = 1
        }
        let node = graph.nodes.find((el) => el.node_id == link.source_node_id)
        link.source = node.index;
        node = graph.nodes.find((el) => el.node_id == link.target_node_id)
        link.target = node.index;
    })

    return graph
}

/* ************************************** */

const getSankeyUrl = () => {
    let params = {
        ifid: props.context.ifid,
        ...getExtraParameters()
    }
    let url_params = ntopng_url_manager.obj_to_url_params(params);
    let url_request = `${sankey_url}?${url_params}`;
    return url_request;
}

/* ************************************** */

function onNodeClick(_, node) {
    if (node.link) {
        ntopng_url_manager.go_to_url(node.link)
    }
}

/* ***************************************************** */

const getExtraParameters = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    if (!props.context.isEnterpriseXL || !props.context.hasClickHouseSupport) {
        extra_params.epoch_begin = null
        extra_params.epoch_end = null
    }
    return extra_params;
};

/* ************************************** */

function columnsSorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "device") {
            return sortingFunctions.sortByName(r0.device.name, r1.device.name, col.sort);
        } else if (col.id == "interface") {
            return sortingFunctions.sortByName(r0.interface.name, r1.interface.name, col.sort);
        } else if (col.id == "customer") {
            return sortingFunctions.sortByName(r0.customer.name, r1.customer.name, col.sort);
        } else if (col.id == "as") {
            return sortingFunctions.sortByName(r0.as.name, r1.as.name, col.sort);
        } else if (col.id == "dst_as") {
            return sortingFunctions.sortByName(r0.dst_as.name, r1.dst_as.name, col.sort);
        } else if (col.id == "src_as") {
            return sortingFunctions.sortByName(r0.src_as.name, r1.src_as.name, col.sort);
        } else if (col.id == "src_transit_as") {
            return sortingFunctions.sortByName(r0.src_transit_as?.name || "", r1.src_transit_as?.name || "", col.sort);
        } else if (col.id == "dst_transit_as") {
            return sortingFunctions.sortByName(r0.dst_transit_as?.name || "", r1.dst_transit_as?.name || "", col.sort);
        } else if (col.id == "transit_as") {
            return sortingFunctions.sortByName(r0.transit_as?.name || "", r1.transit_as?.name || "", col.sort);
        } else if (col.id == "bytes_sent") {
            return sortingFunctions.sortByNumber(r0.bytes_sent, r1.bytes_sent, col.sort);
        } else if (col.id == "bytes_rcvd") {
            return sortingFunctions.sortByNumber(r0.bytes_rcvd, r1.bytes_rcvd, col.sort);
        } else if (col.id == "total_bytes") {
            return sortingFunctions.sortByNumber(r0.total_bytes, r1.total_bytes, col.sort);
        }
    }
    /* Default sorting */
    return sortingFunctions.sortByNumber(r0.total_bytes, r1.total_bytes, col.sort);
}

/* ************************************** */

const formatAS = (value) => {
    if (!value) {
        return ''
    }
    let addTitle = true;
    let importantASNIcon = ''
    const title = `data-bs-toggle="tooltip" data-bs-placement="top" title="${value.id}"`;
    if (value.is_customer_asn) {
        importantASNIcon = customerIcon;
    } else if (value.is_sub_customer_asn) {
        importantASNIcon = subCustomerIcon;
    } else if (value.is_remote_asn) {
        importantASNIcon = remoteIcon;
    }
    if (dataUtils.isEmptyString(value.name)) {
        addTitle = false
    }
    if (!dataUtils.isEmptyString(value.url)) {
        return `<a href="${value.url}" ${addTitle ? title : ""}>${value.name}</a> ${importantASNIcon}`;
    }
    return `<span ${addTitle ? title : ""}>${value.name}</span> ${importantASNIcon}`;
}

/* ************************************** */

const mapTableColumns = (columns) => {
    let map_columns = {
        "device": (value, row) => {
            if (dataUtils.isEmptyString(value.name)) {
                return value.id
            }
            if (!dataUtils.isEmptyString(value.url)) {
                return `<a href="${value.url}" title="${value.id}">${value.name}</a>`
            }
            return `<span data-bs-toggle="tooltip" data-bs-placement="top" title="${value.id}">${value.name}</span>`;
        },
        "interface": (value, row) => {
            if (dataUtils.isEmptyString(value.name)) {
                return value.id
            }
            if (!dataUtils.isEmptyString(value.url)) {
                return `<a href="${value.url}" title="${value.id}">${value.name}</a>`
            }
            return `<span data-bs-toggle="tooltip" data-bs-placement="top" title="${value.id}">${value.name}</span>`;
        },
        "as": (value, row) => {
            return formatAS(value);
        },
        "transit_as": (value, row) => {
            return formatAS(value);
        },
        "bytes_sent": (value, row) => {
            return FormatterUtils.getFormatter("bytes")(value || 0);
        },
        "bytes_rcvd": (value, row) => {
            return FormatterUtils.getFormatter("bytes")(value || 0);
        },
        "total_bytes": (value, row) => {
            if (value) {
                return FormatterUtils.getFormatter("bytes")(value);
            }

            if (row.bytes_rcvd || row.bytes_sent) {
                let bytes_sent = 0;
                let bytes_rcvd = 0;
                if (row.bytes_rcvd) { bytes_rcvd = row.bytes_rcvd }
                if (row.bytes_sent) { bytes_sent = row.bytes_sent }
                return FormatterUtils.getFormatter("bytes")(bytes_rcvd + bytes_sent);
            }

            return FormatterUtils.getFormatter("bytes")(0);
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
