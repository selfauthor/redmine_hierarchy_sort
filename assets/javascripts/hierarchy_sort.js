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
        $('#child_filters_fieldset, #child_sort_fieldset').slideDown(200);
      } else {
        $('#child_filters_fieldset, #child_sort_fieldset').slideUp(200);
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
  
  /**
   * Функция: Добавление фильтра подзадач (экспорт в глобальную область)
   * Блок 19: Аналог стандартной функции addFilter для фильтров подзадач
   */
  window.addHierarchyChildFilter = function(field, operator, values) {
    // Блок 20: Получаем информацию о фильтре
    var filter = childAvailableFilters[field];
    if (!filter) {
      alert('Filter not found: ' + field);
      return;
    }
    
    // Блок 21: Создаем HTML для фильтра
    var filterType = filter.type;
    var filterName = filter.name;
    var operators = childOperatorByType[filterType] || [];
    
    // Блок 22: Находим таблицу фильтров подзадач
    var $table = $('#child_filters-table');
    var index = $table.find('tr').length;
    
    // Блок 23: Создаем строку таблицы
    var $tr = $('<tr></tr>').addClass('filter').attr('id', 'child_filter_' + index);
    
    // Блок 24: Ячейка с полем
    var $tdField = $('<td></td>').addClass('field');
    $tdField.append(
      $('<span></span>').text(filterName),
      $('<input type="hidden">').attr('name', 'child_f[]').val(field)
    );
    $tr.append($tdField);
    
    // Блок 25: Ячейка с оператором
    var $tdOperator = $('<td></td>').addClass('operator');
    var $selectOperator = $('<select></select>')
      .attr('name', 'child_op[' + field + ']')
      .addClass('operator');
    
    operators.forEach(function(op) {
      var label = childOperatorLabels[op] || op;
      $selectOperator.append($('<option></option>').val(op).text(label));
    });
    
    $selectOperator.val(operator);
    $tdOperator.append($selectOperator);
    $tr.append($tdOperator);
    
    // Блок 26: Ячейка со значениями (будет заполнена позже)
    var $tdValues = $('<td></td>').addClass('values');
    $tr.append($tdValues);
    
    // Блок 27: Ячейка с кнопкой удаления
    var $tdRemove = $('<td></td>').addClass('buttons');
    $tdRemove.append(
      $('<a></a>')
        .attr('href', '#')
        .addClass('icon icon-del')
        .text('')
        .on('click', function(e) {
          e.preventDefault();
          $tr.remove();
          updateChildFiltersPlaceholder();
        })
    );
    $tr.append($tdRemove);
    
    // Блок 28: Добавляем строку в таблицу
    $table.append($tr);
    
    // Блок 29: Инициализируем значения фильтра
    initChildFilterValues(field, filterType, values);
    
    // Блок 30: Обновляем placeholder
    updateChildFiltersPlaceholder();
  };
  
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
  
})(jQuery);