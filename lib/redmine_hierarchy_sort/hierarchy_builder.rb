# lib/redmine_hierarchy_sort/hierarchy_builder.rb
module RedmineHierarchySort
  # Класс, реализующий алгоритм иерархической выборки задач
  class HierarchyBuilder
    attr_reader :query, :options

    # Функция: Инициализация билдера
    # Блок 1: Сохраняем ссылку на основной запрос и опции (limit, offset)
    def initialize(query, options = {})
      @query = query
      @options = options
    end

    # Функция: Главный метод для получения финального списка задач
    # Блок 2: Вызывает последовательно все шаги алгоритма
    def fetch_issues
      # Шаг 1: Загрузка "легких" данных для корней (только id и parent_id)
      root_data = fetch_light_root_data

      # Шаг 2: Определение относительных корней (удаление тех, чьи родители есть в выборке)
      relative_roots = identify_relative_roots(root_data)

      # Шаг 3: Пагинация корней
      paginated_roots = paginate_array(relative_roots)

      # Шаг 4: Рекурсивная загрузка потомков и сборка финального списка ID (DFS)
      final_ids = []
      paginated_roots.each do |root|
        final_ids << root[:id]
        fetch_descendants_recursive(root[:id], final_ids)
      end

      # Шаг 5: "Тяжелая" загрузка полных объектов задач
      load_full_issues(final_ids)
    end

    private

    # Функция: Загрузка "легких" данных для корней
    # Блок 3: Формируем SQL-запрос с фильтрами и сортировкой корней, выбираем только id и parent_id
    def fetch_light_root_data
      # Базовый скоуп с учетом видимости
      scope = Issue.visible

      # Применяем фильтры корней (используем стандартный statement основного запроса)
      # statement уже содержит project_statement и все условия из query.filters
      if query.statement.present?
        scope = scope.where(query.statement)
      end

      # Применяем сортировку корней
      order_clause = query.sort_clause
      scope = scope.order(order_clause) if order_clause.present?

      # Выбираем только необходимые поля и преобразуем в массив хэшей
      scope.pluck(:id, :parent_id).map do |id, parent_id|
        { id: id, parent_id: parent_id }
      end
    end

    # Функция: Определение относительных корней
    # Блок 4: Помечаем задачи для удаления, если их родитель присутствует в массиве
    def identify_relative_roots(data)
      # Добавляем флаг to_delete ко всем элементам
      data.each { |d| d[:to_delete] = false }

      # Создаем множество всех ID для быстрого поиска (O(1))
      all_ids = data.map { |d| d[:id] }.to_set

      # Проходим по всем элементам и помечаем те, чей родитель есть в выборке
      data.each do |d|
        if d[:parent_id].present? && all_ids.include?(d[:parent_id])
          d[:to_delete] = true
        end
      end

      # Возвращаем только те элементы, которые не помечены на удаление
      data.reject { |d| d[:to_delete] }
    end

    # Функция: Пагинация массива корней
    # Блок 5: Применяем limit и offset к массиву хэшей
    def paginate_array(array)
      limit = options[:limit] || 25
      offset = options[:offset] || 0
      
      array[offset, limit] || []
    end

    # Функция: Рекурсивная загрузка потомков
    # Блок 6: Загружаем прямых потомков, применяем фильтры и сортировку, рекурсивно вызываем для каждого
    def fetch_descendants_recursive(parent_id, final_ids)
      # Базовый скоуп для потомков: только прямые дети родителя
      scope = Issue.visible.where(parent_id: parent_id)

      # Применяем фильтры потомков, если они заданы
      if query.child_filters.present?
        child_statement = build_child_statement
        scope = scope.where(child_statement) if child_statement.present?
      end

      # Применяем сортировку потомков, если она задана
      child_order = build_child_order_clause
      scope = scope.order(child_order) if child_order.present?

      # Загружаем только ID потомков (уже отсортированные SQL-запросом)
      child_ids = scope.pluck(:id)

      # Для каждого потомка добавляем его ID в финальный список и рекурсивно загружаем его детей
      child_ids.each do |child_id|
        final_ids << child_id
        fetch_descendants_recursive(child_id, final_ids)
      end
    end

    # Функция: Построение SQL-условия WHERE для фильтров потомков
    # Блок 7: Создаем временный IssueQuery для генерации statement на основе child_filters
    def build_child_statement
      # Создаем временный запрос с тем же проектом
      temp_query = IssueQuery.new(:project => query.project)
      
      # Устанавливаем фильтры потомков
      temp_query.filters = query.child_filters
      
      # Инициализируем доступные фильтры (необходимо для корректной работы statement)
      temp_query.send(:initialize_available_filters)
      
      # Генерируем SQL-условие
      temp_query.statement
    end

    # Функция: Построение SQL-условия ORDER BY для сортировки потомков
    # Блок 8: Создаем временный IssueQuery для генерации sort_clause на основе child_sort_criteria
    def build_child_order_clause
      # Создаем временный запрос
      temp_query = IssueQuery.new(:project => query.project)
      
      # Устанавливаем критерии сортировки потомков
      temp_query.sort_criteria = query.child_sort_criteria
      
      # Инициализируем доступные фильтры и колонки (необходимо для sort_clause)
      temp_query.send(:initialize_available_filters)
      temp_query.available_columns
      
      # Генерируем SQL-условие сортировки
      temp_query.sort_clause
    end

    # Функция: "Тяжелая" загрузка полных объектов задач
    # Блок 9: Загружаем задачи по списку ID с необходимыми includes и сортируем в Ruby
    def load_full_issues(ids)
      # Если список ID пуст, возвращаем пустой массив
      return [] if ids.empty?

      # Формируем базовый скоуп с необходимыми includes
      # Включаем все стандартные ассоциации, которые использует Redmine для отображения
      scope = Issue.where(id: ids).preload(:priority).includes([
        :status, :project, :tracker, :author, :assigned_to, 
        :fixed_version, :category, :attachments, :relations
      ])

      # Загружаем задачи
      issues = scope.to_a

      # Создаем хэш для быстрого доступа по ID
      issues_by_id = issues.index_by(&:id)

      # Формируем финальный массив, сохраняя порядок из final_ids
      sorted_issues = ids.filter_map { |id| issues_by_id[id] }

      # Применяем условную предзагрузку данных (spent_hours, last_updated_by и т.д.)
      # Это необходимо для корректной работы стандартных колонок Redmine
      apply_conditional_preloading(sorted_issues)

      sorted_issues
    end

    # Функция: Применение условной предзагрузки данных
    # Блок 10: Вызываем стандартные методы Redmine для загрузки дополнительных данных, если нужные колонки выбраны
    def apply_conditional_preloading(issues)
      # Загружаем затраченные часы, если выбрана соответствующая колонка
      if query.has_column?(:spent_hours)
        Issue.load_visible_spent_hours(issues)
      end

      # Загружаем общие затраченные часы
      if query.has_column?(:total_spent_hours)
        Issue.load_visible_total_spent_hours(issues)
      end

      # Загружаем последнего обновившего пользователя
      if query.has_column?(:last_updated_by)
        Issue.load_visible_last_updated_by(issues)
      end

      # Загружаем последние заметки
      if query.has_column?(:last_notes)
        Issue.load_visible_last_notes(issues)
      end
    end
  end
end