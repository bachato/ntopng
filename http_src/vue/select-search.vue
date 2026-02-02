<template>
    <!-- Select2 wrapper component with Vue integration -->
    <select class="select2 form-select" ref="select2" required name="filter_type" :multiple="multiple"
        :disabled="disabled">
        <!-- Render regular options (without groups) -->
        <option class="no-wrap  p-0" v-for="(item, i) in options_2" :selected="is_selected(item)" :value="item.value"
            :disabled="item.disabled">
            {{ item.label }}
        </option>
        <!-- Render grouped options -->
        <optgroup v-for="(item, i) in groups_options_2" :label="item.group">
            <option v-for="(opt, j) in item.options" :selected="is_selected(opt)" :value="opt.value"
                :disabled="opt.disabled">
                {{ opt.label }}
            </option>
        </optgroup>
    </select>
</template>

<script setup>
import { ref, onMounted, computed, watch, onBeforeUnmount } from "vue";

// Reference to the native select element for Select2 initialization
const select2 = ref(null);

// const selected2_option = ref({});

// Define component events for parent communication
const emit = defineEmits(['update:selected_option', 'update:selected_options', 'select_option', 'unselect_option', 'change_selected_options']);

// Reactive state for internal option management
const options_2 = ref([]); // Regular options (without groups)
const groups_options_2 = ref([]); // Grouped options
const selected_option_2 = ref({}); // Currently selected option (single select)
const selected_values = ref([]); // Array of selected values (multiple select)
const refresh_options = ref(0); // Counter to trigger option re-rendering

// Component props definition
const props = defineProps({
    id: String,
    options: Array, // Source options array
    selected_option: Object, // Currently selected option (single mode)
    selected_options: Array, // Currently selected options (multiple mode)
    multiple: Boolean, // Whether multiple selection is allowed
    add_tag: Boolean, // Whether to allow adding custom tags
    disable_change: Boolean, // Whether to disable option updates
    theme: String, // Select2 theme
    dropdown_size: String, // Size variant for dropdown
    disabled: Boolean // Whether the select is disabled
});

let first_time_render = true; // Flag to track initial render

// Lifecycle hook: Initialize component when mounted
onMounted(() => {
    if (!props.disable_change || !first_time_render) {
        set_input();
    }
});

// Watch for changes in selected_option prop (single select mode)
watch(() => props.selected_option, (cur_value, old_value) => {
    set_selected_option(cur_value);
    change_select_2_selected_value();
}, { flush: 'pre' });

// Watch for changes in selected_options prop (multiple select mode)
watch(() => props.selected_options, (cur_value, old_value) => {
    set_selected_values(cur_value);
    change_select_2_selected_value();
}, { flush: 'pre' });

// Watch for option refresh trigger
watch([refresh_options], (cur_value, old_value) => {
    render();
}, { flush: 'post' });

// Watch for changes in options prop
watch(() => props.options, (current_value, old_value) => {
    if (props.disable_change == true || current_value == null) { return; }
    set_input();
}, { flush: 'pre' });

/**
 * Initialize component with options and selection state.
 * This function orchestrates the complete setup process by calling:
 * 1. set_options() - processes and categorizes options
 * 2. set_selected_option() - sets single selection state
 * 3. set_selected_values() - sets multiple selection state
 */
function set_input() {
    set_options();
    set_selected_option();
    set_selected_values();
}

/**
 * Process raw options array and separate them into regular and grouped options.
 * This function performs several transformations:
 * 1. Creates a shallow copy of each option to avoid mutation
 * 2. Ensures each option has a value (uses label as fallback)
 * 3. Separates options based on the presence of 'group' property
 * 4. Groups options by their group property using a dictionary
 * 5. Converts the groups dictionary to an array format
 * 
 * The resulting structure:
 * - options_2: Array of options without groups
 * - groups_options_2: Array of grouped options with structure {group: string, options: array}
 * 
 * @throws Will skip processing if props.options is null
 * @sideeffect Updates options_2, groups_options_2, and increments refresh_options
 */
