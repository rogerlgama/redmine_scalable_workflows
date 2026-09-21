(function () {
  'use strict';

  function normalize(value) {
    return (value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  }

  function selectedIds(picker) {
    return Array.prototype.map.call(picker.querySelectorAll('.rsw-chip'), function (chip) {
      return String(chip.dataset.id);
    });
  }

  function hideResults(picker) {
    var results = picker.querySelector('.rsw-picker-results');
    results.hidden = true;
    results.replaceChildren();
  }

  function renderResults(picker, items, onSelect) {
    var results = picker.querySelector('.rsw-picker-results');
    results.replaceChildren();
    items.forEach(function (item) {
      var button = document.createElement('button');
      button.type = 'button';
      button.className = 'rsw-result';
      button.textContent = item.name;
      button.addEventListener('click', function () { onSelect(item); });
      results.appendChild(button);
    });
    results.hidden = items.length === 0;
  }

  function addValue(picker, item) {
    var currentIds = selectedIds(picker);
    if (currentIds.indexOf(String(item.id)) !== -1) return false;
    if (String(item.id) === 'all' || currentIds.indexOf('all') !== -1) clearValues(picker);
    var chips = picker.querySelector('.rsw-picker-chips');
    var chip = document.createElement('span');
    chip.className = 'rsw-chip';
    chip.dataset.id = item.id;
    chip.appendChild(document.createTextNode(item.name));
    var remove = document.createElement('button');
    remove.type = 'button';
    remove.className = 'rsw-remove';
    remove.setAttribute('aria-label', 'Remover');
    remove.textContent = '×';
    chip.appendChild(remove);
    var hidden = document.createElement('input');
    hidden.type = 'hidden';
    hidden.name = picker.dataset.paramName;
    hidden.value = item.id;
    hidden.className = 'rsw-picker-value';
    if (picker.dataset.formId) hidden.setAttribute('form', picker.dataset.formId);
    chips.appendChild(chip);
    chips.appendChild(hidden);
    if (picker.dataset.mirrorParamName) {
      var mirror = document.createElement('input');
      mirror.type = 'hidden';
      mirror.name = picker.dataset.mirrorParamName;
      mirror.value = item.id;
      mirror.className = 'rsw-picker-value';
      if (picker.dataset.formId) mirror.setAttribute('form', picker.dataset.formId);
      chips.appendChild(mirror);
    }
    return true;
  }

  function clearValues(picker) {
    picker.querySelectorAll('.rsw-chip, .rsw-picker-value').forEach(function (element) {
      element.remove();
    });
  }

  function removeValue(picker, chip) {
    var id = String(chip.dataset.id);
    var hidden = Array.prototype.find.call(picker.querySelectorAll('.rsw-picker-value'), function (input) {
      return String(input.value) === id;
    });
    if (hidden) hidden.remove();
    chip.remove();
  }

  function bindRemoval(picker, submitAfter) {
    picker.addEventListener('click', function (event) {
      var remove = event.target.closest('.rsw-remove');
      if (!remove || !picker.contains(remove)) return;
      removeValue(picker, remove.closest('.rsw-chip'));
      if (submitAfter) {
        var targetForm = picker.dataset.formId ? document.getElementById(picker.dataset.formId) : picker.closest('form');
        targetForm.submit();
      }
    });
  }

  function multiselectValues(picker) {
    return Array.prototype.map.call(picker.querySelectorAll('.rsw-multiselect-value'), function (input) {
      return {id: String(input.value), name: input.dataset.label || input.value};
    });
  }

  function updateMultiselectSummary(picker) {
    var selected = multiselectValues(picker);
    var summary = picker.querySelector('.rsw-multiselect-summary');
    if (selected.length === 0) {
      summary.textContent = picker.dataset.placeholder;
      summary.classList.add('rsw-placeholder');
    } else if (selected.length === 1) {
      summary.textContent = selected[0].name;
      summary.classList.remove('rsw-placeholder');
    } else {
      summary.textContent = selected.length + ' ' + picker.dataset.selectedLabel;
      summary.classList.remove('rsw-placeholder');
    }
  }

  function setMultiselectValue(picker, item, checked) {
    var values = picker.querySelector('.rsw-multiselect-values');
    var current = multiselectValues(picker);
    if (checked && String(item.id) === 'all') {
      values.replaceChildren();
    } else if (checked && current.some(function (entry) { return entry.id === 'all'; })) {
      values.replaceChildren();
    }

    var existing = Array.prototype.find.call(values.querySelectorAll('.rsw-multiselect-value'), function (input) {
      return String(input.value) === String(item.id);
    });
    if (checked && !existing) {
      var hidden = document.createElement('input');
      hidden.type = 'hidden';
      hidden.name = picker.dataset.paramName;
      hidden.value = item.id;
      hidden.dataset.label = item.name;
      hidden.className = 'rsw-multiselect-value';
      values.appendChild(hidden);
    } else if (!checked && existing) {
      existing.remove();
    }
  }

  function renderMultiselectOptions(picker, query) {
    var items = JSON.parse(picker.querySelector('.rsw-picker-data').textContent || '[]');
    var selected = multiselectValues(picker).map(function (item) { return item.id; });
    var options = picker.querySelector('.rsw-multiselect-options');
    var normalizedQuery = normalize(query || '');
    options.replaceChildren();

    items.filter(function (item) {
      return !normalizedQuery || normalize(item.name).indexOf(normalizedQuery) !== -1;
    }).forEach(function (item) {
      var label = document.createElement('label');
      label.className = 'rsw-multiselect-option';
      var checkbox = document.createElement('input');
      checkbox.type = 'checkbox';
      checkbox.checked = selected.indexOf(String(item.id)) !== -1;
      checkbox.addEventListener('change', function () {
        setMultiselectValue(picker, item, checkbox.checked);
        updateMultiselectSummary(picker);
        renderMultiselectOptions(picker, picker.querySelector('.rsw-multiselect-search').value);
      });
      label.appendChild(checkbox);
      label.appendChild(document.createTextNode(item.name));
      options.appendChild(label);
    });
  }

  function initializeMultiselect(picker) {
    if (picker.dataset.initialized) return;
    picker.dataset.initialized = '1';
    var toggle = picker.querySelector('.rsw-multiselect-toggle');
    var panel = picker.querySelector('.rsw-multiselect-panel');
    var search = picker.querySelector('.rsw-multiselect-search');
    updateMultiselectSummary(picker);
    renderMultiselectOptions(picker, '');

    toggle.addEventListener('click', function () {
      panel.hidden = !panel.hidden;
      toggle.setAttribute('aria-expanded', panel.hidden ? 'false' : 'true');
      if (!panel.hidden) {
        search.focus();
        renderMultiselectOptions(picker, search.value);
      }
    });
    search.addEventListener('input', function () {
      renderMultiselectOptions(picker, search.value);
    });
  }

  function initializeRemotePicker(picker) {
    if (picker.dataset.initialized) return;
    picker.dataset.initialized = '1';
    var input = picker.querySelector('.rsw-picker-search');
    var addButton = picker.querySelector('.rsw-add-status');
    var timer;
    var controller;
    var selectedItem = null;
    addButton.disabled = true;
    input.addEventListener('input', function () {
      selectedItem = null;
      addButton.disabled = true;
      clearTimeout(timer);
      var query = input.value.trim();
      if (!query) return hideResults(picker);
      timer = setTimeout(function () {
        if (controller) controller.abort();
        controller = new AbortController();
        var url = new URL(picker.dataset.url, window.location.origin);
        url.searchParams.set('q', query);
        url.searchParams.set('axis', picker.dataset.axis);
        (picker.dataset.trackers || '').split(',').filter(Boolean).forEach(function (id) {
          url.searchParams.append('tracker_ids[]', id);
        });
        fetch(url.toString(), {headers: {'Accept': 'application/json'}, signal: controller.signal})
          .then(function (response) { return response.json(); })
          .then(function (payload) {
            var selected = selectedIds(picker);
            var items = (payload.results || []).filter(function (item) {
              return selected.indexOf(String(item.id)) === -1;
            });
            renderResults(picker, items, function (item) {
              selectedItem = item;
              input.value = item.name;
              addButton.disabled = false;
              hideResults(picker);
            });
          })
          .catch(function (error) {
            if (error.name !== 'AbortError') hideResults(picker);
          });
      }, 250);
    });
    addButton.addEventListener('click', function () {
      if (!selectedItem || !addValue(picker, selectedItem)) return;
      var targetForm = picker.dataset.formId ? document.getElementById(picker.dataset.formId) : picker.closest('form');
      targetForm.submit();
    });
    bindRemoval(picker, true);
  }

  function setTransitionState(checkbox, checked) {
    var cell = checkbox.closest('.rsw-transition-cell');
    var value = cell.querySelector('.rsw-transition-value');
    checkbox.indeterminate = false;
    checkbox.checked = checked;
    value.value = checked ? '1' : '0';
    checkbox.dataset.state = value.value;
    cell.classList.toggle('rsw-enabled', checked);
    cell.classList.remove('rsw-partial');
  }

  function initializeTransitionStates() {
    document.querySelectorAll('.rsw-transition-checkbox').forEach(function (checkbox) {
      if (checkbox.dataset.initialized) return;
      checkbox.dataset.initialized = '1';
      var cell = checkbox.closest('.rsw-transition-cell');
      checkbox.indeterminate = checkbox.dataset.state === 'no_change';
      cell.classList.toggle('rsw-enabled', checkbox.dataset.state === '1');
      cell.classList.toggle('rsw-partial', checkbox.dataset.state === 'no_change');
      checkbox.addEventListener('change', function () {
        setTransitionState(checkbox, checkbox.checked);
      });
    });
  }

  function initializeBulkTransitionToggles() {
    document.querySelectorAll('.rsw-bulk-toggle').forEach(function (button) {
      if (button.dataset.initialized) return;
      button.dataset.initialized = '1';
      button.addEventListener('click', function () {
        var matrix = button.closest('.rsw-split-matrix');
        var direction = button.dataset.direction;
        var statusId = String(button.dataset.statusId);
        var rule = String(button.dataset.rule);
        var targets = Array.prototype.filter.call(matrix.querySelectorAll('.rsw-transition-checkbox'), function (checkbox) {
          if (String(checkbox.dataset.rule) !== rule) return false;
          return direction === 'source' ? String(checkbox.dataset.sourceId) === statusId :
            String(checkbox.dataset.destinationId) === statusId;
        });
        if (targets.length === 0) return;
        var shouldSelect = targets.some(function (checkbox) {
          return !checkbox.checked || checkbox.indeterminate;
        });
        targets.forEach(function (checkbox) { setTransitionState(checkbox, shouldSelect); });
      });
    });
  }

  function initialize() {
    document.querySelectorAll('.rsw-multiselect').forEach(initializeMultiselect);
    document.querySelectorAll('.rsw-remote-picker').forEach(initializeRemotePicker);
    initializeTransitionStates();
    initializeBulkTransitionToggles();
    var editButton = document.getElementById('rsw-edit-selection');
    if (editButton && !editButton.dataset.initialized) {
      editButton.dataset.initialized = '1';
      editButton.addEventListener('click', function () {
        var form = editButton.closest('form');
        form.querySelectorAll('input[name="axes_initialized"], input[name="source_status_ids[]"], input[name="destination_status_ids[]"]').forEach(function (input) {
          input.remove();
        });
        document.querySelectorAll('input[form="rsw-selection-form"][name="source_status_ids[]"], input[form="rsw-selection-form"][name="destination_status_ids[]"]').forEach(function (input) {
          input.remove();
        });
      });
    }
  }

  document.addEventListener('click', function (event) {
    document.querySelectorAll('.rsw-remote-picker').forEach(function (picker) {
      if (!picker.contains(event.target)) hideResults(picker);
    });
    document.querySelectorAll('.rsw-multiselect').forEach(function (picker) {
      if (!picker.contains(event.target)) picker.querySelector('.rsw-multiselect-panel').hidden = true;
    });
  });
  document.addEventListener('DOMContentLoaded', initialize);
  document.addEventListener('turbo:load', initialize);
}());
