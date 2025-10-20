<template>


  <div class="container-fluid p-3">
    <div class="row">
      <div class="col-md-4 mb-2">
        <div ref="nprobeComponent" class="bg-success text-white p-3 d-flex justify-content-between align-items-center">
          <BadgeComponent id="probesCounter" :params="probesCounterParams" :ifid="props.context.ifid.toString()"
            :get_component_data="get_component_data_func(probesCounterParams)"
            :set_component_attr="set_component_attr_func(probesCounterParams)" :filters="{}">
          </BadgeComponent>
        </div>
      </div>
      <div class="col-md-4 mb-2">
        <div ref="exporterComponent"
          class="bg-success text-white p-3 d-flex justify-content-between align-items-center">
          <BadgeComponent id="exportersCounter" :params="exportersCounterParams" :ifid="props.context.ifid.toString()"
            :get_component_data="get_component_data_func(exportersCounterParams)"
            :set_component_attr="set_component_attr_func(exportersCounterParams)" :filters="{}">
          </BadgeComponent>
        </div>
      </div>
      <div class="col-md-4 mb-2">
        <div ref="interfaceComponent"
          class="bg-success text-white p-3 d-flex justify-content-between align-items-center">
          <BadgeComponent id="interfacesCounter" :params="interfacesCounterParams" :ifid="props.context.ifid.toString()"
            :get_component_data="get_component_data_func(interfacesCounterParams)"
            :set_component_attr="set_component_attr_func(interfacesCounterParams)" :filters="{}">
          </BadgeComponent>
        </div>
      </div>
    </div>

        <TableWithConfig ref="table_probes" :table_id="table_id" :csrf="csrf" :f_map_columns="map_table_def_columns"
            :f_sort_rows="columns_sorting" :get_extra_params_obj="get_extra_params_obj" @custom_event="on_table_custom_event">
        </TableWithConfig>

        <NoteList :note_list="note_list"> </NoteList>

    </div>
</template>


<script setup>
import { ref, reactive, onMounted } from "vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as BadgeComponent } from "./dashboard-badge.vue";
import { default as NoteList } from "./note-list.vue";
import formatterUtils from "../utilities/formatter-utils";
import linksUtils from "../utilities/links-utils.js";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";

// used for dashboard badges
const badgeParams = {
  "i18n_name": "",
  "counter_formatter": "no_formatting",
  "component_resp_field": "",
  "counter_path": "",
  "url_params": {},
  "url": ""
}

const exporter_notes_url = `${http_prefix}/lua/pro/rest/v2/get/exporters/exporter_notes.lua?`
const flowdevice_interface_url = `${http_prefix}/lua/pro/enterprise/flowdevice_interface_details.lua?`
const snmp_interface_details_url = `${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?`
const snmp_interface_config_url = `${http_prefix}/lua/pro/enterprise/flowdevice_interface_details.lua?`
const exporters_counter_url = "/lua/pro/rest/v2/get/exporters/exporters_count.lua"

const interfaces_counter_str = "interfaces_count"
const exporters_counter_str = "exporters_count"
const probes_counter_str = "probes_count"

const interfaces_limit_str = "interfaces_limit"
const exporters_limit_str = "exporters_limit"

const components_info = reactive({});

const exporterComponent = ref(null);
const interfaceComponent = ref(null);
const nprobeComponent = ref(null);

const probesCounterParams = reactive({ ...badgeParams, componentRef: nprobeComponent, url: exporters_counter_url, current_value: probes_counter_str, i18n_name: create_18n_str(probes_counter_str), counter_path: probes_counter_str })
const exportersCounterParams = reactive({ ...badgeParams, componentRef: exporterComponent, url: exporters_counter_url, current_value: exporters_counter_str, limit_value: exporters_limit_str, i18n_name: create_18n_str(exporters_counter_str), counter_path: exporters_counter_str })
const interfacesCounterParams = reactive({ ...badgeParams, componentRef: interfaceComponent, url: exporters_counter_url, current_value: interfaces_counter_str, limit_value: interfaces_limit_str, i18n_name: create_18n_str(interfaces_counter_str), counter_path: interfaces_counter_str })
const loading = ref(false);

const props = defineProps({
    context: Object
});

const note_list = ref([]);
const snmp_port_idx = ref(null);
const table_id = ref(props.context.all_exporters ? 'all_exporters_interfaces' : 'exporter_interfaces');
const table_probes = ref(null);
const csrf = props.context.csrf;

function create_18n_str(i18n_name) {
  return "flow_devices." + i18n_name
}