function set_options() {
    options_2.value = [];
    groups_options_2.value = [];

    if (props.options == null) { return; }
    let groups_dict = {};
    props.options.forEach((option) => {
        let opt_2 = { ...option };
        // Use label as value if value is not provided
        if (opt_2.value == null) {
            opt_2.value = opt_2.label;
        }
        // Separate options with groups from regular options
        if (option.group == null) {
            options_2.value.push(opt_2);
        } else {
            if (groups_dict[option.group] == null) {
                groups_dict[option.group] = { group: opt_2.group, options: [] };
            }
            groups_dict[option.group].options.push(opt_2);
        }
    });
    // Convert groups dictionary to array
    groups_options_2.value = ntopng_utility.object_to_array(groups_dict);
    refresh_options.value += 1; // Trigger re-render
}

/**
 * Custom search matcher function for Select2 with hierarchical search support.
 * This function implements case-insensitive searching that works across nested option groups.
 * 
 * Algorithm:
 * 1. Normalize search term and text to lowercase for case-insensitive comparison
 * 2. If no search term is provided, return all data (no filtering)
 * 3. Check if the parent item's text contains the search term
 * 4. If no match, recursively search through child items (for grouped options)
 * 5. If children match, return the parent with filtered children only
 * 6. Return null if neither parent nor children match
 * 
 * @param {Object} params - Select2 search parameters
 * @param {string} params.term - The search term entered by the user
 * @param {Object} data - The option data object from Select2
 * @param {string} data.text - Display text of the option
 * @param {Array} [data.children] - Child options for grouped items
 * @returns {Object|null} - Modified data object with filtered children, original data, or null if no match
 * 
 * @example
 * // Returns data unchanged
 * matchCustom({term: ''}, {text: 'Option 1'})
 * 
 * // Returns data if text contains 'opt'
 * matchCustom({term: 'opt'}, {text: 'Option 1'})
 * 
 * // Returns parent with filtered children
 * matchCustom({term: 'child'}, {text: 'Parent', children: [{text: 'Child 1'}, {text: 'Other'}]})
 */
function matchCustom(params, data) {
    // `params.term` should be the term that is used for searching
    // `data.text` is the text that is displayed for the data object
    // Searching with lower case, case insensitive
    const searchedString = params?.term?.toLowerCase()
    const text = data?.text?.toLowerCase()

    // If there are no search terms, return all of the data
    if (!searchedString?.trim()) {
        // Trim removes white spaces
        return data;
    }

    // Do not display the item if there is no 'text' property
    if (!text) {
        return null;
    }

    // Search for the string in the text
    if (text.indexOf(searchedString) > -1) {
        return data
    }

    // Now search the childs, in case of groups
    const filteredChildren = []
    data?.children?.forEach((child) => {
        const childText = child?.text?.toLowerCase()
        // Search for the string in the text
        if (childText && childText.indexOf(searchedString) > -1) {
            filteredChildren.push(child);
        }
    })

    if (filteredChildren.length > 0) {
        const modifiedParent = { ...data };
        modifiedParent.children = filteredChildren
        return modifiedParent;
    }

    // Return `null` if the term should not be displayed
    return null;
}

/**
 * Initialize or re-initialize the Select2 plugin with Vue integration.
 * This is the core rendering function that:
 * 1. Destroys existing Select2 instance if not first render
 * 2. Initializes Select2 with custom configuration
 * 3. Sets up event handlers for selection changes
 * 4. Synchronizes Vue state with Select2 state
 * 
 * Configuration includes:
 * - Custom matcher for hierarchical search
 * - Theme customization
 * - Tagging support (when enabled)
 * - Size variants via CSS classes
 * 
 * Event handling:
 * - select2:select: Handles both regular selections and custom tag creation
 * - select2:unselect: Manages removal from multiple selections
 * 
 * @sideeffect Modifies DOM, sets up jQuery event listeners, updates first_time_render flag
 * @throws May throw if Select2 initialization fails or jQuery is not available
 */
