<!-- (C) 2026 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>
      {{ title }}
    </template>
    <template v-slot:body>
      {{ message }}
      <div v-if="show_return_msg" class="text-left">
      </div>
    </template><!-- modal-body -->
    <template v-slot:footer>
      <button type="button" @click="reset_tag" class="btn btn-danger">{{ _i18n("reset") }}</button>
    </template>
  </modal>
</template>

<script setup>
import { ref, onMounted, nextTick } from "vue";
import { default as modal } from "./modal.vue";

const _i18n = (t) => i18n(t);
const modal_id = ref(null);
const message = ref('')
const return_message = ref('')
const show_return_msg = ref(false)
const title = ref('')
const err = ref(false);
const row = ref(null);
const tag_id = ref(null);

const emit = defineEmits(["reset"]);

const props = defineProps({
  context: Object,
});

onMounted(() => { });

/* ****************************************** */

/* This function simply reset the modal to factory values */
async function resetModal() {
  row.value = null;
  message.value = '';
  return_message.value = '';
  show_return_msg.value = false;
  err.value = false;
  title.value = '';
}

/* ****************************************** */

/* This function formats the reset message */
async function formatMessage(tag) {
  title.value = i18n("tags_page.reset_tag_title")
  if (tag) {
    const tag_name = tag.tag_name;
    title.value = title.value + ": " + tag_name;
  }
  message.value = i18n('tags_page.reset_tag');
}

/* ****************************************** */

async function reset_tag() {
  const formData = {
    tag_id: tag_id.value,
    reset: true
  };
  emit("reset", formData);
}


const showReset = async (item) => {
  resetModal();
  tag_id.value = item.tag_id;
  formatMessage(item);
  modal_id.value.show();
};

const close = () => {
  setTimeout(() => {
    modal_id.value.close();
  }, 500 /* 0.5 seconds */)
};

defineExpose({ showReset, close });

</script>
