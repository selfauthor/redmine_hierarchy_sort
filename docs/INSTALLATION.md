# Подробное руководство по установке

## Предварительные требования

Перед установкой плагина убедитесь, что:

- [ ] Установлен Redmine версии 5.0 или выше
- [ ] Версия Ruby соответствует требованиям Redmine
- [ ] База данных настроена и работает
- [ ] У вас есть доступ к командной строке сервера

## Пошаговая установка

### Шаг 1: Резервное копирование

Перед установкой любого плагина рекомендуется сделать резервную копию:

```bash
# Резервная копия базы данных
mysqldump -u username -p redmine_db > redmine_backup_$(date +%Y%m%d).sql

# Резервная копия файлов Redmine
cp -r /path/to/redmine /path/to/redmine_backup_$(date +%Y%m%d)
```

### Шаг 2: Скачивание плагина

```bash
cd /path/to/redmine/plugins
git clone https://github.com/selfauthor/redmine_hierarchy_sort.git
```

### Шаг 3: Установка зависимостей

```bash
cd /path/to/redmine
bundle install --without development test
```

### Шаг 4: Миграции (если есть)

Для этого плагина миграции не требуются, но на будущее:

### Шаг 5: Очистка кэша

```bash
bundle exec rake tmp:cache:clear
bundle exec rake tmp:sessions:clear
```

### Шаг 6: Перезапуск приложения

```bash
# Для Passenger
touch tmp/restart.txt

# Для systemd
sudo systemctl restart redmine

# Для Docker
docker-compose restart
```

### Шаг 7: Проверка установки

1. Откройте Redmine в браузере
2. Перейдите в **Администрирование → Плагины**
3. Убедитесь, что "Иерархия задач с сортировкой и связями" отображается в списке
4. Перейдите в любой проект → Задачи
5. Нажмите "Новый запрос"
6. В блоке "Опции" должны быть чекбоксы "Дерево подзадач" и "Показывать связи"

## Устранение неполадок

### Плагин не отображается в списке

**Причина:** Неправильная структура директорий

**Решение:**
```bash
# Проверьте структуру
ls -la /path/to/redmine/plugins/redmine_hierarchy_sort/

# Должны быть файлы: init.rb, README.md, lib/, app/
# Если init.rb находится в поддиректории — переместите его
```

### Ошибка "Cannot load such file"

**Причина:** Отсутствуют зависимости или неправильные права доступа

**Решение:**
```bash
# Проверьте права
chmod -R 755 /path/to/redmine/plugins/redmine_hierarchy_sort

# Переустановите зависимости
cd /path/to/redmine
bundle install
```

### Ошибка миграции БД

**Причина:** Несовместимость версии плагина с версией Redmine

**Решение:**
```bash
# Откатите миграции
bundle exec rake redmine:plugins:migrate NAME=redmine_hierarchy_sort VERSION=0 RAILS_ENV=production

# Обновите плагин до совместимой версии
cd plugins/redmine_hierarchy_sort
git checkout tags/v1.0.0
```

### Иерархия не работает

**Причина:** Конфликт с другим плагином или неправильная настройка

**Решение:**
1. Проверьте логи Redmine:
   ```bash
   tail -f /path/to/redmine/log/production.log
   ```
2. Отключите другие плагины по одному для выявления конфликта
3. Убедитесь, что чекбокс "Дерево подзадач" включен в запросе

## Удаление плагина

Если вам нужно удалить плагин:

```bash
# 1. Отключите плагин (опционально)
# Отредактируйте config/configuration.yml и добавьте:
# disabled_plugins:
#   - redmine_hierarchy_sort

# 2. Удалите файлы плагина
rm -rf /path/to/redmine/plugins/redmine_hierarchy_sort

# 3. Очистите кэш
cd /path/to/redmine
bundle exec rake tmp:cache:clear

# 4. Перезапустите Redmine
touch tmp/restart.txt
```

**Важно:** Все настройки запросов сохранятся в базе данных и не вызовут ошибок, так как они хранятся в поле `options` в формате YAML.

## Обновление плагина

```bash
cd /path/to/redmine/plugins/redmine_hierarchy_sort
git pull origin main

cd /path/to/redmine
bundle install
bundle exec rake tmp:cache:clear
touch tmp/restart.txt
```

## Docker установка

Если вы используете Docker:

```dockerfile
# Dockerfile
FROM redmine:5.0

# Установка плагина
RUN cd /usr/src/redmine/plugins && \
    git clone https://github.com/your-username/redmine_hierarchy_sort.git

# Установка зависимостей
RUN cd /usr/src/redmine && \
    bundle install --without development test
```

Или через docker-compose:

```yaml
# docker-compose.yml
version: '3'
services:
  redmine:
    image: redmine:5.0
    volumes:
      - ./plugins/redmine_hierarchy_sort:/usr/src/redmine/plugins/redmine_hierarchy_sort
    ports:
      - "3000:3000"
```