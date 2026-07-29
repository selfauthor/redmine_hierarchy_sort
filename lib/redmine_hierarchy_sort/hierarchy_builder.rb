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
    def fetch_issues(root_data: nil)
      # Шаг 1: Загрузка "лёгких" данных для корней (только id и parent_id)
      # Если данные переданы (из кэша issue_count), используем их
      root_data ||= fetch_light_root_data

      # Шаг 2: Определение относительных корней
      relative_roots = identify_relative_roots(root_data)

      # Шаг 3: Пагинация корней
      paginated_roots_data = paginate_array(relative_roots)
      parent_ids = paginated_roots_data.map { |r| r[:id] }

      # Шаг 4: Загрузка полных объектов родителей
      parents = load_parent_issues(parent_ids)

      # Шаг 5: Загрузка потомков по уровням (один запрос на уровень)
      descendants = fetch_descendants_by_levels(parent_ids)

      # Шаг 6: Построение дерева и DFS-обход
      final_issues = build_tree_and_flatten(parents, descendants)

      # Шаг 7: Применение условной предзагрузки к финальному списку
      apply_conditional_preloading(final_issues)

      final_issues
    end

    private

    # Функция: Загрузка "лёгких" данных для корней
    # Блок 3: Формируем SQL-запрос с фильтрами и сортировкой корней, выбираем только id и parent_id
    def fetch_light_root_data
      # Базовый скоуп с учётом видимости
      scope = Issue.visible

      # Применяем фильтры корней (используем стандартный statement основного запроса)
      if query.statement.present?
        scope = scope.where(query.statement)
      end

      # Применяем сортировку корней
      order_clause = query.sort_clause
      if order_clause.present?
        scope = scope.order(order_clause)
        # Добавляем JOIN'ы для сортировки корней
        joins_clause = query.joins_for_order_statement(order_clause.map(&:to_s).join(','))
        scope = scope.joins(joins_clause) if joins_clause.present?
      end

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

      # Создаём множество всех ID для быстрого поиска (O(1))
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

    # Функция: Загрузка полных объектов родителей
    # Блок 6: Загружаем задачи по списку ID с необходимыми includes
    # ВАЖНО: :relations НЕ добавляем в includes, т.к. такой ассоциации нет в модели Issue.
    # Связи загружаются позже через Issue.load_visible_relations в apply_conditional_preloading.
    def load_parent_issues(ids)
      return [] if ids.empty?

      scope = Issue.where(id: ids).preload(:priority).includes([
        :status, :project, :tracker, :author, :assigned_to,
        :fixed_version, :category, :attachments
      ])

      issues = scope.to_a
      issues_by_id = issues.index_by(&:id)
      ids.filter_map { |id| issues_by_id[id] }
    end

    # Функция: Загрузка потомков по уровням
    # Блок 7: Делаем один SQL-запрос на каждый уровень вложенности
    # ВАЖНО: :relations НЕ добавляем в includes по той же причине.
    def fetch_descendants_by_levels(parent_ids)
      all_descendants = []
      current_level_ids = parent_ids

      while current_level_ids.present?
        # Базовый скоуп для потомков: только прямые дети текущего уровня
        scope = Issue.visible.where(parent_id: current_level_ids)

        # Применяем фильтры потомков, если они заданы
        if query.child_filters.present?
          child_statement = build_child_statement
          scope = scope.where(child_statement) if child_statement.present?
        end

        # Применяем сортировку потомков, если она задана
        child_order = build_child_order_clause
        if child_order.present?
          scope = scope.order(child_order)
          # Добавляем JOIN'ы для сортировки потомков
          joins_clause = build_child_joins(child_order)
          scope = scope.joins(joins_clause) if joins_clause.present?
        end

        # Загружаем полные объекты задач текущего уровня
        level_issues = scope.preload(:priority).includes([
          :status, :project, :tracker, :author, :assigned_to,
          :fixed_version, :category, :attachments
        ]).to_a

        # Если потомков нет, выходим из цикла
        break if level_issues.empty?

        # Добавляем задачи текущего уровня в общий список
        all_descendants.concat(level_issues)

        # Переходим к следующему уровню
        current_level_ids = level_issues.map(&:id)
      end

      all_descendants
    end

    # Функция: Построение дерева и DFS-обход
    # Блок 8: Создаём хэш parent_id → [дети] и обходим дерево в глубину
    def build_tree_and_flatten(parents, descendants)
      # Создаём хэш: parent_id → [массив детей]
      # Ruby 1.9+ сохраняет порядок вставки, поэтому порядок сортировки SQL сохраняется
      children_map = Hash.new { |h, k| h[k] = [] }
      descendants.each { |issue| children_map[issue.parent_id] << issue }

      # DFS-обход: родитель → дети → внуки
      final_issues = []

      parents.each do |parent|
        final_issues << parent
        add_descendants_dfs(parent.id, children_map, final_issues)
      end

      final_issues
    end

    # Функция: Рекурсивное добавление потомков в финальный список
    # Блок 9: Для каждого узла добавляем его детей и рекурсивно вызываем для внуков
    def add_descendants_dfs(parent_id, children_map, final_issues)
      children_map[parent_id].each do |child|
        final_issues << child
        add_descendants_dfs(child.id, children_map, final_issues)
      end
    end

    # Функция: Построение SQL-условия WHERE для фильтров потомков
    # Блок 10: Создаём временный IssueQuery для генерации statement на основе child_filters
    def build_child_statement
      # Создаём временный запрос с тем же проектом
      temp_query = IssueQuery.new(:project => query.project)

      # Устанавливаем фильтры потомков
      temp_query.filters = query.child_filters

      # Инициализируем доступные фильтры (необходимо для корректной работы statement)
      temp_query.send(:initialize_available_filters)

      # Генерируем SQL-условие
      temp_query.statement
    end

    # Функция: Построение SQL-условия ORDER BY для сортировки потомков
    # Блок 11: Создаём временный IssueQuery для генерации sort_clause на основе child_sort_criteria
    def build_child_order_clause
      # Создаём временный запрос
      temp_query = IssueQuery.new(:project => query.project)

      # Устанавливаем критерии сортировки потомков
      temp_query.sort_criteria = query.child_sort_criteria

      # Инициализируем доступные фильтры и колонки (необходимо для sort_clause)
      temp_query.send(:initialize_available_filters)
      temp_query.available_columns

      # Генерируем SQL-условие сортировки
      temp_query.sort_clause
    end

    # Функция: Построение JOIN'ов для сортировки потомков
    # Блок 12: Используем метод joins_for_order_statement из временного запроса
    def build_child_joins(order_clause)
      return nil unless order_clause.present?

      # Создаём временный запрос для генерации JOIN'ов
      temp_query = IssueQuery.new(:project => query.project)
      temp_query.send(:initialize_available_filters)
      temp_query.available_columns

      # Преобразуем order_clause в строку для joins_for_order_statement
      order_string = order_clause.map(&:to_s).join(',')

      # Генерируем JOIN'ы
      temp_query.joins_for_order_statement(order_string)
    end

    # Функция: Применение условной предзагрузки данных
    # Блок 13: Вызываем стандартные методы Redmine для загрузки дополнительных данных,
    # если соответствующие колонки выбраны в запросе
    def apply_conditional_preloading(issues)
      
      return if issues.empty?
      
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
      
      # Загружаем связи
      if query.has_column?(:relations) || query.show_relations
        Issue.load_visible_relations(issues)
        
        # Проверяем, загрузились ли связи
        issues.each do |issue|
        end
      else
      end
    end
  end
end