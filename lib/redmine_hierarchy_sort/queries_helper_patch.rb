# frozen_string_literal: true

# Расширение штатного помощника Redmine для формирования списка фильтров.
# Изменяет заголовок группы фильтров родительской задачи,
# не затрагивая локализацию родительского проекта в других местах.
module RedmineHierarchySort
  module QueriesHelperPatch
    # Формирует HTML-список доступных фильтров запроса.
    # Параметр query — объект запроса Redmine, содержащий доступные фильтры.
    # Для фильтров parent.* используется отдельный ключ локализации,
    # а для всех остальных сохраняется штатная группировка Redmine.
    def filters_options_for_select(query)
      ungrouped = []

      # Сохраняем штатные группы фильтров Redmine.
      grouped = {
        label_string: [],
        label_date: [],
        label_time_tracking: [],
        label_attachment: []
      }

      query.available_filters.map do |field, field_options|
        if /^cf_\d+\./.match?(field)
          group = (field_options[:through] || field_options[:field]).try(:name)
        elsif field =~ /^(.+)\./
          # Для фильтров родительской задачи используем отдельную группу.
          # Для остальных ассоциативных фильтров сохраняем штатный ключ.
          group =
            if $1 == 'parent'
              :label_parent_issue_filters
            else
              :"field_#{$1}"
            end
        elsif field_options[:type] == :relation
          group = :label_relations
        elsif field_options[:type] == :tree
          group = query.is_a?(IssueQuery) ? :label_relations : nil
        elsif %w(member_of_group assigned_to_role).include?(field)
          group = :field_assigned_to
        elsif field_options[:type] == :date_past || field_options[:type] == :date
          group = :label_date
        elsif %w(estimated_hours spent_time).include?(field)
          group = :label_time_tracking
        elsif %w(attachment attachment_description).include?(field)
          group = :label_attachment
        elsif [:string, :text, :search].include?(field_options[:type])
          group = :label_string
        end

        # Помещаем фильтр в соответствующую группу или в общий список.
        if group
          (grouped[group] ||= []) << [field_options[:name], field]
        else
          ungrouped << [field_options[:name], field]
        end
      end

      # Удаляем группы, в которых нет доступных фильтров.
      grouped.delete_if { |_key, values| values.empty? }

      # Если фильтр даты всего один, показываем его без отдельной группы.
      if grouped[:label_date].try(:size) == 1
        ungrouped << grouped.delete(:label_date).first
      end

      # Формируем HTML-список, сохраняя штатный механизм Redmine.
      result = options_for_select([[]] + ungrouped)

      if grouped.present?
        localized_grouped = grouped.map do |key, values|
          [key.is_a?(Symbol) ? l(key) : key.to_s, values]
        end

        result << grouped_options_for_select(localized_grouped)
      end

      result
    end
  end
end
# v2610161145