// Function to display notes on the footer of the table
async function get_notes(snmp_port_idx) {
    let url = exporter_notes_url + `ip=${get_ip_from_url()}&snmp_port_idx=${snmp_port_idx}`
    const rsp = await ntopng_utility.http_request(url);

    note_list.value = rsp.map(el => el.content);
}

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

function get_ip_from_url() {
    return ntopng_url_manager.get_url_entry('ip')
}

const map_table_def_columns = (columns) => {
    let map_columns = {
        "ifindex": (value, row) => {
            get_notes(value)
            const snmp_interface_url = `${snmp_interface_details_url}ip=${get_ip_from_url()}&page=config&snmp_port_idx=${value}&ifid=${props.context.ifid}`
            if (row.snmp_interface_available)
                return `<a href=${snmp_interface_url}>${value}</i></a>`
            else
                return value
        },
        "snmp_ifname": (value, row) => {            
            return value
        },
        "in_bytes": (value, row) => {
            if (!value)
                return '';
            return formatterUtils.getFormatter("bytes")(value);
        },
        "out_bytes": (value, row) => {
            if (!value)
                return '';
            return formatterUtils.getFormatter("bytes")(value);
        },
        "throughput": (value, row) => {
            if (!value)
                return '';
            return formatterUtils.getFormatter("bps")(value);
        },
        "ratio": (value, row) => {
            if (!value.value || value.value == -1)
                return '';
            return formatterUtils.getFormatter("ratio")(value.value);
        }
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        if (c.id == "actions") {
            const visible_dict = {
                jump_to_snmp: props.context.isSNMPAvailable,
                timeseries: props.context.showTimeseries,
            };
            c.button_def_array.forEach((b) => {
                b.f_map_class = (current_class, row) => {
                    // if is not defined is enabled
                    if (!visible_dict[b.id]) {
                        current_class.push("disabled");
                    } else if (!(row.snmp_interface_available) && (b.id === "jump_to_snmp")) {
                        current_class.push("disabled");
                    }
                    return current_class;
                }
            });
        }
    });

    return columns;
};

/* ************************************** */

function columns_sorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "ip") {
            return sortingFunctions.sortByIP(r0.probe_ip, r1.probe_ip, col.sort);
        } else if (col.id == "name") {
            return sortingFunctions.sortByName(r0.probe_public_ip, r1.probe_public_ip, col.sort);
        } else if (col.id == "exported_flows") {
            return sortingFunctions.sortByNumber(r0.probe_uuid, r1.probe_uuid, col.sort);
        } else if (col.id == "interface_name") {
            return sortingFunctions.sortByName(r0.probe_interface, r1.probe_interface, col.sort);
        }
    }
}

/* ************************************** */

function click_button_jump_to_snmp(event) {
    const row = event.row;
    const url = linksUtils.getSNMPInterfaceDetailsPageURL(row.exporter_ip, row.ifindex, http_prefix)
    window.location.href = url;
}

/* ************************************** */

function click_button_timeseries(event) {
    const row = event.row;
    const url = linksUtils.getExporterInterfaceDetailsPageURL(row.exporter_ip, row.ifindex, row.ifid, http_prefix)
    window.location.href = url;
}

/* ************************************** */

function on_table_custom_event(event) {
    let events_managed = {
        "click_button_jump_to_snmp": click_button_jump_to_snmp,
        "click_button_timeseries": click_button_timeseries,
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

/* ************************************** */

// used by dashboard badges
function get_component_data_func(component) {
  const get_component_data = async (url, url_params, post_params) => {
    let info = {};
    if (!components_info[component.url]) {
      components_info[component.url] = {};
    }
    info = components_info[component.url];

    if (info.data) {
      await info.data;
    }

    const data_url = `${component.url}${url_params ? '?' + url_params : ''}`;

    loading.value = true;
    if (post_params) {
      info.data = ntopng_utility.http_post_request(data_url, post_params);
    } else {
      info.data = ntopng_utility.http_request(data_url);
    }

    info.data = info.data.then((response) => {
      loading.value = false;
      if (response.are_limits_exceeded) {
        if (response[component.current_value] === response[component.limit_value]) {
          component.componentRef.classList.add('bg-danger')
          component.componentRef.classList.remove('bg-success')
        }
      } else if (response[component.current_value] === response[component.limit_value]) {
        component.componentRef.classList.add('bg-warning')
        component.componentRef.classList.remove('bg-success')
      }
      const value = `${response[component.current_value]}${component.limit_value ? " / " + response[component.limit_value] : ""}`;
      const resKey = component.counter_path

      return { [resKey]: value }
    });

    return info.data;
  };
  return get_component_data;
}

function set_component_attr_func(component) {
  const set_component_attr = async (attr, value) => {
    component[attr] = value;
  }
  return set_component_attr;
}

</script>
