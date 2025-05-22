// 2016-19 - ntop.org

export function datatableRemoveEmptyRow(table) {
  $('tbody tr.emptyRow', $(table)).remove();
}

export function datatableAddEmptyRow(table, empty_str) {
  const columns = $('thead th', $(table)).filter(function() {
    return $(this).css('display') != 'none';
  }).length;
  $('tbody', $(table)).html('<tr class="emptyRow"><td colspan="' + columns + '"><i>' + empty_str + '</i></td></tr>');
}

export function datatableGetNumDisplayedItems(table) {
  return $('tr:not(.emptyRow)', $(table)).length - 1;
}

export function datatableIsEmpty(table) {
  return datatableGetNumDisplayedItems(table) == 0;
}

export function datatableGetByForm(form) {
  return $('table', $('#dt-top-details', $(form)).parent());
}

export function datatableUndoAddRow(new_row, empty_str, bt_to_enable, callback_str) {
  if (bt_to_enable) {
    $(bt_to_enable).removeAttr('disabled').removeClass('disabled');
  }

  const form = $(new_row).closest('form');
  $(new_row).remove();
  aysUpdateForm(form);
  const dt = datatableGetByForm(form);

  if (datatableIsEmpty(dt)) {
    datatableAddEmptyRow(dt, empty_str);
  }

  if (callback_str)
  // invoke
  {
    window[callback_str](new_row);
  }
}

export function datatableForEachRow(table, callbacks) {
  $('tr:not(:first)', table).each(function(row_i) {
    if (typeof callbacks === 'function') {
      callbacks.bind(this)(row_i);
    } else {
      let i;
      for (i=0; i<callbacks.length; i++) {
        callbacks[i].bind(this)(row_i);
      }
    }
  });
}

export function datatableAddButtonCallback(td_idx, label, bs_class, callback_str, link, visible = true, title = '') {
  if ($('td:nth-child('+td_idx+')', $(this)).find('div.d-flex').length == 0) {
    $('td:nth-child('+td_idx+')', $(this)).empty();
    $('td:nth-child('+td_idx+')', $(this)).append($('<div class=\'d-flex justify-content-center\'></div>'));
  }
  $('td:nth-child('+td_idx+')', $(this)).find('.d-flex').append('<a href="' + link + `" title='${title}' data-placement="bottom" class="btn btn-sm mx-1 ${bs_class} ${!visible ? 'disabled' : ''}" onclick="` + callback_str + '" role="button">' + label + '</a>');
}

export function datatableAddDeleteButtonCallback(td_idx, callback_str, label) {
  datatableAddButtonCallback.bind(this)(td_idx, label, 'btn-danger', callback_str, 'javascript:void(0)', true, 'Delete');
}

export function datatableAddActionButtonCallback(td_idx, callback_str, label, visible = true, title = '') {
  datatableAddButtonCallback.bind(this)(td_idx, label, 'btn-info', callback_str, 'javascript:void(0)', visible, title);
}

export function datatableAddFilterButtonCallback(td_idx, callback_str, label, title = '', visible = true) {
  datatableAddButtonCallback.bind(this)(td_idx, label, 'btn-warning', callback_str, 'javascript:void(0)', visible, title);
}

export function datatableAddLinkButtonCallback(td_idx, link, label, title = '') {
  datatableAddButtonCallback.bind(this)(td_idx, label, 'btn-primary', '', link, true, title);
}

export function datatableMakeSelectUnique(tr_obj, added_rows_prefix, options) {
  options = NtopUtils.paramsExtend({
    on_change: $.noop, /* A callback to be called when the select input changes */
    selector_fn: function(obj) {/* A callback which receives a tr object and returns a single select input */
      return obj.find('select').first();
    },
  }, options);

  function datatableForeachSelectOtherThan(this_select, added_rows_prefix, selector_fn, callback) {
    $('[id^=' + added_rows_prefix + ']').each(function() {
      const other = selector_fn($(this));
      if (other[0] != this_select[0]) {
        callback(other);
      }
    });
  }

  function datatableOptionChangeStatus(option_obj, enable) {
    if (enable) {
      option_obj.removeAttr('disabled');
    } else {
      const select_obj = option_obj.closest('select');
      const should_reset = (select_obj.val() == option_obj.val());
      option_obj.attr('disabled', 'disabled');

      if (should_reset) {
        const new_val = select_obj.find('option:not([disabled])').first().val();
        select_obj.val(new_val);
        select_obj.attr('data-old-val', new_val);
      }
    }
  }

  function datatableOnSelectEntryChange(added_rows_prefix, selector_fn, change_callback) {
    let old_value = $(this).attr('data-old-val') || '';
    const new_value = $(this).val() || '';
    const others = [];

    if (old_value == new_value) {
      old_value = '';
    }

    datatableForeachSelectOtherThan($(this), added_rows_prefix, selector_fn, function(other) {
      datatableOptionChangeStatus(other.find('option[value=\'' + old_value + '\']'), true);
      datatableOptionChangeStatus(other.find('option[value=\'' + new_value + '\']'), false);
      others.push(other);
    });

    change_callback($(this), old_value, new_value, others, datatableOptionChangeStatus);

    $(this).attr('data-old-val', new_value);
  }

  function datatableOnAddSelectEntry(select_obj, added_rows_prefix, selector_fn) {
    select_obj.val('');

    // Trigger an update on other inputs in order to disable entries on the select_obj
    datatableForeachSelectOtherThan(select_obj, added_rows_prefix, selector_fn, function(other) {
      // datatableOptionChangeStatus(select_obj.find("option[value='" + other.val() + "']"), false);
      other.trigger('change');
    });

    // select first available entry
    const new_sel = select_obj.find('option:not([disabled])').first();
    const new_val = new_sel.val();

    // trigger change event to update other entries
    select_obj.val(new_val);
    select_obj.trigger('change');
  }

  const select = options.selector_fn(tr_obj);
  select.on('change', function() {
    datatableOnSelectEntryChange.bind(this)(added_rows_prefix, options.selector_fn, options.on_change);
  });
  select.on('remove', function() {
    $(this).val('').trigger('change');
  });
  datatableOnAddSelectEntry(select, added_rows_prefix, options.selector_fn);
}