const render = () => {
    let select2Div = select2.value;
    if (first_time_render == false) {
        destroy();
    }
    if (!$(select2Div).hasClass("select2-hidden-accessible")) {
        $(select2Div).select2({
            matcher: matchCustom,
            width: '100%',
            theme: props.theme ? props.theme : 'bootstrap-5',
            dropdownParent: $(select2Div).parent(),
            dropdownAutoWidth: true,
            tags: props.add_tag && !props.multiple,
            selectionCssClass: props.dropdown_size == "small" ? 'select2--small' : '',
            dropdownCssClass: props.dropdown_size == "small" ? 'select2--small' : ''
        });
        // Handle option selection event
        $(select2Div).on('select2:select', function (e) {
            let data = e.params.data;
            if (data.element === null) {
                //TODO: implement for multiselect
                let option = { label: data.text, value: data.id };
                emit('update:selected_option', option);
                emit('select_option', option);
                return;
            }
            let value = data.element._value;
            let option = find_option_from_value_or_label(value);
            if (value !== props.selected_option) {
                emit('update:selected_option', option);
                emit('select_option', option);
            }
            if (!props.multiple) {
                return;
            }
            // Update selected values for multiple select
            selected_values.value = selected_values.value.filter((v) => v != value);
            selected_values.value.push(value);
            let options = find_options_from_values(selected_values.value);
            emit('update:selected_options', options);
            emit('change_selected_options', options);
        });
        // Handle option unselection event (multiple select only)
        $(select2Div).on('select2:unselect', function (e) {
            let data = e.params.data;
            let value = data.element._value;
            if (!props.multiple) {
                return;
            }
            selected_values.value = selected_values.value.filter((v) => v != value);
            let option = find_option_from_value_or_label(value);
            let options = find_options_from_values(selected_values.value);
            emit('unselect_option', option);
            emit('update:selected_options', options);
            emit('change_selected_options', options);
        });
    }
    first_time_render = false;
    // this.$forceUpdate();
    change_select_2_selected_value();
};

/**
 * Synchronize Select2's displayed value with Vue's internal state.
 * This function ensures the Select2 UI reflects the current selection state.
 * 
 * For single select mode:
 * - Extracts value from selected option object
 * - Sets Select2 value and triggers change event
 * 
 * For multiple select mode:
 * - Uses the array of selected values
 * - Updates Select2 with all selected values
 * 
 * @sideeffect Modifies Select2 DOM element value and triggers change events
 */
function change_select_2_selected_value() {
    let select2Div = select2.value;
    if (!props.multiple) {
        let value = get_value_from_selected_option(props.selected_option);
        $(select2Div).val(value);
        $(select2Div).trigger("change");
    } else {
        $(select2Div).val(selected_values.value);
        $(select2Div).trigger("change");
    }
}

/**
 * Determine if an option should be marked as selected in the rendered HTML.
 * This function handles the logic for both single and multiple selection modes.
 * 
 * Single select logic:
 * 1. Compares option value with selected option value (strict equality)
 * 2. Special handling for zero values: also matches by label if value is 0 or "0"
 * 
 * Multiple select logic:
 * 1. Checks if value exists in selected_values array
 * 2. Falls back to option's own 'selected' property
 * 
 * @param {Object} item - The option object to check
 * @param {string|number} item.value - Option value
 * @param {string} item.label - Option display label
 * @param {boolean} [item.selected] - Optional pre-selected flag
 * @returns {boolean} - True if the option should be marked as selected
 */
function is_selected(item) {
    if (!props.multiple) {
        const is_zero_value = selected_option_2.value.value == 0 || selected_option_2.value.value == "0";
        return item.value == selected_option_2.value.value || (is_zero_value && item.label == selected_option_2.value.label);
    }
    return selected_values.value.find((v) => v == item.value) != null || item.selected;
}

/**
 * Initialize selected values array from props for multiple select mode.
 * This function converts an array of option objects into an array of values.
 * Each option's value is extracted (with label as fallback) and added to selected_values.
 * 
 * @sideeffect Updates selected_values reactive array
 * @note Only executes in multiple select mode and when selected_options is provided
 */
function set_selected_values() {
    if (props.selected_options == null || !props.multiple) {
        return;
    }
    selected_values.value = [];
    props.selected_options.forEach((opt) => {
        let value = opt.value || opt.label;
        selected_values.value.push(value);
    });
}

