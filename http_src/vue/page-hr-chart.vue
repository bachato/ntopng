<!-- (C) 2026 - ntop.org -->
<!-- 
     HR Chart page 
     Renders the page navbar and a tagify filter bar.
     RangePicker without the date picker Chart is rendered by graph_utils.drawNewGraphs() 
     When the filter tags change the page reloads so hr_chart.lua can pass the updated filter values to drawNewGraphs via the source_value_object.
-->
<template>
    <Navbar id="navbar" :main_title="context.navbar.main_title" :base_url="context.navbar.base_url"
        :help_link="context.navbar.help_link" :items_table="context.navbar.items_table">
    </Navbar>

    <div class="col-12 mb-2 mt-2 ms-1">
        <div class="range-picker d-flex m-auto flex-wrap">
            <AlertInfo id="alert_info" :global="true" ref="alert_info"></AlertInfo>
            <!-- Keep in sync allowed_filter_ids with flow_aggr in http_src/constants/metrics-consts.js -->
            <RangePicker v-if="mount_range_picker" ref="range_picker" id="range_picker" :show_date_picker="false">
                <template #filter_begin>
                    <select class="form-select w-auto flex-shrink-0" :value="group_by_value" @change="on_group_by_change">
                        <option value="">{{ _i18n("hr_chart.group_by_none") }}</option>
                        <option value="l7proto">{{ _i18n("hr_chart.group_by_l7proto") }}</option>
                        <option value="l7cat">{{ _i18n("hr_chart.group_by_l7cat") }}</option>
                        <option value="l4proto">{{ _i18n("hr_chart.group_by_l4proto") }}</option>
                        <option value="cli_asn">{{ _i18n("hr_chart.group_by_cli_asn") }}</option>
                        <option value="srv_asn">{{ _i18n("hr_chart.group_by_srv_asn") }}</option>
                    </select>
                </template>
            </RangePicker>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { ntopng_events_manager, ntopng_events, ntopng_url_manager, ntopng_sync } from "../services/context/ntopng_globals_services";

import { default as Navbar } from "./page-navbar.vue";
import { default as AlertInfo } from "./alert-info.vue";
import { default as RangePicker } from "./range-picker.vue";

const props = defineProps({ context: Object });
const _i18n = (t) => i18n(t);

const mount_range_picker = ref(false);
const group_by_value = ref("");

/* Clear PageStats params so PageStats.init() updates the ts_query with current URL state. */
function clear_page_stats_params() {
    ntopng_url_manager.delete_params([
        "timeseries_groups", "timeseries_groups_mode", "ts_query", "ts_schema"
    ]);
}

function on_group_by_change(event) {
    const val = event.target.value;
    if (val) {
        ntopng_url_manager.set_key_to_url("group_by", val);
    } else {
        ntopng_url_manager.delete_params(["group_by"]);
    }
    group_by_value.value = val;
    clear_page_stats_params();
    ntopng_url_manager.reload_url();
}

onBeforeMount(() => {
    const ifid = props.context?.ifid;
    if (ifid != null && !ntopng_url_manager.get_url_entry("ifid")) {
        ntopng_url_manager.set_key_to_url("ifid", String(ifid));
    }
    group_by_value.value = ntopng_url_manager.get_url_entry("group_by") || "";
});

onMounted(async () => {
    mount_range_picker.value = true;
    await ntopng_sync.on_ready("range_picker");

    /* Reload the page when filter tags change so hr_chart.lua can pass the updated values to drawNewGraphs.
     * Epoch-only changes are handled by the PageStats date picker without a reload. */
    /* Subscribe to FILTERS_CHANGE so we fire after RangePicker's reload_status has
     * already written the new filter values to the URL. */
    ntopng_events_manager.on_event_change("flow_aggr_filter", ntopng_events.FILTERS_CHANGE, () => {
        /* Clear PageStats-owned URL params so PageStats.init() calls
         * get_default_timeseries_groups() and getTsQuery() picks up the new
         * filter values via pass_url_filters. */
        clear_page_stats_params();
        ntopng_url_manager.reload_url();
    });
});
</script>
