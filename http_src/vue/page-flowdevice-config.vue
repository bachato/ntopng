<!-- (C) 2022-26 - ntop.org     -->
<template>
  <div class="m-3">
    <!-- Page header -->
    <h5>{{ _i18n('modify_flowdev_settings') }}</h5>
    <hr>

    <!-- Main settings card -->
    <div class="m-4 card card-shadow">
      <div class="card-body">
        <!-- Settings table -->
        <div class="table-responsive">
          <table class="table table-striped table-bordered">
            <tbody class="table_length">
              <!-- Flow device alias row -->
              <tr>
                <td>
                  <div class="d-flex align-items-center">
                    <div class="col-8">
                      <b>{{ _i18n('flowdev_alias') }}</b><br>
                    </div>
                    <div class="col-4">
                      <!-- Alias input field with change detection -->
                      <input type="text" ref="aliasInput" class="form-control border" @input="validateFormChanges">
                    </div>
                  </div>
                </td>
              </tr>

              <!-- Exporter Site selection row -->
              <tr>
                <td>
                  <div class="d-flex align-items-center">
                    <div class="col-8">
                      <b>{{ _i18n('flowdev_site') }}</b><br>
                    </div>
                    <div class="col-4">
                      <!-- Dropdown for Site selection -->
                      <SelectSearch v-model:selected_option="selectedSite" :options="siteOptions"
                        :disabled="false" @select_option="handleSiteSelect" />
                    </div>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Action buttons -->
        <div class="d-flex justify-content-end me-1">
          <!-- Save button - disabled when no changes detected -->
          <button class="btn btn-primary" :class="[isSaveDisabled ? 'disabled' : '']" @click="saveFlowDeviceSettings"
            id="save">
            {{ _i18n("save_settings") }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as SelectSearch } from "./select-search.vue";

// Internationalization helper
const _i18n = (t) => i18n(t);

// Template refs
const aliasInput = ref(null);

// Form state
const originalAlias = ref(''); // Original alias value for change detection
const isSaveDisabled = ref(true); // Controls save button state

// Component props
const props = defineProps({
  context: Object // Contains ifid, csrf, and other context data
});

// Exporter sites data
const sites = ref([]); // Raw Sites from API
const originalSiteId = ref(''); // Original site ID for change detection
const siteOptions = ref([]); // Formatted options for dropdown
const selectedSite = ref({
  value: '',
  label: ''
});

// API endpoint URLs
const FLOWDEV_CONFIG_UPDATE_URL = `${http_prefix}/lua/pro/rest/v2/set/flowdevice/config.lua`;
const SITES_LIST_URL = `${http_prefix}/lua/pro/rest/v2/get/sites/list.lua`;
const FLOWDEV_EXPORTER_CONFIG_GET_URL = `${http_prefix}/lua/pro/rest/v2/get/flowdevice/config.lua?flowdev_ip=${getDeviceIpFromUrl()}&ifid=${props.context.ifid}`;

/**
 * Vue lifecycle hook: Called when component is mounted to DOM
 * Loads initial data for the form
 */
onMounted(async () => {
  await loadSitesList();
  await loadFlowDeviceConfiguration();
});

/**
 * Extracts the device IP address from URL parameters
 * 
 * @returns {string} The IP address from URL
 */
function getDeviceIpFromUrl() {
  return ntopng_url_manager.get_url_entry('ip')
}

/**
 * Loads the current flow device alias from the server
 * and populates the input field with the value
 */
async function loadFlowDeviceConfiguration() {
  const response = await ntopng_utility.http_request(`${FLOWDEV_EXPORTER_CONFIG_GET_URL}`, {
    method: 'get'
  });

  // Use response alias or fallback to device IP
  if (response) {
    // Get the Alias
    const ip = getDeviceIpFromUrl()
    const aliasValue = response.alias || ip;
    aliasInput.value.value = aliasValue;
    originalAlias.value = aliasValue;

    // Get the Ssite
    if (response.site && response.site.id) {
      selectedSite.value = {
        value: response.site.id,
        label: response.site.name
      };
    } else {
      // No site found, use the default one, that is in the first position of the entire list
      selectedSite.value = siteOptions.value[0]
    }
    originalSiteId.value = selectedSite.value.value;
  }
}

/**
 * Saves the updated flow device settings (alias and Site)
 * to the server and disables the save button on success
 */
const saveFlowDeviceSettings = async function () {
  const requestData = {
    csrf: props.context.csrf,
    ip: ntopng_url_manager.get_url_entry('ip'),
    site_id: selectedSite.value.value,
    alias: aliasInput.value.value,
    ifid: props.context.ifid,
  };

  const requestHeaders = {
    'Content-Type': 'application/json'
  };

  await ntopng_utility.http_request(
    FLOWDEV_CONFIG_UPDATE_URL,
    {
      method: 'post',
      headers: requestHeaders,
      body: JSON.stringify(requestData)
    }
  );

  // Update original values and disable save button
  originalAlias.value = aliasInput.value.value;
  originalSiteId.value = selectedSite.value.value;
  isSaveDisabled.value = true;
}

/**
 * Validates whether form has been modified and updates save button state
 * Compares current values with original values to detect changes
 */
const validateFormChanges = function () {
  const isAliasChanged = originalAlias.value !== aliasInput.value.value;
  const isSiteChanged = originalSiteId.value !== selectedSite.value.value;

  isSaveDisabled.value = !(isAliasChanged || isSiteChanged);
}

/**
 * Loads the list of available Sites from the server
 * and sets up the dropdown options
 */
async function loadSitesList() {
  const response = await ntopng_utility.http_request(
    SITES_LIST_URL,
    { method: 'get' }
  );

  sites.value = response || [];
  const tmpSites = sites.value.map(site => ({
    value: site.id,
    label: site.name
  }));
  
  siteOptions.value = [
    tmpSites.find(e => e.value == 0),
    ...tmpSites.filter(site => site.value != 0).sort(sortByLabel)
  ];
}

function sortByLabel(a, b) {
  return a.label.localeCompare(b.label, 'it', { sensitivity: 'base' });
}

/**
 * Handles selection of a Site from the dropdown
 * 
 * @param {Object} option - Selected option object with value and label
 */
function handleSiteSelect(option) {
  selectedSite.value = {
    value: option.value,
    label: option.label
  };
  validateFormChanges();
}

</script>