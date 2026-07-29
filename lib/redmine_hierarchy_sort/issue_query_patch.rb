module RedmineHierarchySort
  module IssueQueryPatch
    extend ActiveSupport::Concern

    included do
      alias_method :issues_without_hierarchy, :issues
      alias_method :issue_count_without_hierarchy, :issue_count
      
      define_method :issues_with_hierarchy do |options={}|
        if hierarchy_enabled
          builder = RedmineHierarchySort::HierarchyBuilder.new(self, options)
          # Передаем кэшированные данные о корнях, если они есть
          builder.fetch_issues(root_data: @hierarchy_root_data)
        else
          issues_without_hierarchy(options)
        end
      end
      
      define_method :issue_count_with_hierarchy do
        if hierarchy_enabled
          # Кэшируем данные о корнях для устранения дублирования запроса
          @hierarchy_root_data ||= begin
            builder = RedmineHierarchySort::HierarchyBuilder.new(self, {})
            builder.send(:fetch_light_root_data)
          end
          
          # Определяем относительные корни и возвращаем их количество
          builder = RedmineHierarchySort::HierarchyBuilder.new(self, {})
          relative_roots = builder.send(:identify_relative_roots, @hierarchy_root_data)
          relative_roots.size
        else
          issue_count_without_hierarchy
        end
      end
      
      alias_method :issues, :issues_with_hierarchy
      alias_method :issue_count, :issue_count_with_hierarchy
    end
  end
end