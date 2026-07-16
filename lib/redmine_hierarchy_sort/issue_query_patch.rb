# lib/redmine_hierarchy_sort/issue_query_patch.rb
module RedmineHierarchySort
  module IssueQueryPatch
    extend ActiveSupport::Concern

    included do
      # Блок 1: Здесь в Части 6 мы переопределим метод issues
      # для интеграции алгоритма иерархической выборки.
      # Пока оставляем модуль пустым, чтобы не ломать стандартную логику.
    end
  end
end