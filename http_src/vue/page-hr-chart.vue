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

const mount_range_picker = ref(false);

/* Returns a string of all URL params except epoch, used to detect filter changes. */
function get_filter_url_params() {
    const params = new URLSearchParams(ntopng_url_manager.get_url_params());
    params.delete("epoch_begin");
    params.delete("epoch_end");
    return params.toString();
}

onBeforeMount(() => {
    const ifid = props.context?.ifid;
    if (ifid != null && !ntopng_url_manager.get_url_entry("ifid")) {
        ntopng_url_manager.set_key_to_url("ifid", String(ifid));
    }
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
        ntopng_url_manager.delete_params([
            "timeseries_groups", "timeseries_groups_mode", "ts_query", "ts_schema"
        ]);
        ntopng_url_manager.reload_url();
    });
});
</script>
