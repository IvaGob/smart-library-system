# SmartLibraryAI

SmartLibraryAI - MVP веб-додатку університетської бібліотеки з рекомендаційним модулем на базі SVD. Проєкт демонструє зв'язок між React-інтерфейсом, Django REST API, PostgreSQL та Python-модулем рекомендацій.

## Основні можливості

- авторизація користувачів через JWT;
- ролі користувачів: читач, бібліотекар, адміністратор;
- каталог книг із MARC21-даними;
- пошук книг за назвою, ISBN та жанром;
- видача й повернення книг;
- фіксація боржників;
- оцінювання книг читачами;
- персональні рекомендації на основі Surprise SVD;
- fallback-рекомендації, якщо даних для повної SVD-моделі ще недостатньо;
- адміністративна панель ШІ з RMSE/MAE, попередженнями про критичну похибку та примусовим перенавчанням;
- нижній термінал логів розробника з API, SQL та Python/SVD-подіями.

## Технології

Backend:
- Python 3.10+
- Django 4.2
- Django REST Framework
- PostgreSQL 15
- Simple JWT
- Surprise SVD
- Pandas
- Gunicorn

Frontend:
- React 18
- Tailwind CSS
- Lucide React

Інфраструктура:
- Docker Compose
- PostgreSQL volume
- Django staticfiles через WhiteNoise

## Структура проєкту

```text
.
├── backend/
│   ├── library/              # Django app: API, моделі, серіалізатори, авторизація
│   ├── recommendations/      # SVD-рекомендації та пояснення
│   ├── smart_library/        # Django settings та urls
│   ├── init_db.sql           # початкова схема і демо-дані PostgreSQL
│   ├── entrypoint.sh         # міграції, staticfiles, створення admin
│   └── requirements.txt
├── frontend/
│   └── src/App.js            # основний React MVP-інтерфейс
└── docker-compose.yml
```

## Демо-акаунти

Адміністратор:

```text
Email: admin@example.com
Password: admin12345
```

Читач:

```text
Email: reader@example.com
Password: reader12345
```

Бібліотекар:

```text
Email: librarian@example.com
Password: librarian12345
```

Адміністратор створюється в `backend/entrypoint.sh`. Читач і бібліотекар додаються через `backend/init_db.sql` під час першої ініціалізації PostgreSQL volume.

## Запуск через Docker

У корені проєкту:

```bash
docker compose up --build
```

Після запуску:

- backend API: `http://localhost:8000`
- Django admin: `http://localhost:8000/admin/`
- PostgreSQL: `localhost:5432`

Docker Compose піднімає базу даних і backend. Frontend запускається окремо.

## Запуск frontend

У новому терміналі:

```bash
cd frontend
npm install
npm start
```

Frontend буде доступний за адресою:

```text
http://localhost:3000
```

Якщо backend працює не на `http://localhost:8000`, задайте змінну:

```bash
REACT_APP_API_BASE=http://localhost:8000 npm start
```

## API-ендпоінти

Основні маршрути:

- `POST /api/v1/auth/login/` - вхід;
- `POST /api/v1/auth/register/` - реєстрація читача;
- `GET /api/v1/auth/me/` - поточний користувач;
- `GET /api/v1/books/` - каталог;
- `GET /api/v1/books/<id>/` - MARC21-дані книги;
- `POST /api/v1/loans/borrow/` - видача книги читачу;
- `POST /api/v1/loans/<id>/return/` - повернення книги читачем;
- `GET /api/v1/librarian/loans/active/` - активні формуляри для бібліотекаря;
- `POST /api/v1/librarian/loans/<id>/return/` - приймання книги бібліотекарем;
- `GET /api/v1/ratings/` - оцінки користувача;
- `POST /api/v1/ratings/` - створення оцінки;
- `POST /api/v1/ai/recommendations/` - персональні рекомендації;
- `POST /api/v1/ai/train/` - примусове перенавчання SVD, тільки admin;
- `GET /api/v1/ai/stats/` - останні метрики моделі.

## Панель адміністратора ШІ

Адміністратор має окремий режим у вкладці `ШІ`.

Панель містить:

- графічні шкали `RMSE` та `MAE`;
- статус якості моделі;
- попередження про підвищену або критичну похибку;
- кнопку `Примусово перенавчити SVD`;
- покроковий лог епох градієнтного спуску;
- Python/SVD-логи у нижньому терміналі.

Пороги попереджень у frontend:

```text
Warning:  RMSE >= 1.0 або MAE >= 0.8
Critical: RMSE >= 1.5 або MAE >= 1.2
```

Якщо критична похибка виявлена після завантаження статистики або перенавчання, подія також записується в термінал логів розробника.

## Термінал логів розробника

У нижній частині інтерфейсу розташований інтерактивний термінал. Він показує:

- HTTP/API-запити з frontend;
- фізичні SQL-запити, які повертає backend у полі `log`;
- Python-логи рекомендаційного модуля;
- повідомлення про помилки.

Це зроблено для наочного захисту MVP: комісія бачить, як дія в UI пов'язана з PostgreSQL і математичним модулем Surprise.

## Рекомендаційний модуль

Файл: `backend/recommendations/recommender.py`.

Модуль:

- читає оцінки з таблиці `ratings`;
- формує Surprise `Dataset`;
- навчає `SVD(n_factors=60, n_epochs=30, lr_all=0.005, reg_all=0.04)`;
- рахує `RMSE` та `MAE`;
- зберігає модель у `media/models/svd_model.pkl`;
- записує метрики в таблицю `model_stats`;
- повертає `epoch_logs` і `python_logs` для UI.

Якщо оцінок замало, зберігається fallback-модель холодного старту.

## Корисні команди

Перевірити backend:

```bash
cd backend
python manage.py check
```

Зібрати frontend:

```bash
cd frontend
npm run build
```

Перезапустити тільки backend-контейнер:

```bash
docker compose restart backend
```

Переглянути логи backend:

```bash
docker logs smartlibrary_backend
```

## Примітка про базу даних

`init_db.sql` виконується лише під час першого створення PostgreSQL volume. Якщо змінити початкові SQL-дані після першого запуску, вони не застосуються автоматично до вже існуючого volume.

Для повного перестворення бази:

```bash
docker compose down -v
docker compose up --build
```

Ця команда видаляє PostgreSQL volume разом із даними.
