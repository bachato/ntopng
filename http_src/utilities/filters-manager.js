const filters_const_dict = {};

async function get_filter_const(url_request) {
  if (filters_const_dict[url_request] == null) {
    filters_const_dict[url_request] = ntopng_utility.http_request(url_request);
  }
  const filter_consts = await filters_const_dict[url_request];
  return filter_consts;
}

const tag_operator_label_dict = {
  'eq': '=',
  'neq': '!=',
  'lt': '<',
  'gt': '>',
  'gte': '>=',
  'lte': '<=',
  'in': 'contains',
  'nin': 'does not contain',
};

const load_filters_data = async function(filters_const) {
  filters_const.filter((x) => x.label == null).forEach((x) => {
    console.error(`label not defined for filter ${JSON.stringify(x)}`); x.label = '';
  });
  filters_const.sort((a, b) => a.label.localeCompare(b.label));
  i18n_ext.tags = {};
  TAG_OPERATORS = {};
  DEFINED_TAGS = {};
  filters_const.forEach((f_def) => {
    i18n_ext.tags[f_def.id] = f_def.label;
    f_def.operators.forEach((op) => TAG_OPERATORS[op.id] = op.label);
    DEFINED_TAGS[f_def.id] = f_def.operators.map((op) => op.id);
  });
  const entries = ntopng_url_manager.get_url_entries();
  const filters = [];
  for (const [key, value] of entries) {
    const filter_def = FILTERS_CONST.find((fc) => fc.id == key);
    if (filter_def != null) {
      const options_string = value.split(',');
      options_string.forEach((opt_stirng) => {
        const [value, operator] = opt_stirng.split(';');
        if (
          operator == null || value == null || operator == '' ||
                    (filter_def.options != null && filter_def.options.find((opt) => opt.value == value) == null)
        ) {
          return;
        }
        let value_label = value;
        if (filter_def.value_type == 'array') {
		    value_label = filter_def?.options?.find((opt) => opt.value == value)?.label;
        }
        filters.push({id: filter_def.id, operator: operator, value: value, label: filter_def.label, value_label});
      });
    }
  }
  return filters;
  // "l7proto=XXX;eq"
};


function get_filters_object(filters) {
  const filters_groups = {};
  filters.forEach((f) => {
    let group = filters_groups[f.id];
    if (group == null) {
      group = [];
      filters_groups[f.id] = group;
    }
    group.push(f);
  });
  const filters_object = {};
  for (const f_id in filters_groups) {
    const group = filters_groups[f_id];
    const filter_values = group.filter((f) => f.value != null && f.operator != null && f.operator != '').map((f) => `${f.value};${f.operator}`).join(',');
    filters_object[f_id] = filter_values;
  }
  return filters_object;
}

const filtersManager = function() {
  return {
    get_filter_const,
    get_filters_object,
    load_filters_data,
    tag_operator_label_dict,
  };
}();

export default filtersManager;
