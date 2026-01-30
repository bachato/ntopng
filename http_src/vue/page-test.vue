<template>
    <div class="row">
        <Transition name="add-effect" mode="out-in">
            <div class="position-relative">
                <div class="card card-shadow">
                    <div class="card-body">
                        <NetworkMap ref="network_map_test" :empty_message="no_data_message" :height="'30vh'"
                            :page_csrf="props.context.csrf" :url="network_map_test_url" :url_params="getExtraParameters()"
                            :map_id="'network_map_test'">
                        </NetworkMap>
                    </div>
                </div>
            </div>
        </Transition>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as NetworkMap } from "./network-map.vue";
import { ntopng_url_manager, ntopng_utility } from "../services/context/ntopng_globals_services.js";

const props = defineProps({
    context: Object,
});

const _i18n = (t) => i18n(t);
const no_data_message = i18n('no_data_available')
const network_map_test = ref(null)
const network_map_test_url = `${http_prefix}/lua/rest/v2/get/ntopng/test_rest.lua`

/* ***************************************************** */

const getExtraParameters = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ************************************** */

onMounted(() => {})

/* ************************************** */

onBeforeMount(() => {})

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
