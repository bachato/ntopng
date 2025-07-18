<template>
    <a class="btn btn-link btn-sm w-auto" type="button" @click="change_value" :title="title" :class="isOn ? '' : 'link-secondary'">
      <i class="fas fa-lg" :class="[ isOn ? 'btn-success' : 'btn-outline-secondary', icon ]">
      </i>
    </a>
</template>

<script setup>
import { ref, onMounted, computed, watch, h } from "vue";

const emit = defineEmits(['update:value', 'change_value']);

const props = defineProps({
    value: Boolean,
    title: String,
    label: String,
    icon: String /* e.g. fa-truck-fast */
});

const isOn = ref(false);

onMounted(() => {
    isOn.value = props.value;
});

watch(() => props.value, (cur_value, old_value) => {
    isOn.value = props.value;
}, { flush: 'pre'});

function change_value() {
    emit('update:value', !isOn.value);
    emit('change_value', !isOn.value);
}

</script>

<style scoped>
</style>
