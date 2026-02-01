<template>
    <div class="row">
        <div class="card card-shadow">
            <div class="card-body">
                <Transition name="add-effect" mode="out-in">
                    <div class="position-relative mb-5">
                        <Sankey v-if="show_sankey" ref="sankey_chart" :no_data_message="no_data_message"
                            :sankey_data="sankey_data" @node_click="onNodeClick"
                            @autorefresh_toggle="onAutoRefreshToggle">
                        </Sankey>
                    </div>
                </Transition>
                <Transition name="add-effect" mode="out-in">
                    <div class="position-relative">
                        <NetworkMap ref="network_map_test" :empty_message="no_data_message"
                            :page_csrf="props.context.csrf" :url="network_map_test_url"
                            :url_params="getExtraParameters()" :map_id="'network_map_test'">
                        </NetworkMap>
                    </div>
                </Transition>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as Sankey } from "./sankey.vue";
import { default as Loading } from "./loading.vue"
import { default as NetworkMap } from "./network-map.vue";
import { ntopng_url_manager, ntopng_utility } from "../services/context/ntopng_globals_services.js";

const props = defineProps({
    context: Object,
});

const _i18n = (t) => i18n(t);
const no_data_message = i18n('no_data_available')
const show_sankey = ref(true);
const sankey_data = ref({});
const sankey_chart = ref(null);
const loading = ref(true);
const network_map_test = ref(null)
const sankey_test_url = `${http_prefix}/lua/rest/v2/get/ntopng/test_rest.lua`;
const network_map_test_url = `${http_prefix}/lua/rest/v2/get/ntopng/test_rest.lua`

let intervalId = null;

/* ***************************************************** */

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

const updateSankeyData = async () => {
    if (show_sankey.value) {
        loading.value = true;
        let data = await getSankeyData();
        sankey_data.value = data;
        loading.value = false;
    }
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
    params.enabled = true
    let url_params = ntopng_url_manager.obj_to_url_params(params);
    let url_request = `${sankey_test_url}?${url_params}`;
    return url_request;
}

/* ************************************** */

function onNodeClick(_, node) {
    if (node.link) {
        ntopng_url_manager.go_to_url(node.link)
    }
}

/* ************************************** */

const getExtraParameters = () => {
    const extra_params = ntopng_url_manager.get_url_object();
    return {
        enabled: false,
        ...extra_params
    };
};

/* ************************************** */

onMounted(() => {
    updateSankeyData()
})

/* ************************************** */

onBeforeMount(() => { })

/* ************************************** */

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
