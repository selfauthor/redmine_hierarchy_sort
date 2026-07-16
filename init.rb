# redmine_hierarchy_sort/init.rb
Redmine::Plugin.register :redmine_hierarchy_sort do
  name 'Иерархия задач с сортировкой и связями'
  author 'Андрей Якушев'
  author_url 'https://a2ya.ru'
  url 'https://github.com/selfauthor/redmine_hierarchy_sort'
  description 'Плагин для иерархической сортировки задач с сохранением древовидной структуры и визуализацией связей'
  version '1.0.0'
  
  # Требования к версии Redmine
  requires_redmine :version_or_higher => '5.0.0'
  
  # Подключение патчей к моделям
  to_prepare do
    # Патч для модели Query (добавление атрибутов для иерархической сортировки)
    unless Query.respond_to?(:hierarchy_enabled)
      require_dependency 'query'
      Query.send(:include, RedmineHierarchySort::QueryPatch)
    end
    
    # Патч для модели IssueQuery (переопределение метода issues)
    unless IssueQuery.instance_methods.include?(:issues_with_hierarchy)
      require_dependency 'issue_query'
      IssueQuery.send(:include, RedmineHierarchySort::IssueQueryPatch)
    end
  end
end