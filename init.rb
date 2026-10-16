require 'redmine'

# Подключаем расширение помощника для изменения группы фильтров родительской задачи.
require_relative 'lib/redmine_hierarchy_sort/queries_helper_patch'

# Блок 1: Регистрация плагина в Redmine
Redmine::Plugin.register :redmine_hierarchy_sort do
  name 'Иерархия задач с сортировкой и связями'
  author 'Андрей Якушев'
  author_url 'https://a2ya.ru'
  url 'https://github.com/selfauthor/redmine_hierarchy_sort'
  description 'Плагин для иерархической сортировки задач с сохранением древовидной структуры и визуализацией связей'
  version '2.0.5'
  requires_redmine :version_or_higher => '5.0.0'
end

# Блок 2: Инициализация после загрузки всего приложения (Rails 7 + Zeitwerk)
Rails.application.config.after_initialize do
  # Блок 3: Патчим модель Query — добавляем опции иерархии и show_relations
  unless Query.instance_methods.include?(:hierarchy_enabled)
    Query.send(:include, RedmineHierarchySort::QueryPatch)
  end

  # Блок 4: Патчим модель IssueQuery — переопределяем выборку задач и подсчет
  unless IssueQuery.instance_methods.include?(:issues_with_hierarchy)
    IssueQuery.send(:include, RedmineHierarchySort::IssueQueryPatch)
  end

  # Блок 5: Подключаем хелпер во все view-контексты
  if defined?(HierarchySortHelper)
    # Включение в базовый класс гарантирует доступность во ВСЕХ view
    unless ActionView::Base.included_modules.include?(HierarchySortHelper)
      ActionView::Base.send(:include, HierarchySortHelper)
    end
  end

  # Блок 6: Переопределяем группировку фильтров родительской задачи.
  QueriesHelper.prepend(RedmineHierarchySort::QueriesHelperPatch)

end
# v2610161152