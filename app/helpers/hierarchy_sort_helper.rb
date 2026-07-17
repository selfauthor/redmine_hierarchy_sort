# app/helpers/hierarchy_sort_helper.rb
module HierarchySortHelper
  # Функция: Рендеринг иконки связей для задачи
  # Блок 1: Иконка показывается только если включена опция show_relations и у задачи есть связи
  def render_relation_icon(issue)
    return '' unless @query&.show_relations && issue.relations.present?
    render partial: 'issues/relation_icon', locals: { issue: issue }
  end

  # Функция: Рендеринг popover со списком связей
  # Блок 2: Вызываем группировку связей и передаем результат в partial
  def render_relation_popover(issue)
    return '' unless @query&.show_relations && issue.relations.present?
    groups = group_relations_by_type(issue)
    render partial: 'issues/relation_popover', locals: { issue: issue, groups: groups }
  end

  private

  # Функция: Группировка связей задачи по типам и направлениям
  # Блок 3: Анализируем все связи задачи и формируем структуру для отображения
  def group_relations_by_type(issue)
    groups = {}
    
    # Блок 4: Задаем порядок отображения типов связей (для стабильности UI)
    type_order = %w[relates duplicates duplicated_by blocks blocked_by precedes follows copied_to copied_from]

    issue.relations.each do |relation|
      # Блок 5: Определяем, является ли текущая задача источником (issue_from) или целью (issue_to)
      is_from = (relation.issue_from_id == issue.id)
      base_type = relation.relation_type

      # Блок 6: Определяем эффективный тип связи и направление стрелки
      if IssueRelation::TYPES[base_type][:sym]
        # Для симметричных связей (relates) направление двунаправленное
        effective_type = base_type
        direction = 'bidirectional'
      else
        if is_from
          effective_type = base_type
          direction = 'outgoing'
        else
          # Для входящих связей используем обратный тип (например, blocked_by вместо blocks)
          effective_type = IssueRelation::TYPES[base_type][:reverse]
          direction = 'incoming'
        end
      end

      # Блок 7: Получаем связанную задачу (противоположную текущей)
      other_issue = is_from ? relation.issue_to : relation.issue_from
      next unless other_issue&.visible? # Проверка видимости для безопасности

      # Блок 8: Добавляем связь в соответствующую группу
      groups[effective_type] ||= []
      groups[effective_type] << { issue: other_issue, direction: direction }
    end

    # Блок 9: Сортируем группы согласно заданному порядку
    sorted_groups = {}
    type_order.each do |type|
      sorted_groups[type] = groups[type] if groups[type].present?
    end
    
    # Блок 10: Добавляем любые новые типы связей, которые могут появиться в будущем
    (groups.keys - type_order).each do |type|
      sorted_groups[type] = groups[type]
    end

    sorted_groups
  end
end