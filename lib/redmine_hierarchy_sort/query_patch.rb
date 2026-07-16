# lib/redmine_hierarchy_sort/query_patch.rb
module RedmineHierarchySort
  module QueryPatch
    extend ActiveSupport::Concern

    included do
      # Блок 1: Мы не добавляем новые колонки в БД.
      # Все настройки будут храниться в существующем сериализованном поле options (Hash).
      # Это гарантирует, что при удалении плагина Redmine просто проигнорирует лишние ключи.
    end

    # --- Геттеры и сеттеры для опций ---

    # Функция: Проверка включено ли дерево подзадач
    def hierarchy_enabled
      options[:hierarchy_enabled] == true || options[:hierarchy_enabled] == '1'
    end

    # Функция: Установка состояния дерева подзадач
    def hierarchy_enabled=(arg)
      options[:hierarchy_enabled] = (arg == true || arg == '1' ? true : false)
    end

    # Функция: Проверка включен ли показ связей
    def show_relations
      options[:show_relations] == true || options[:show_relations] == '1'
    end

    # Функция: Установка состояния показа связей
    def show_relations=(arg)
      options[:show_relations] = (arg == true || arg == '1' ? true : false)
    end

    # Функция: Получение фильтров для подзадач
    def child_filters
      options[:child_filters] || {}
    end

    # Функция: Установка фильтров для подзадач
    def child_filters=(arg)
      options[:child_filters] = arg
    end

    # Функция: Получение критериев сортировки для подзадач
    def child_sort_criteria
      options[:child_sort_criteria] || []
    end

    # Функция: Установка критериев сортировки для подзадач
    def child_sort_criteria=(arg)
      options[:child_sort_criteria] = arg
    end

    # --- Переопределение методов ---

    # Функция: Переопределение build_from_params для чтения наших параметров из формы
    def build_from_params_with_hierarchy_sort(params, defaults={})
      # Блок 2: Вызываем оригинальный метод Redmine для обработки стандартных полей
      build_from_params_without_hierarchy_sort(params, defaults)

      # Блок 3: Определяем источник параметров (из query[] или из корня params)
      query_params = params[:query] || {}

      # Блок 4: Читаем булевы флаги (дерево и связи)
      self.hierarchy_enabled = query_params[:hierarchy_enabled] || params[:hierarchy_enabled]
      self.show_relations = query_params[:show_relations] || params[:show_relations]

      # Блок 5: Обработка фильтров подзадач
      # Мы используем префикс child_ для параметров формы, чтобы не конфликтовать с основными фильтрами
      if params[:child_f] || query_params[:child_f]
        fields = params[:child_f] || query_params[:child_f]
        operators = params[:child_op] || query_params[:child_op] || {}
        values = params[:child_v] || query_params[:child_v] || {}
        
        self.child_filters = {}
        add_child_filters(fields, operators, values)
      end

      # Блок 6: Обработка сортировки подзадач
      # Стандартный Redmine использует params[:sort] в формате "field:direction"
      # Мы будем использовать params[:child_sort]
      if params[:child_sort].present? || query_params[:child_sort].present?
        sort_param = params[:child_sort] || query_params[:child_sort]
        # Используем стандартный парсер Redmine для преобразования строки в массив
        self.child_sort_criteria = Redmine::SortCriteria.new(sort_param).to_a
      end

      self
    end

    # Функция: Вспомогательный метод для парсинга фильтров подзадач
    # Логика аналогична стандартному add_filters, но записывает результат в child_filters
    def add_child_filters(fields, operators, values)
      return unless fields.present? && operators.present?

      fields.each do |field|
        # Блок 7: Проверяем, что поле доступно в фильтрах (защита от некорректных данных)
        if available_filters.has_key?(field)
          child_filters[field] = {
            :operator => operators[field],
            :values => (values[field] || [''])
          }
        end
      end
    end

    # Блок 8: Применяем патч через alias_method, чтобы сохранить цепочку вызовов
    included do
      alias_method :build_from_params_without_hierarchy_sort, :build_from_params
      alias_method :build_from_params, :build_from_params_with_hierarchy_sort
    end
  end
end