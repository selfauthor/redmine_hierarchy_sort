# lib/redmine_hierarchy_sort/query_patch.rb
module RedmineHierarchySort
  module QueryPatch
    extend ActiveSupport::Concern

    included do
      # Все настройки хранятся в поле options (Hash)

      # --- Геттеры и сеттеры для опций ---

      # Функция: Проверка включено ли дерево подзадач
      define_method :hierarchy_enabled do
        options[:hierarchy_enabled] == true || options[:hierarchy_enabled] == '1'
      end

      # Функция: Установка состояния дерева подзадач
      define_method :hierarchy_enabled= do |arg|
        options[:hierarchy_enabled] = (arg == true || arg == '1' ? true : false)
      end

      # Функция: Проверка включен ли показ связей
      define_method :show_relations do
        options[:show_relations] == true || options[:show_relations] == '1'
      end

      # Функция: Установка состояния показа связей
      define_method :show_relations= do |arg|
        options[:show_relations] = (arg == true || arg == '1' ? true : false)
      end

      # Функция: Получение фильтров для подзадач
      define_method :child_filters do
        options[:child_filters] || {}
      end

      # Функция: Установка фильтров для подзадач
      define_method :child_filters= do |arg|
        options[:child_filters] = arg
      end

      # Функция: Получение критериев сортировки для подзадач
      define_method :child_sort_criteria do
        options[:child_sort_criteria] || []
      end

      # Функция: Установка критериев сортировки для подзадач
      define_method :child_sort_criteria= do |arg|
        options[:child_sort_criteria] = arg
      end

      # --- Переопределение css_classes для добавления класса hierarchy-sort ---
      # Функция: Возвращает CSS-классы для таблицы списка задач
      # Блок 1: При включённой иерархической сортировке добавляем класс hierarchy-sort
      # для возможности кастомизации стилей пользователем в будущем
      alias_method :css_classes_without_hierarchy, :css_classes
      define_method :css_classes do
        classes = css_classes_without_hierarchy
        if hierarchy_enabled
          classes = classes.present? ? "#{classes} hierarchy-sort" : "hierarchy-sort"
        end
        classes
      end

      # --- Переопределение методов ---

      # Функция: Переопределение build_from_params для чтения наших параметров из формы
      alias_method :build_from_params_without_hierarchy_sort, :build_from_params
      define_method :build_from_params do |params, defaults={}|
        # Блок 2: Вызываем оригинальный метод Redmine для обработки стандартных полей
        build_from_params_without_hierarchy_sort(params, defaults)

        # Блок 3: Определяем источник параметров (из query[] или из корня params)
        query_params = params[:query] || {}

        # Блок 4: Читаем булевы флаги (дерево и связи)
        self.hierarchy_enabled = query_params[:hierarchy_enabled] || params[:hierarchy_enabled]
        self.show_relations = query_params[:show_relations] || params[:show_relations]

        # Блок 5: Обработка фильтров подзадач
        if params[:child_f] || query_params[:child_f]
          fields = params[:child_f] || query_params[:child_f]
          operators = params[:child_op] || query_params[:child_op] || {}
          values = params[:child_v] || query_params[:child_v] || {}
          
          self.child_filters = {}
          add_child_filters(fields, operators, values)
        end

        # Блок 6: Обработка сортировки подзадач
        # Параметр приходит как хэш: {"0"=>["tracker", "desc"], "1"=>["", ""], "2"=>["", ""]}
        if params[:child_sort_criteria].present? || query_params[:child_sort_criteria].present?
          sort_param = params[:child_sort_criteria] || query_params[:child_sort_criteria]
          if sort_param.is_a?(Hash)
            criteria = []
            sort_param.each do |key, value|
              if value.is_a?(Array) && value[0].present?
                criteria << value
              end
            end
            self.child_sort_criteria = criteria
          else
            self.child_sort_criteria = Redmine::SortCriteria.new(sort_param).to_a
          end
        end

        self
      end

      # Функция: Вспомогательный метод для парсинга фильтров подзадач
      define_method :add_child_filters do |fields, operators, values|
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
end