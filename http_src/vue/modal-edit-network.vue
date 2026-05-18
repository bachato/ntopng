<!-- (C) 2026 - ntop.org     -->
<template>
    <!-- Modal component wrapper for edit network form -->
    <modal ref="modal_id">
        <!-- Modal header title - changes based on context (add/edit) -->
        <template v-slot:title>
            {{ _i18n("network_details.edit_network") }}
        </template>

        <!-- Modal body containing the form fields -->
        <template v-slot:body>
            <!-- ==================== Network Alias ==================== -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-3">
                    <label for="network_alias" class="form-label fw-bold mb-0">
                        {{ _i18n("network_details.network_alias") }}
                        <i class="fa-solid fa-circle-question" data-bs-toggle="tooltip" data-bs-placement="top"
                            :title="_i18n('network_details.alias_description')"></i>
                    </label>
                </div>
                <div class="col-md-9">
                    <!-- Name input with validation styling -->
                    <input id="network_alias" type="text" class="form-control" :class="{ 'is-invalid': name_error }"
                        v-model="network_alias" @input="validateNameDebounced" />
                    <!-- Validation error message display -->
                    <div v-if="name_error" class="invalid-feedback">
                        {{ name_error }}
                    </div>
                </div>
            </div>

            <!-- ==================== Site Field ==================== -->
            <div class="row mb-3">
                <div class="col-md-3">
                    <label class="form-label fw-bold mb-0">
                        {{ _i18n("sites_page.site_name") }}
                        <i class="fa-solid fa-circle-question" data-bs-toggle="tooltip" data-bs-placement="top"
                            :title="_i18n('network_details.site_description')"></i>
                    </label>
                </div>

                <div class="col-md-9">
                    <SelectSearch :options="_sitesList" :selected_option="selectedSite"
                        @update:selected_option="updateSelectedOption" />
                </div>
            </div>
        </template>
        <!-- Modal footer with action buttons -->
        <template v-slot:footer>
            <div class="d-flex w-100">
                <!-- Error message display area (validation errors, server errors) -->
                <div v-if="errorMessage" class="alert alert-danger alert-danger-sm col-8">
                    {{ errorMessage }}
                </div>
                <!-- Submit button - disabled until form is valid -->
                <button type="button" class="btn btn-primary ms-auto" @click="handleSubmit" :disabled="!is_form_valid">
                    {{ _i18n("save") }}
                </button>
            </div>
        </template>
    </modal>
</template>


<script setup>
import { ref, computed, nextTick, watch } from "vue";
import SelectSearch from "./select-search.vue";
import { default as modal } from "./modal.vue";
import regexValidation from "../utilities/regex-validation"

// Internationalization helper
const _i18n = (t) => i18n(t);

// ==================== Refs and State ====================
const modal_id = ref(null);                    // Reference to modal component

// Form field bindings
const network_alias = ref("");                  // Network name
const network_cidr = ref("")
const selectedSite = ref([])

// Form state management
const name_error = ref("");                      // Validation error message for name field
const _sitesList = ref([])

// ==================== Component Events ====================
const emit = defineEmits(["edit"]);        // Emit edit or add event on form submission

// ==================== Props ====================
const props = defineProps({
    errorMessage: String,    // Error message from parent component
    sitesList: Object
});

// ==================== Computed Properties ====================

// Form validity check for enabling/disabling submit button
// Requirements: name not empty, name length > 1, no validation errors
const is_form_valid = computed(() => {
    return network_alias.value.trim().length > 1 && !name_error.value;
});

watch(() => [props.sitesList], (cur_value, old_value) => {
    _sitesList.value = cur_value[0].map((t) => {
        return {
            id: t.id,
            label: t.name,
            title: t.name,
        }
    })
}, { flush: 'pre', deep: true });

// ==================== Validation Methods ====================

let debounce_name_timer = null

function validateNameDebounced() {
    clearTimeout(debounce_name_timer)
    debounce_name_timer = setTimeout(() => {
        validateName()
    }, 400) // wait 400 ms before checking the input in order to not check each single character
}

/**
 * Validates the site name according to business rules:
 * - Cannot be empty
 * - Must be longer than 1 character
 * - Must contain only alphanumeric characters and spaces
 * 
 * For reserved sites, validation is skipped (field is disabled)
 */
const validateName = () => {
    const trimmed = network_alias.value.trim();
    // Unicode-aware regex that allows letters, numbers, and spaces
    const alphanumericRegex = /^[\p{L}0-9 .,\-@]+$/u;

    if (!trimmed) {
        name_error.value = _i18n("error_messages.name_cannot_be_empty");
    } else if (trimmed.length <= 1) {
        name_error.value = _i18n("error_messages.name_must_be_longer_than_1_character");
    } else if (!alphanumericRegex.test(trimmed)) {
        name_error.value = _i18n("error_messages.name_must_be_alphanumeric");
    } else {
        name_error.value = "";
    }
};

/**
 * Handles form submission:
 * 1. Validates the form
 * 2. If valid, emits appropriate event (add) with form data
 */
const handleSubmit = () => {
    validateName();
    if (!is_form_valid.value) return;

    // Prepare form data object
    const formData = {
        network_cidr: network_cidr.value,
        network_alias: network_alias.value,
        site_id: selectedSite.value.id
    };

    emit("edit", formData);
};

const updateSelectedOption = (item) => {
    selectedSite.value = item;
}


const open = (item = null) => {
    // Destructure item with defaults (handles both edit and add modes)
    const {
        network_alias: edited_network_alias = "",
        network_cidr: edited_network_cidr,
        site_id: edited_site_id = 0, // default site is 0
    } = item || {}

    // Populate form fields
    network_alias.value = edited_network_alias;
    network_cidr.value = edited_network_cidr;
    selectedSite.value = _sitesList.value.find(el => el.id === edited_site_id);

    // Reset state
    name_error.value = "";

    // Show the modal
    modal_id.value.show();
};

/**
 * Closes the modal
 */
const close = () => {
    modal_id.value.close();
};

// Expose methods to parent components
defineExpose({ open, close });

</script>

<style scoped>
.fade-scale-enter-active,
.fade-scale-leave-active {
    transition: all 0.5s ease;
}

.fade-scale-enter-from {
    opacity: 0;
    transform: scaleY(0);
}

.fade-scale-enter-to {
    opacity: 1;
    transform: scaleY(1);
}

.fade-scale-leave-from {
    opacity: 1;
    transform: scaleY(1);
}

.fade-scale-leave-to {
    opacity: 0;
    transform: scaleY(0);
}

.alert-danger-sm {
    margin-bottom: 0 !important;
    padding: 0.3rem !important
}
</style>