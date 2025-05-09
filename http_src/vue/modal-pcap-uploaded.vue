<!-- (C) 2022 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>
      {{ _i18n("success") }}
    </template>
    <template v-slot:body>
      {{ _i18n("analyze_pcap_ok") }}
    </template><!-- modal-body -->
    <template v-slot:footer>
      <div>
        <button type="button" @click="loadNewInterface" class="btn btn-primary">{{ _i18n('switch_new_pcap_interface') }}</button>
      </div>
    </template>
  </modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";

const props = defineProps({
  page: String,
  context: Object,
});
const emit = defineEmits(["load_interface"]);

const _i18n = (t) => i18n(t);
const modal_id = ref(null);

onMounted(() => {});

const show = () => {
  modal_id.value.show();
};

const close = () => {
  modal_id.value.close();
};

const loadNewInterface = function() {
  emit("load_interface")
  close()
}

defineExpose({ show, close });

</script>