/**
 * Set the internal selected option state for single select mode.
 * This function handles null/undefined cases by falling back to the first option
 * when no selection is provided and not in multiple select mode.
 * 
 * @param {Object|null} selected_option - The option to select, or null for default
 * @sideeffect Updates selected_option_2 reactive reference
 */
function set_selected_option(selected_option) {
    if (selected_option == null && !props.multiple) {
        selected_option = get_props_selected_option();
    }
    selected_option_2.value = selected_option;
}

/**
 * Get the selected option from props with safe fallback logic.
 * This function provides a default selection when none is specified.
 * 
 * @returns {Object} - The selected option from props, or the first option if none selected
 * @throws May return undefined if props.options is empty
 */
function get_props_selected_option() {
    if (props.selected_option == null) {
        return props.options[0];
    }
    return props.selected_option;
}

/**
 * Extract the display value from a selected option object.
 * This function handles the optional nature of the 'value' property by using
 * label as a fallback when value is not provided.
 * 
 * @param {Object|null} selected_option - The option object
 * @param {string|number} [selected_option.value] - Optional value property
 * @param {string} selected_option.label - Display label (used as fallback value)
 * @returns {string|number} - The value to use for Select2
 */
function get_value_from_selected_option(selected_option) {
    if (selected_option == null) {
        selected_option = get_props_selected_option();
    }
    let value;
    if (selected_option.value != null) {
        value = selected_option.value;
    } else {
        value = selected_option.label;
    }
    return value;
}

/**
 * Convert an array of string/number values to an array of full option objects.
 * This function maps each value through find_option_from_value_or_label to
 * retrieve the complete option object with all its properties.
 * 
 * @param {Array<string|number>} values - Array of option values
 * @returns {Array<Object>} - Array of corresponding option objects
 */
function find_options_from_values(values) {
    let options = values.map((v) => find_option_from_value_or_label(v));
    return options;
}

/**
 * Find the original option object from the props.options array by value or label.
 * This function bridges between the internal processed options and the original
 * props to ensure event emissions contain the original option objects.
 * 
 * Process:
 * 1. Finds the processed option in options_2 or groups_options_2
 * 2. Uses that option's value or label to locate the original in props.options
 * 
 * @param {string|number} value - The value to search for
 * @returns {Object} - The original option object from props.options
 */
function find_option_from_value_or_label(value) {
    let option_2 = find_option_2_from_value(value);
    let option = props.options.find((o) => (o.value === option_2.value) || (o.label == option_2.label));
    return option;
}

/**
 * Find an option from the internal processed collections by its value.
 * This function searches through both regular and grouped options using
 * strict equality comparison (===) for accurate matching.
 * 
 * Search order:
 * 1. Regular options (options_2)
 * 2. Grouped options (groups_options_2)
 * 
 * @param {string|number} value - The value to search for
 * @returns {Object|null} - The found option object or null if not found
 */
function find_option_2_from_value(value) {
    if (value == null) {
        value = get_value_from_selected_option();
    }
    // let option = options_2.value.find((o) => o.value == value);
    let option = options_2.value.find((o) => o.value === value);
    if (option != null) { return option; }
    // Search in grouped options
    for (let i = 0; i < groups_options_2.value.length; i += 1) {
        let g = groups_options_2.value[i];
        option = g.options.find((o) => o.value === value);
        if (option != null) {
            return option;
        }
    }
    return null;
}

/**
 * Clean up Select2 instance and event listeners to prevent memory leaks.
 * This function safely destroys the Select2 plugin and removes all jQuery
 * event handlers attached to the element.
 * 
 * Error handling:
 * - Wraps destruction in try-catch to prevent unmount errors
 * - Logs errors without throwing to avoid disrupting component lifecycle
 * 
 * @sideeffect Removes Select2 from DOM, clears event listeners
 */
function destroy() {
    try {
        $(select2.value).select2('destroy');
        $(select2.value).off('select2:select');
    } catch (err) {
        console.error("Destroy select-search catch error:");
        console.error(err);
    }
}

// Lifecycle hook: Clean up before component unmounts
onBeforeUnmount(() => {
    destroy();
});

// Expose render function to parent components
defineExpose({ render });

</script>