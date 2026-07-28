# lib/redmine_hierarchy_sort/issue_query_patch.rb
module RedmineHierarchySort
  module IssueQueryPatch
    extend ActiveSupport::Concern

    included do
      # Патчим метод issues для использования нашего алгоритма
      alias_method :issues_without_hierarchy, :issues
      alias_method :issue_count_without_hierarchy, :issue_count

      # Определяем новый метод issues
      define_method :issues_with_hierarchy do |options={}|
        if hierarchy_enabled
          # Блок 1: Если включено дерево, используем наш билдер
          builder = RedmineHierarchySort::HierarchyBuilder.new(self, options)
          builder.fetch_issues
        else
          # Блок 2: Иначе работаем как стандартный Redmine
          issues_without_hierarchy(options)
        end
      end

      # Определяем новый метод issue_count
      define_method :issue_count_with_hierarchy do
        if hierarchy_enabled
          # Блок 3: Для корректной пагинации нам нужно знать количество корней, а не всех задач
          # Создаем билдер и вызываем его приватные методы для подсчета относительных корней
          builder = RedmineHierarchySort::HierarchyBuilder.new(self, {})
          root_data = builder.send(:fetch_light_root_data)
          relative_roots = builder.send(:identify_relative_roots, root_data)
          relative_roots.size
        else
          issue_count_without_hierarchy
        end
      end

      # Теперь создаем алиасы
      alias_method :issues, :issues_with_hierarchy
      alias_method :issue_count, :issue_count_with_hierarchy
    end
  end
end