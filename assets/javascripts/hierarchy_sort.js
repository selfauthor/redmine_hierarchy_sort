// assets/javascripts/hierarchy_sort.js
// JavaScript для работы UI плагина иерархической сортировки

(function($) {
  'use strict';
  
  // Инициализация при загрузке документа
  $(document).ready(function() {
    initHierarchySortUI();
  });
  
  /**
   * Функция: Инициализация UI плагина
   * Блок 1: Навешиваем обработчики событий на чекбоксы
   */
  function initHierarchySortUI() {
    // Блок 2: Обработчик изменения чекбокса "Дерево подзадач"
    var $hierarchyCheckbox = $('#query_hierarchy_enabled');
    $hierarchyCheckbox.on('change', function() {
      var isChecked = $(this).is(':checked');
      // Блок 3: Показываем/скрываем блоки фильтров и сортировки подзадач
      if (isChecked) {
        $('#child_filters_fieldset, #child_sort_fieldset').show(200);
      } else {
        $('#child_filters_fieldset, #child_sort_fieldset').hide(200);
      }
    });
    
    // Блок 4: Инициализируем состояние при загрузке страницы
    $hierarchyCheckbox.trigger('change');
    
    // Блок 5: Инициализация popover для связей (будет доработана в Части 5)
    initRelationPopovers();
  }
  
  /**
   * Функция: Инициализация popover для отображения связей
   * Блок 6: Навешиваем обработчики на иконки связей
   */
  function initRelationPopovers() {
    // Блок 7: Делегирование событий для динамически создаваемых элементов
    $(document).on('click', '.hierarchy-relation-icon', function(e) {
      e.preventDefault();
      e.stopPropagation();
      
      var $icon = $(this);
      var issueId = $icon.data('issue-id');
      
      // Блок 8: Закрываем все открытые popover
      $('.hierarchy-relation-popover').hide();
      
      // Блок 9: Показываем/скрываем popover для текущей задачи
      var $popover = $('#relation-popover-' + issueId);
      if ($popover.length) {
        toggleRelationPopover($icon, $popover);
      }
    });
    
    // Блок 10: Закрытие popover при клике вне его
    $(document).on('click', function(e) {
      if (!$(e.target).closest('.hierarchy-relation-icon, .hierarchy-relation-popover').length) {
        $('.hierarchy-relation-popover').hide();
      }
    });
    
    // Блок 11: Закрытие popover по крестику
    $(document).on('click', '.hierarchy-popover-close', function(e) {
      e.preventDefault();
      $(this).closest('.hierarchy-relation-popover').hide();
    });
  }
  
  /**
   * Функция: Переключение видимости popover
   * Блок 12: Позиционирование popover относительно иконки
   */
  function toggleRelationPopover($icon, $popover) {
    // Блок 13: Проверяем, виден ли popover
    var isVisible = $popover.is(':visible');
    
    if (isVisible) {
      $popover.hide();
    } else {
      // Блок 14: Вычисляем позицию
      var iconOffset = $icon.offset();
      var iconHeight = $icon.outerHeight();
      var iconWidth = $icon.outerWidth();
      var popoverWidth = $popover.outerWidth();
      var popoverHeight = $popover.outerHeight();
      
      // Блок 15: Определяем, показывать сверху или снизу
      var windowHeight = $(window).height();
      var scrollTop = $(window).scrollTop();
      var spaceBelow = windowHeight - (iconOffset.top - scrollTop) + iconHeight;
      var spaceAbove = iconOffset.top - scrollTop;
      
      var top, left;
      
      // Блок 16: Позиционируем влево от иконки
      left = iconOffset.left - popoverWidth - 10;
      
      // Блок 17: Выбираем направление (вверх/вниз)
      if (spaceBelow > popoverHeight || spaceAbove < popoverHeight) {
        // Показываем снизу
        top = iconOffset.top + iconHeight + 5;
      } else {
        // Показываем сверху
        top = iconOffset.top - popoverHeight - 5;
      }
      
      // Блок 18: Применяем позиционирование
      $popover.css({
        top: top + 'px',
        left: left + 'px',
        position: 'absolute',
        zIndex: 1000
      }).show();
    }
  }
  
// Функция: Добавление фильтра подзадач (полный аналог стандартной addFilter)
window.addHierarchyChildFilter = function(field, operator, values) {
  var fieldId = field.replace('.', '');
  var tr = $('#tr_child_' + fieldId);
  var filterOptions = childAvailableFilters[field];
  if (!filterOptions) return;
  
  if (filterOptions['remote'] && filterOptions['values'] == null) {
    $.getJSON(childFiltersUrl, {'name': field}).done(function(data) {
      filterOptions['values'] = data;
      window.addHierarchyChildFilter(field, operator, values);
    });
    return;
  }
  
  if (tr.length > 0) {
    tr.show();
  } else {
    buildChildFilterRow(field, operator, values);
  }
  $('#cb_child_' + fieldId).prop('checked', true);
  toggleChildFilter(field);
  toggleChildMultiSelectIconInit();
  $('#child_add_filter_select').val('').find('option').each(function() {
    if ($(this).attr('value') == field) {
      $(this).attr('disabled', true);
    }
  });
};

// Функция: Построение строки фильтра подзадач (аналог buildFilterRow)
function buildChildFilterRow(field, operator, values) {
  var fieldId = field.replace('.', '_');
  var filterTable = $("#child_filters-table");
  var filterOptions = childAvailableFilters[field];
  if (!filterOptions) return;
  
  var operators = childOperatorByType[filterOptions['type']];
  var filterValues = filterOptions['values'];
  var select;
  
  var tr = $('<div class="filter">').attr('id', 'tr_child_' + fieldId).html(
    '<div class="field"><input checked="checked" id="cb_child_' + fieldId + '" name="child_f[]" value="' + field + '" type="checkbox"><label for="cb_child_' + fieldId + '">' + filterOptions['name'] + '</label></div>' +
    '<div class="operator"><select id="operators_child_' + fieldId + '" name="child_op[' + field + ']"></select></div>' +
    '<div class="values"></div>'
  );
  
  filterTable.append(tr);
  select = tr.find('.operator select');
  operators.forEach(function(op) {
    var option = $('<option>').val(op).text(childOperatorLabels[op]);
    if (op == operator) { option.prop('selected', true); }
    select.append(option);
  });
  select.change(function(){ toggleChildOperator(field); });
  
  switch (filterOptions['type']) {
    case "list":
    case "list_with_history":
    case "list_optional":
    case "list_optional_with_history":
    case "list_status":
    case "list_subprojects":
      const iconType = values.length > 1 ? 'toggle-minus' : 'toggle-plus';
      const clonedIcon = document.querySelector('#child_icon_copy_source svg').cloneNode(true);
      updateSVGIcon(clonedIcon, iconType);
      tr.find('.values').append(
        $('<span>', { style: 'display:none;' }).append(
          $('<select>', {
            class: 'value',
            id: 'child_values_' + fieldId + '_1',
            name: 'child_v[' + field + '][]',
          }),
          '\n',
          $('<span>', { class: 'toggle-multiselect icon-only icon-' + iconType }).append(clonedIcon)
        )
      );
      select = tr.find('.values select');
      if (values.length > 1) { select.attr('multiple', true); }
      filterValues.forEach(function(filterValue) {
        var option = $('<option>');
        if ($.isArray(filterValue)) {
          option.val(filterValue[1]).text(filterValue[0]);
          if ($.inArray(filterValue[1], values) > -1) {option.prop('selected', true);}
          if (filterValue.length == 3) {
            var optgroup = select.find('optgroup').filter(function(){return $(this).attr('label') == filterValue[2]});
            if (!optgroup.length) {optgroup = $('<optgroup>').attr('label', filterValue[2]);}
            option = optgroup.append(option);
          }
        } else {
          option.val(filterValue).text(filterValue);
          if ($.inArray(filterValue, values) > -1) {option.prop('selected', true);}
        }
        select.append(option);
      });
      break;
    case "date":
    case "date_past":
      tr.find('.values').append(
        '<span style="display:none;"><input type="date" name="child_v[' + field + '][]" id="child_values_' + fieldId + '_1" size="10" class="value date_value"/></span>' +
        '<span style="display:none;"><input type="date" name="child_v[' + field + '][]" id="child_values_' + fieldId + '_2" size="10" class="value date_value"/></span>' +
        '<span style="display:none;"><input type="text" name="child_v[' + field + '][]" id="child_values_' + fieldId + '" size="3" class="value"/>' + childLabelDayPlural + '</span>'
      );
      $('#child_values_' + fieldId + '_1').val(values[0]).datepickerFallback(datepickerOptions);
      $('#child_values_' + fieldId + '_2').val(values[1]).datepickerFallback(datepickerOptions);
      $('#child_values_' + fieldId).val(values[0]);
      break;
    case "string":
    case "text":
    case "search":
      tr.find('.values').append(
        '<span style="display:none;"><input type="text" name="child_v[' + field + '][]" id="child_values_' + fieldId + '" size="30" class="value"/></span>'
      );
      $('#child_values_' + fieldId).val(values[0]);
      break;
    case "relation":
      tr.find('.values').append(
        '<span style="display:none;"><input type="text" name="child_v[' + field + '][]" id="child_values_' + fieldId + '" size="6" class="value"/></span>' +
        '<span style="display:none;"><select class="value" name="child_v[' + field + '][]" id="child_values_' + fieldId + '_1"></select></span>'
      );
      $('#child_values_' + fieldId).val(values[0]);
      select = tr.find('.values select');
      filterValues.forEach(function(filterValue) {
        var option = $('<option>');
        option.val(filterValue[1]).text(filterValue[0]);
        if (values[0] == filterValue[1]) { option.prop('selected', true); }
        select.append(option);
      });
      break;
    case "integer":
    case "float":
    case "tree":
      tr.find('.values').append(
        '<span style="display:none;"><input type="text" name="child_v[' + field + '][]" id="child_values_' + fieldId + '_1" size="14" class="value"/></span>' +
        '<span style="display:none;"><input type="text" name="child_v[' + field + '][]" id="child_values_' + fieldId + '_2" size="14" class="value"/></span>'
      );
      $('#child_values_' + fieldId + '_1').val(values[0]);
      $('#child_values_' + fieldId + '_2').val(values[1]);
      break;
  }
}

// Функция: Переключение фильтра подзадач (аналог toggleFilter)
function toggleChildFilter(field) {
  var fieldId = field.replace('.', '');
  if ($('#cb_child_' + fieldId).is(':checked')) {
    $("#operators_child_" + fieldId).show().removeAttr('disabled');
    toggleChildOperator(field);
  } else {
    $("#operators_child_" + fieldId).hide().attr('disabled', true);
    enableChildValues(field, []);
  }
}

// Функция: Включение/выключение значений фильтра подзадач (аналог enableValues)
function enableChildValues(field, indexes) {
  var fieldId = field.replace('.', '');
  $('#tr_child_' + fieldId + ' .values .value').each(function(index) {
    if ($.inArray(index, indexes) >= 0) {
      $(this).removeAttr('disabled');
      $(this).parents('span').first().show();
    } else {
      $(this).val('');
      $(this).attr('disabled', true);
      $(this).parents('span').first().hide();
    }
  });
}

// Функция: Переключение оператора фильтра подзадач (аналог toggleOperator)
function toggleChildOperator(field) {
  var fieldId = field.replace('.', '');
  var operator = $("#operators_child_" + fieldId);
  switch (operator.val()) {
    case "!":
    case "*":
    case "nd":
    case "t":
    case "ld":
    case "nw":
    case "w":
    case "lw":
    case "l2w":
    case "nm":
    case "m":
    case "lm":
    case "y":
    case "o":
    case "c":
    case "*o":
    case "!o":
      enableChildValues(field, []);
      break;
    case "><":
      enableChildValues(field, [0,1]);
      break;
    case "<t+":
    case ">t+":
    case "><t+":
    case "t+":
    case ">t-":
    case "<t-":
    case "><t-":
    case "t-":
      enableChildValues(field, [2]);
      break;
    case "=p":
    case "=!p":
    case "!p":
      enableChildValues(field, [1]);
      break;
    default:
      enableChildValues(field, [0]);
      break;
  }
}

// Функция: Инициализация иконок множественного выбора для child-фильтров
function toggleChildMultiSelectIconInit() {
  $('#child_filters-table .toggle-multiselect:not(.icon-toggle-minus):not(.icon-toggle-plus)').each(function(){
    let iconType;
    if ($(this).siblings('select').find('option:selected').length > 1) {
      iconType = 'toggle-minus';
    } else {
      iconType = 'toggle-plus';
    }
    $(this).addClass('icon-' + iconType);
    updateSVGIcon($(this).find('svg')[0], iconType);
  });
}
  
  /**
   * Функция: Инициализация значений фильтра подзадач
   * Блок 31: Создает input/select для значений в зависимости от типа фильтра
   */
  function initChildFilterValues(field, filterType, values) {
    var $tr = $('#child_filters-table tr').last();
    var $tdValues = $tr.find('td.values');
    
    // Блок 32: Создаем input для значений
    var $input = $('<input type="text">')
      .attr('name', 'child_v[' + field + '][]')
      .addClass('filter-value')
      .val(values && values[0] ? values[0] : '');
    
    $tdValues.append($input);
  }
  
  /**
   * Функция: Обновление placeholder для фильтров подзадач
   * Блок 33: Убеждаемся, что hidden field существует
   */
  function updateChildFiltersPlaceholder() {
    var $table = $('#child_filters-table');
    var $placeholder = $('#child_filters_placeholder');
    
    if ($table.find('tr.filter').length === 0) {
      $placeholder.val('');
    }
  }
  
  // Блок 34: Экспортируем функции для внешнего использования
  window.HierarchySort = {
    init: initHierarchySortUI,
    togglePopover: toggleRelationPopover
  };

  // Блок 35: Обработчик для чекбокса hierarchy_enabled (если форма уже загружена)
  $(document).on('change', '#query_hierarchy_enabled', function() {
    var isChecked = $(this).is(':checked');
    if (isChecked) {
      $('#child_filters_fieldset, #child_sort_fieldset').show();
    } else {
      $('#child_filters_fieldset, #child_sort_fieldset').hide();
    }
  });

  // Инициализация child-фильтров (аналог initFilters из application.js)
  function initChildFilters() {
    $('#child_add_filter_select').change(function() {
      var field = $(this).val();
      if (field) {
        window.addHierarchyChildFilter(field, 'o', ['']);
        $(this).val('');
      }
    });
  }

  // Вызываем initChildFilters при загрузке документа
  $(document).ready(function() {
    initChildFilters();
  });
  
})(jQuery);