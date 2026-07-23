# lib/redmine_hierarchy_sort/query_patch.rb
module RedmineHierarchySort
  module QueryPatch
    extend ActiveSupport::Concern

    included do
      # Блок 1: Геттеры и сеттеры для опций
      # Они определяются здесь, чтобы стать методами экземпляра класса Query
      def hierarchy_enabled
        options[:hierarchy_enabled] == true || options[:hierarchy_enabled] == '1'
      end

      def hierarchy_enabled=(arg)
        options[:hierarchy_enabled] = (arg == true || arg == '1' ? true : false)
      end

      def show_relations
        options[:show_relations] == true || options[:show_relations] == '1'
      end

      def show_relations=(arg)
        options[:show_relations] = (arg == true || arg == '1' ? true : false)
      end

      def child_filters
        options[:child_filters] || {}
      end

      def child_filters=(arg)
        options[:child_filters] = arg
      end

      def child_sort_criteria
        options[:child_sort_criteria] || []
      end

      def child_sort_criteria=(arg)
        options[:child_sort_criteria] = arg
      end

      # Блок 2: Переопределение методов через alias_method
      # Важно: alias_method должен быть внутри included, чтобы сработать после загрузки модуля
      alias_method :build_from_params_without_hierarchy_sort, :build_from_params
      alias_method :build_from_params, :build_from_params_with_hierarchy_sort
    end

    # Блок 3: Новые методы (они автоматически станут instance methods благодаря Concern)
    
    # Переопределение build_from_params для чтения наших параметров из формы
    def build_from_params_with_hierarchy_sort(params, defaults={})
      # Вызываем оригинальный метод Redmine (сохраненный через alias)
      build_from_params_without_hierarchy_sort(params, defaults)

      # Определяем источник параметров
      query_params = params[:query] || {}

      # Читаем булевы флаги
      self.hierarchy_enabled = query_params[:hierarchy_enabled] || params[:hierarchy_enabled]
      self.show_relations = query_params[:show_relations] || params[:show_relations]

      # Обработка фильтров подзадач
      if params[:child_f] || query_params[:child_f]
        fields = params[:child_f] || query_params[:child_f]
        operators = params[:child_op] || query_params[:child_op] || {}
        values = params[:child_v] || query_params[:child_v] || {}
        self.child_filters = {}
        add_child_filters(fields, operators, values)
      end

      # Обработка сортировки подзадач
      if params[:child_sort].present? || query_params[:child_sort].present?
        sort_param = params[:child_sort] || query_params[:child_sort]
        self.child_sort_criteria = Redmine::SortCriteria.new(sort_param).to_a
      end

      self
    end

    # Вспомогательный метод для парсинга фильтров подзадач
    def add_child_filters(fields, operators, values)
      return unless fields.present? && operators.present?
      fields.each do |field|
        if available_filters.has_key?(field)
          child_filters[field] = {
            :operator => operators[field],
            :values => (values[field] || [''])
          }
        end
      end
    end
  end
end