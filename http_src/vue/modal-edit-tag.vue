<!-- (C) 2026 - ntop.org     -->
<template>
    <modal ref="modal_id">
        <template v-slot:title>
            {{ _i18n("tags_page.edit_tag") }}
        </template>

        <template v-slot:body>
            <!-- Tag Name -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-3">
                    <label for="tag_name" class="form-label fw-bold mb-0">
                        {{ _i18n("tags_page.tag_name") }}
                    </label>
                </div>
                <div class="col-md-9">
                    <input
                        id="tag_name"
                        type="text"
                        class="form-control"
                        :class="{ 'is-invalid': name_error }"
                        v-model="tag_name"
                        @input="validateName"
                        :title="isReserved ? _i18n('tags_page.reserved_message') : ''"
                        data-bs-toggle="tooltip"
                        data-bs-placement="top"
                        :disabled="isReserved"
                        required
                    />
                    <div v-if="name_error" class="invalid-feedback">
                        {{ name_error }}
                    </div>
                </div>
            </div>

            <!-- Tag Color -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-3">
                    <label for="tag_color" class="form-label fw-bold mb-0">
                        {{ _i18n("tags_page.tag_color") }}
                    </label>
                </div>
                <div class="col-md-9">
                    <input
                        id="tag_color"
                        type="color"
                        class="form-control form-control-color"
                        v-model="tag_color"
                        required
                    />
                </div>
            </div>

            <!-- Tag Description -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-3">
                    <label for="tag_description" class="form-label fw-bold mb-0">
                        {{ _i18n("tags_page.tag_description") }}
                    </label>
                </div>
                <div class="col-md-9">
                    <textarea
                        id="tag_description"
                        class="form-control"
                        rows="3"
                        v-model="tag_description"
                        :title="isReserved ? _i18n('tags_page.reserved_message') : ''"
                        data-bs-toggle="tooltip"
                        data-bs-placement="top"
                        :disabled="isReserved"
                    ></textarea>
                </div>
            </div>
        </template>

        <template v-slot:footer>
            <button
                v-if="!isReserved"
                type="button"
                class="btn btn-secondary btn-block"
                @click="handleResetButton"
            >
                {{ _i18n("reset") }}
            </button>

            <button
                type="button"
                class="btn btn-primary btn-blo"
                @click="handleSubmit"
                :disabled="!is_form_valid"
            >
                {{ _i18n("save") }}
            </button>
        </template>
    </modal>
    <ModalResetTag
        ref="tagReset" @reset="handleReset">
    </ModalResetTag>
</template>


<script setup>

import { ref, computed, nextTick } from "vue";
import { default as modal } from "./modal.vue";
import { default as ModalResetTag } from "./modal-reset-tag.vue";

const _i18n = (t) => i18n(t);

const modal_id = ref(null);

const emit = defineEmits(["edit"]);

const tag_name = ref("");
const tag_color = ref("#000000");
const tag_description = ref("");
const tag_id = ref("");
const tagReset = ref(null);
const name_error = ref("");
const currentItem = ref(null);

const isReserved = computed(() => {
    return currentItem.value?.tag_reserved === 'true';
});

const props = defineProps({
    context: Object,
});

const is_form_valid = computed(() => {
    return tag_name.value.trim().length > 1 && !name_error.value;
});

/* ************************************** */

const validateName = () => {
    if (isReserved.value) {
        name_error.value = "";
        return;
    }
    const name = tag_name.value;

    const alphanumericRegex = /^[\p{L}0-9]+$/u;

    if (!name) {
        name_error.value = _i18n("error_messages.name_cannot_be_empty");
    } else if (name.length <= 1) {
        name_error.value = _i18n("error_messages.name_must_be_longer_than_1_character");
    } else if (/\s/.test(name)) {
        name_error.value = _i18n("error_messages.name_cannot_contain_spaces");
    } else if (!alphanumericRegex.test(name)) {
        name_error.value = _i18n("error_messages.name_must_be_alphanumeric");
    } else {
        name_error.value = "";
    }
};

/* ************************************** */

const handleSubmit = () => {
    validateName();

    if (!is_form_valid.value) {
        return;
    }

    emit("edit", {
        tag_name: tag_name.value.trim(),
        tag_color: tag_color.value,
        tag_description: tag_description.value.trim(),
        item: currentItem.value
    });

    close();
};

/* ************************************** */

const showEdit = async (item) => {
    currentItem.value = item;
    tag_name.value = item.tag_name;
    tag_color.value = item.tag_color || "#000000";
    tag_description.value = item.tag_description || "";
    tag_id.value = item.tag_id;

    name_error.value = "";

    await nextTick();
    modal_id.value.show();
};

/* ************************************** */

const showReset = (item) => {
    tagReset.value.showReset(item);
};

const handleResetButton = () => {
    const tag_data = {
        tag_name: tag_name.value,
        tag_id: tag_id.value,
    };

    showReset(tag_data);
};

/* ****************************************** */

async function handleReset(item) {
    emit("reset", item);
    tagReset.value.close();
    close();
}

/* ************************************** */

const close = () => {
    modal_id.value.close();
};

defineExpose({ showEdit, close });

</script>
