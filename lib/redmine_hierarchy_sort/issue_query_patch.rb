module RedmineHierarchySort
  module IssueQueryPatch
    extend ActiveSupport::Concern

    included do
      alias_method :issues_without_hierarchy, :issues
      alias_method :issue_count_without_hierarchy, :issue_count

      # Функция: Расширяет список доступных столбцов сортировки полями непосредственного родителя.
      # Параметры: отсутствуют; метод использует штатный список столбцов IssueQuery.
      # Возвращает: массив стандартных столбцов Redmine и дополнительных столбцов родителя.
      alias_method :available_columns_without_parent_sort, :available_columns

      define_method :available_columns do
        # Возвращаем кэшированный список, чтобы повторный вызов не добавлял
        # одни и те же столбцы родителя несколько раз.
        next @available_columns if @available_columns

        # Копируем штатный список, сохраняя стандартные столбцы и пользовательские поля.
        columns = available_columns_without_parent_sort.dup

        # Используем отдельный псевдоним таблицы родителя внутри коррелированных подзапросов.
        parent_table = 'parent_sort_issues'
        parent_link = "#{parent_table}.id = #{Issue.table_name}.parent_id"

        # Формируем выражения сортировки для полей, хранящихся непосредственно в issues.
        # При отсутствии родителя подзапрос возвращает NULL.
        parent_attributes = {
          subject:         [:subject, :field_subject],
          created_on:      [:created_on, :field_created_on],
          updated_on:      [:updated_on, :field_updated_on],
          closed_on:       [:closed_on, :field_closed_on],
          start_date:      [:start_date, :field_start_date],
          due_date:        [:due_date, :field_due_date],
          estimated_hours: [:estimated_hours, :field_estimated_hours],
          done_ratio:      [:done_ratio, :field_done_ratio],
          is_private:      [:is_private, :field_is_private]
        }

        # Для атрибутов таблицы issues строим независимые подзапросы,
        # чтобы не менять JOIN основного запроса и не размножать строки задач.
        parent_attributes.each do |attribute, (db_field, caption_key)|
          sortable_sql =
            "(SELECT #{parent_table}.#{db_field} " \
            "FROM #{Issue.table_name} #{parent_table} " \
            "WHERE #{parent_link})"

          columns << QueryColumn.new(
            "parent_#{attribute}".to_sym,
            :sortable => sortable_sql,
            :caption => l(:label_attribute_of_parent, name: l(caption_key))
          )
        end

        # Для связанных объектов сортируем по тому же смысловому атрибуту,
        # который используется штатными столбцами Redmine.
        parent_associations = {
          tracker: [
            :tracker_id,
            :field_tracker,
            "#{Tracker.table_name}.position"
          ],
          status: [
            :status_id,
            :field_status,
            "#{IssueStatus.table_name}.position"
          ],
          priority: [
            :priority_id,
            :field_priority,
            "#{IssuePriority.table_name}.position"
          ],
          category: [
            :category_id,
            :field_category,
            "#{IssueCategory.table_name}.name"
          ],
          fixed_version: [
            :fixed_version_id,
            :field_fixed_version,
            "#{Version.table_name}.name"
          ]
        }

        # Каждое выражение обращается к связанному объекту именно родительской задачи.
        # Если связь отсутствует, результат сортировки будет NULL.
        parent_associations.each do |association, (foreign_key, caption_key, sort_field)|
          association_table = case association
                              when :project
                                Project.table_name
                              when :tracker
                                Tracker.table_name
                              when :status
                                IssueStatus.table_name
                              when :priority
                                IssuePriority.table_name
                              when :category
                                IssueCategory.table_name
                              when :fixed_version
                                Version.table_name
                              end

          sortable_sql =
            "(SELECT #{sort_field} " \
            "FROM #{Issue.table_name} #{parent_table} " \
            "LEFT JOIN #{association_table} " \
            "ON #{association_table}.id = #{parent_table}.#{foreign_key} " \
            "WHERE #{parent_link})"

          columns << QueryColumn.new(
            "parent_#{association}".to_sym,
            :sortable => sortable_sql,
            :caption => l(:label_attribute_of_parent, name: l(caption_key))
          )
        end

        # Для автора и исполнителя сохраняем порядок по фамилии и имени,
        # используемый штатными механизмами сортировки пользователей Redmine.
        {
          author: [:author_id, :field_author],
          assigned_to: [:assigned_to_id, :field_assigned_to]
        }.each do |association, (foreign_key, caption_key)|
          sortable_sql = [
            "(SELECT parent_sort_users.lastname " \
            "FROM #{Issue.table_name} #{parent_table} " \
            "LEFT JOIN #{User.table_name} parent_sort_users " \
            "ON parent_sort_users.id = #{parent_table}.#{foreign_key} " \
            "WHERE #{parent_link})",
            "(SELECT parent_sort_users.firstname " \
            "FROM #{Issue.table_name} #{parent_table} " \
            "LEFT JOIN #{User.table_name} parent_sort_users " \
            "ON parent_sort_users.id = #{parent_table}.#{foreign_key} " \
            "WHERE #{parent_link})"
          ]

          columns << QueryColumn.new(
            "parent_#{association}".to_sym,
            :sortable => sortable_sql,
            :caption => l(:label_attribute_of_parent, name: l(caption_key))
          )
        end

        # Добавляем сортировку по пользовательским полям непосредственной родительской задачи.
        # Используем штатные SQL-выражения формата поля, чтобы сохранить корректную
        # сортировку чисел, дат и связанных объектов без дублирования логики Redmine.
        # В список включаем доступные поля независимо от флага is_filter.
        issue_custom_fields.visible.each do |custom_field|
          # Получаем штатное выражение сортировки и необходимые для него JOIN.
          # Для полей с несколькими значениями и неподдерживаемых форматов
          # Redmine возвращает nil — такие поля оставляем несортируемыми.
          order_statement = custom_field.order_statement
          join_statement = custom_field.join_for_order_statement

          next if order_statement.blank? || join_statement.blank?

          # Создаём отдельный псевдоним CustomValue, чтобы SQL сортировки
          # родителя не конфликтовал с JOIN пользовательских полей текущей задачи.
          custom_value_alias = "parent_cf_#{custom_field.id}"

          # Перенаправляем штатные JOIN и ссылки на таблицу issues на родителя.
          # JOIN остаётся внутри коррелированного подзапроса, поэтому не размножает
          # строки основного запроса и не требует изменения его структуры.
          parent_join_statement =
            join_statement.
              gsub("cf_#{custom_field.id}", custom_value_alias).
              gsub("#{Issue.table_name}.", "#{parent_table}.")

          # Используем то же выражение сортировки, что и штатный формат Redmine,
          # заменяя только псевдоним пользовательского значения.
          parent_order_statement =
            order_statement.to_s.gsub("cf_#{custom_field.id}", custom_value_alias)

          # Подзапрос получает значение только непосредственного родителя.
          # Если родителя или значения поля нет, результат сортировки будет NULL.
          sortable_sql =
            "(SELECT #{parent_order_statement} " \
            "FROM #{Issue.table_name} #{parent_table} " \
            "#{parent_join_statement} " \
            "WHERE #{parent_link})"

          # Создаём штатную колонку пользовательского поля связанного объекта.
          # Она получает значение через issue.parent и использует штатное
          # форматирование пользовательского поля Redmine.
          parent_column = QueryAssociationCustomFieldColumn.new(
            :parent,
            custom_field
          )

          # Сохраняем идентификатор столбца, уже использованный в настройках списка,
          # чтобы не менять параметр parent_cf_<id> в сохранённых настройках.
          parent_column.name = :"parent_cf_#{custom_field.id}"

          # Назначаем выражение сортировки по пользовательскому полю родителя.
          parent_column.sortable = sortable_sql

          # Показываем название поля с префиксом «Родительская задача».
          # Используем метод caption, чтобы штатный механизм отображения
          # заголовков Redmine получил нужную подпись.
          parent_column.define_singleton_method(:caption) do
            l(:label_attribute_of_parent, name: custom_field.name)
          end

          columns << parent_column
        end

        # Сохраняем расширенный список в штатном кэше IssueQuery.
        @available_columns = columns
      end

      # Сохраняем штатный обработчик пользовательских полей Redmine.
      alias_method :sql_for_custom_field_without_parent_custom_fields,
                   :sql_for_custom_field

      # Формирует SQL для пользовательского поля родительской задачи.
      # Для остальных полей полностью сохраняет штатную обработку Redmine.
      # Параметры:
      #   field — идентификатор поля фильтра;
      #   operator — оператор сравнения;
      #   value — значения фильтра;
      #   custom_field_id — идентификатор пользовательского поля.
      define_method :sql_for_custom_field do |field, operator, value, custom_field_id|
        # Обрабатываем отдельно только пользовательские поля родительской задачи.
        unless field.to_s.match?(/\Aparent\.cf_\d+\z/)
          next sql_for_custom_field_without_parent_custom_fields(
            field, operator, value, custom_field_id
          )
        end

        db_table = CustomValue.table_name
        db_field = 'value'
        filter = @available_filters[field]

        # Если фильтр не зарегистрирован, SQL для него не формируем.
        next nil unless filter

        # Сохраняем штатную обработку фильтров пользовательских полей,
        # значения которых ссылаются на пользователей.
        if filter[:field].format.target_class &&
           filter[:field].format.target_class <= User
          if value.delete('me')
            value.push User.current.id.to_s
          end
        end

        # Оператор "!" реализуем через NOT EXISTS, как в ядре Redmine.
        not_in = nil
        if operator == '!'
          operator = '='
          not_in = 'NOT'
        end

        # Поле относится к родительской задаче, поэтому ищем её запись
        # через алиас ct, не подменяя таблицу текущей задачи в основном запросе.
        customized_key = 'parent_id'
        customized_class = Issue

        where = sql_for_field(
          field, operator, value, db_table, db_field, true
        )

        # Для сравнений по диапазону исключаем пустые значения,
        # сохраняя штатное поведение Redmine.
        if /[<>]/.match?(operator)
          where = "(#{where}) AND #{db_table}.#{db_field} <> ''"
        end

        # Строим условия доступности поля с учётом родительской задачи.
        # visibility_by_project_condition в IssueCustomField использует имя
        # таблицы issues; заменяем его на ct только внутри условия видимости.
        visibility_condition =
          filter[:field].visibility_by_project_condition(
            'ct.project_id',
            User.current,
            custom_field_id
          ).gsub("#{Issue.table_name}.", 'ct.')

        # Сопоставляем значение custom_values с родительской задачей.
        # Условие issues.parent_id = ct.id связывает родителя с текущей задачей.
        "#{not_in} EXISTS (" \
          "SELECT ct.id FROM #{customized_class.table_name} ct" \
          " LEFT OUTER JOIN #{db_table}" \
          " ON #{db_table}.customized_type='#{customized_class}'" \
          " AND #{db_table}.customized_id=ct.id" \
          " AND #{db_table}.custom_field_id=#{custom_field_id}" \
          " WHERE #{Issue.table_name}.#{customized_key} = ct.id" \
          " AND (#{where})" \
          " AND (#{visibility_condition})" \
          ")"
      end

      # Список стандартных атрибутов родительской задачи,
      # которые можно фильтровать обычным механизмом sql_for_field.
      # Специальные фильтры и вычисляемые показатели здесь не используются.
      parent_issue_filter_fields = %w[
        tracker_id
        status_id
        priority_id
        author_id
        assigned_to_id
        fixed_version_id
        category_id
        subject
        description
        created_on
        updated_on
        closed_on
        start_date
        due_date
        estimated_hours
        done_ratio
        is_private
      ]

      # Формирует SQL для фильтра стандартного поля родительской задачи.
      # Параметры:
      #   field — идентификатор фильтра в формате parent.<имя_поля>;
      #   operator — оператор фильтра Redmine;
      #   value — значения, введённые или выбранные пользователем;
      #   attribute — имя столбца issues, заданное в статическом списке выше.
      define_method :sql_for_parent_issue_attribute do |field, operator, value, attribute|
        # Имя таблицы и столбца берутся из внутреннего списка разрешённых атрибутов.
        parent_table = 'parent_issues'

        # Используем штатное формирование условий Redmine, чтобы сохранить
        # обработку типов фильтров, дат, чисел, пустых значений и операторов.
        condition = sql_for_field(
          field,
          operator,
          value,
          parent_table,
          attribute
        )

        # EXISTS проверяет только непосредственного родителя текущей задачи.
        # Внешний запрос не соединяется с таблицей родителей, поэтому строки
        # основного списка не дублируются и не заменяются повторным запросом.
        "EXISTS (" \
          "SELECT #{parent_table}.id " \
          "FROM #{Issue.table_name} #{parent_table} " \
          "WHERE #{Issue.table_name}.parent_id = #{parent_table}.id " \
          "AND (#{condition})" \
          ")"
      end

      # Регистрируем отдельные обработчики, которые Redmine вызывает
      # автоматически для фильтров вида parent.status_id и parent.subject.
      parent_issue_filter_fields.each do |attribute|
        define_method "sql_for_parent_#{attribute}_field" do |field, operator, value|
          sql_for_parent_issue_attribute(field, operator, value, attribute)
        end
      end

      # Функция: Добавляет пользовательские поля родительской задачи в основной список фильтров.
      # Использует штатную регистрацию фильтров Redmine, включая типы полей и их операторы.
      # Поля доступны только для фильтрации, если у них установлен флаг is_filter.
      alias_method :initialize_available_filters_without_parent_custom_fields,
                   :initialize_available_filters

      # Функция: Регистрирует стандартные фильтры текущей задачи,
      # стандартные фильтры её непосредственного родителя и пользовательские
      # фильтры родителя. Типы и значения стандартных фильтров берутся из Redmine.
      # Параметры: отсутствуют; метод использует контекст текущего Query.
      define_method :initialize_available_filters do
        # Сначала штатно регистрируем фильтры текущей задачи.
        initialize_available_filters_without_parent_custom_fields

        # Добавляем фильтры стандартных полей родительской задачи.
        parent_issue_filter_fields.each do |source_field|
          source_filter = @available_filters[source_field]

          # Если Redmine не зарегистрировал поле в текущем контексте,
          # пропускаем его, кроме project_id, который может отсутствовать
          # в списке фильтров при просмотре конкретного проекта.
          if source_filter
            # Копируем исходные параметры QueryFilter, сохраняя штатный тип,
            # список значений, удалённый режим и прочие параметры фильтра.
            parent_filter_options =
              source_filter.instance_variable_get(:@options).dup
          elsif source_field == 'project_id'
            # Фильтр проекта нужен и в контексте конкретного проекта,
            # поскольку у родительской задачи может быть другой проект.
            parent_filter_options = {
              type: :list,
              values: lambda { project_values }
            }
          else
            next
          end

          # Формируем название фильтра в том же формате, что и для пользовательских полей родителя.
          # Убираем префикс «объекта» и используем двоеточие между родителем и названием поля.
          source_field_name = source_filter&.instance_variable_get(:@options)&.dig(:name)
          source_field_name ||= l("field_#{source_field.delete_suffix('_id')}")

          parent_filter_options[:name] = l(:label_attribute_of_parent, name: source_field_name)

          add_available_filter("parent.#{source_field}", parent_filter_options)
        end

        # Сохраняем ранее реализованную регистрацию пользовательских полей
        # родительской задачи. Метод добавляет только поля, разрешённые
        # для фильтрации в настройках пользовательских полей.
        add_custom_fields_filters(issue_custom_fields, :parent)
      end

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
# v2610161122