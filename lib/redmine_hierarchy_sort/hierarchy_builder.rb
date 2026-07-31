# lib/redmine_hierarchy_sort/hierarchy_builder.rb
module RedmineHierarchySort
  class HierarchyBuilder
    attr_reader :query, :options

    def initialize(query, options = {})
      @query = query
      @options = options
    end

    def fetch_issues(root_data: nil)
      root_data ||= fetch_light_root_data
      relative_roots = identify_relative_roots(root_data)
      paginated_roots_data = paginate_array(relative_roots)
      parent_ids = paginated_roots_data.map { |r| r[:id] }
      
      parents = load_parent_issues(parent_ids)
      descendants = fetch_descendants_by_levels(parent_ids)
      final_issues = build_tree_and_flatten(parents, descendants)
      apply_conditional_preloading(final_issues)
      
      final_issues
    end

    private

    def fetch_light_root_data
      scope = Issue.visible
      if query.statement.present?
        scope = scope.where(query.statement)
      end
      order_clause = query.sort_clause
      if order_clause.present?
        scope = scope.order(order_clause)
        joins_clause = query.joins_for_order_statement(order_clause.map(&:to_s).join(','))
        scope = scope.joins(joins_clause) if joins_clause.present?
      end
      scope.pluck(:id, :parent_id).map do |id, parent_id|
        { id: id, parent_id: parent_id }
      end
    end

    def identify_relative_roots(data)
      data.each { |d| d[:to_delete] = false }
      all_ids = data.map { |d| d[:id] }.to_set
      data.each do |d|
        if d[:parent_id].present? && all_ids.include?(d[:parent_id])
          d[:to_delete] = true
        end
      end
      data.reject { |d| d[:to_delete] }
    end

    def paginate_array(array)
      limit = options[:limit] || 25
      offset = options[:offset] || 0
      array[offset, limit] || []
    end

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
        else
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

    def build_tree_and_flatten(parents, descendants)
      children_map = Hash.new { |h, k| h[k] = [] }
      descendants.each { |issue| children_map[issue.parent_id] << issue }
      final_issues = []
      parents.each do |parent|
        final_issues << parent
        add_descendants_dfs(parent.id, children_map, final_issues)
      end
      final_issues
    end

    def add_descendants_dfs(parent_id, children_map, final_issues)
      children_map[parent_id].each do |child|
        final_issues << child
        add_descendants_dfs(child.id, children_map, final_issues)
      end
    end

    # Функция: Построение SQL-условия WHERE для фильтров потомков
    def build_child_statement
      # Создаём временный запрос с тем же проектом
      temp_query = IssueQuery.new(:project => query.project, :name => '_')
      
      # Устанавливаем фильтры потомков
      temp_query.filters = query.child_filters
      
      # Инициализируем доступные фильтры (необходимо для корректной работы statement)
      temp_query.send(:initialize_available_filters)
      
      # Генерируем SQL-условие
      result = temp_query.statement
      
      result
    end

    # Функция: Построение SQL-условия ORDER BY для сортировки потомков
    def build_child_order_clause
      
      # Создаём временный запрос
      temp_query = IssueQuery.new(:project => query.project, :name => '_')
      
      # Устанавливаем критерии сортировки потомков
      temp_query.sort_criteria = query.child_sort_criteria
      
      # Инициализируем доступные фильтры и колонки (необходимо для sort_clause)
      temp_query.send(:initialize_available_filters)
      temp_query.available_columns
      
      # Генерируем SQL-условие сортировки
      result = temp_query.sort_clause
      
      result
    end

    # ИСПРАВЛЕНО: добавлено :name => '_' для прохождения валидации
    def build_child_joins(order_clause)
      return nil unless order_clause.present?
      temp_query = IssueQuery.new(:project => query.project, :name => '_')
      temp_query.send(:initialize_available_filters)
      temp_query.available_columns
      order_string = order_clause.map(&:to_s).join(',')
      temp_query.joins_for_order_statement(order_string)
    end

    def apply_conditional_preloading(issues)
      return if issues.empty?
      if query.has_column?(:spent_hours)
        Issue.load_visible_spent_hours(issues)
      end
      if query.has_column?(:total_spent_hours)
        Issue.load_visible_total_spent_hours(issues)
      end
      if query.has_column?(:last_updated_by)
        Issue.load_visible_last_updated_by(issues)
      end
      if query.has_column?(:last_notes)
        Issue.load_visible_last_notes(issues)
      end
      if query.has_column?(:relations) || query.show_relations
        Issue.load_visible_relations(issues)
      end
    end
  end
end