export function datatableIsLastPage(table) {
  const lastpage = $('#dt-bottom-details .pagination li:nth-last-child(3)', $(table));
  return !((lastpage.length == 1) && (lastpage.hasClass('active') == false));
}

export function datatableGetColumn(table, id_key, id_value) {
  const res = table.data('datatable').resultset.data.filter(function(item) {
    return item[id_key] === id_value;
  });

  if (res) return res[0];
}

export function datatableGetColumnIndex(table, column_key) {
  const index = table.data('datatable').options.columns.findIndex(function(item) {
    return item.field === column_key;
  });

  return (index);
}

/*
 * Helper function to add refreshable datatables rows.
 *
 * table: the datatable div jquery object
 * column_id: the field key used to indentify the rows
 * refresh_interval: milliseconds refresh interval for this table
 * trend_columns: (optional) a map <field -> formatter_fn> which indicates the numeric columns
 * which should be shown with up/down arrows upon refresh.
 *
 * Returns true on success, false otherwise.
 *
 * Example usage:
 *   $("#table-redis-stats").datatable({
 *     ...
 *     tableCallback: function() {
 *       // The table rows will be identified by the "column_key",
 *       // refreshed every 5 seconds, with up/down arrows on the "column_hits"
 *       datatableInitRefreshRows($("#table-redis-stats"), "column_key", 5000, {"column_hits": addCommas});
 *     }
 *   });
 */
export function datatableInitRefreshRows(table, column_id, refresh_interval, trend_columns) {
  const $dt = table.data('datatable');
  const rows = $dt.resultset.data;
  const old_timer = table.data('dt-rr-timer');
  const old_req = table.data('dt-rr-ajax');
  trend_columns = trend_columns || {};

  if (old_timer) {
    // Remove the previously set timer to avoid double scheduling
    clearInterval(old_timer);
    table.removeData('dt-rr-timer');
  }

  if (old_req) {
    // Abort the previous request if any
    old_req.abort();
    table.removeData('dt-rr-ajax');
  }

  const ids = [];
  const id_to_row = {};

  for (const row in rows) {
    const data = rows[row];

    if (data[column_id]) {
      const data_id = data[column_id];
      id_to_row[data_id] = row;
      ids.push(data_id);
    }
  }

  // These parameters will be passed to the refresh endpoint
  // the custom_hosts parameter will be passed in the AJAX request and
  // will contain the IDs to refresh. It should be used by the receiving
  // Lua script as a filter
  const params = {
    'custom_hosts': ids.join(','),
  };
  const url = $dt.options.url;
  let first_load = true;

  const _process_result = function(result) {
    if (typeof(result) === 'string') {
      result = JSON.parse(result);
    }

    if (!result) {
      console.error('Bad JSON result');
      return;
    }

    for (const row in result.data) {
      const data = result.data[row];
      const data_id = data[column_id];

      if (data_id && id_to_row[data_id]) {
        const row_idx = id_to_row[data_id];
        const row_html = $dt.rows[row_idx];
        const row_tds = $('td', row_html);

        /* Try to update all the fields for the current row (row_html) */
        for (const key in data) {
          const col_idx = datatableGetColumnIndex(table, key);
          const cell = row_tds[col_idx];
          const $cell = $(cell);

          const old_val = $cell.data('dt-rr-cur-val') || $(cell).html();
          const trend_value_formatter = trend_columns[key];
          let new_val = data[key];
          let arrows = '';

          if (trend_value_formatter) {
            if (parseFloat(new_val) != new_val) {
              console.warn('Invalid number: ' + new_val);
            }

            if (!first_load) {
              arrows = ' ' + NtopUtils.drawTrend(parseFloat(new_val), parseFloat(old_val));
            }

            // This value will be neede in the next refresh
            $cell.data('dt-rr-cur-val', new_val);

            new_val = trend_value_formatter(new_val);
          }

          $(cell).html((new_val != 0) ? (new_val + arrows) : '');
        }
      }
    }

    first_load = false;
    table.removeData('dt-rr-ajax');
  };

  // Save the timer into "dt-rr-timer" to be able to stop it if
  // datatableInitRefreshRows is called again
  table.data('dt-rr-timer', setInterval(function() {
    // Double check that a request is not pending
    const old_req = table.data('dt-rr-ajax');

    if (old_req) {
      return;
    }

    // Save the ajax request to possibly abort it if
    // datatableInitRefreshRows is called again
    table.data('dt-rr-ajax', $.ajax({
      type: 'GET',
      url: url,
      data: params,
      cache: false,
      success: _process_result,
    }));
  }, refresh_interval));

  // First update
  _process_result($dt.resultset);
}
