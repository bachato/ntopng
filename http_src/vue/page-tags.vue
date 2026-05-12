<!-- (C) 2026 - ntop.org -->
<template>
  <div class="m-2 mb-3">
    <TableWithConfig ref="tags_list" :table_id="table_id" :csrf="csrf" :showLoading="true"
      @custom_event="on_table_custom_event" :f_map_columns="map_table_def_columns"
      :get_extra_params_obj="get_extra_params_obj"
      :f_sort_rows="columns_sorting">
    </TableWithConfig>
    <ModalEditTag ref="tagModal" @edit="handleEditTag" @reset="handleResetTag"> </ModalEditTag>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as ModalEditTag } from "./modal-edit-tag.vue";


/* ************************************** */

const _i18n = (t) => i18n(t);
const props = defineProps({ context: Object });

/* ************************************** */
const loading = ref(false);
const table_id = ref("tags_list");
const tags_list = ref(null);
const csrf = props.context.csrf;
const tagModal = ref(null);
const edit_tag_url = `${http_prefix}/lua/rest/v2/edit/tag/tag.lua`;
const reset_tag_url = `${http_prefix}/lua/rest/v2/delete/tag/tag.lua`;
let edit_tag_id = ref(null);
/* ************************************** */

const map_table_def_columns = (columns) => {
    let map_columns = {
        "name": (value, row) => {
            return "<span class='badge' style='background-color:"+ row.color +"'>" +
                    value + "</span> "
        },
        "description": (value, row) => {
            return value
        },
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
    });

    return columns;
};

/* ************************************** */

function columns_sorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "name") {
            return sortingFunctions.sortByName(r0.name, r1.name, col.sort);
        }
    }
 }

/* ************************************** */

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ************************************** */

function on_table_custom_event(event) {
    let events_managed = {
        "click_button_edit_tag": click_button_edit_tag
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

const click_button_edit_tag = (event) => {
    edit_tag_id = event.row.id;
    const tag_data = {
        tag_id: event.row.id,
        tag_name: event.row.name,
        tag_color: event.row.color,
        tag_description: event.row.description,
        tag_reserved: event.row.reserved,
    };

    showEditModal(tag_data);
};

/* ************************************** */

const showEditModal = (item) => {
    tagModal.value.showEdit(item);
};

/* ************************************** */

const handleEditTag = async (data) => {
    const new_tag_id = edit_tag_id;
    const new_tag_name = data.tag_name;
    const new_tag_color = data.tag_color;
    const new_tag_description = data.tag_description;

    const headers = {
        'Content-Type': 'application/json'
    };

    try {
        const addParams = {
            csrf: props.context.csrf,
            tags: [{
                tag_id: new_tag_id,
                tag_name: new_tag_name,
                color: new_tag_color,
                description: new_tag_description
            }]
        };

        await ntopng_utility.http_request(edit_tag_url, {
            method: 'post',
            headers,
            body: JSON.stringify(addParams)
        });

        // Refresh table
        tags_list.value.refresh_table(true);

    } catch (e) {
        console.error('Error during tag edit:', e);
        tags_list.value.refresh_table(true);
    }
};

/* ************************************** */

const handleResetTag = async (item) => {
    if (item) {
        const tag_id = item.tag_id;

        const requestParams = {
            csrf: props.context.csrf,
            tag_id: tag_id
        };

        const headers = { 'Content-Type': 'application/json' };

        try {
            await ntopng_utility.http_request(reset_tag_url, {
                method: 'post',
                headers,
                body: JSON.stringify(requestParams)
            });

            // Refresh table after delete
            tags_list.value.refresh_table(true);
        } catch (e) {
            console.error('Error deleting tag:', e);
            tags_list.value.refresh_table(true);
        }
    }
};

onMounted(async () => {
});

</script>
