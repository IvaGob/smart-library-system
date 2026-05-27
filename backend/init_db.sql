CREATE TABLE IF NOT EXISTS users (
    user_id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'reader',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS profiles (
    profile_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NULL,
    registration_date DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE IF NOT EXISTS genres (
    genre_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT NULL
);

CREATE TABLE IF NOT EXISTS books (
    book_id SERIAL PRIMARY KEY,
    genre_id INT NULL REFERENCES genres(genre_id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    isbn VARCHAR(20) NOT NULL UNIQUE,
    publisher VARCHAR(150) NULL,
    publication_year INT NULL,
    total_copies INT NOT NULL DEFAULT 1 CHECK (total_copies >= 0),
    available_copies INT NOT NULL DEFAULT 1 CHECK (available_copies >= 0 AND available_copies <= total_copies),
    marc21_raw JSONB NOT NULL,
    added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS authors (
    author_id SERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    biography TEXT NULL
);

CREATE TABLE IF NOT EXISTS book_authors (
    book_id INT NOT NULL REFERENCES books(book_id) ON DELETE CASCADE,
    author_id INT NOT NULL REFERENCES authors(author_id) ON DELETE CASCADE,
    PRIMARY KEY (book_id, author_id)
);

CREATE TABLE IF NOT EXISTS loans (
    loan_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    book_id INT NOT NULL,
    borrow_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL,
    return_date DATE NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS reservations (
    reservation_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    book_id INT NOT NULL,
    reserved_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expiration_date TIMESTAMP NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending'
);

CREATE TABLE IF NOT EXISTS ratings (
    rating_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    book_id INT NOT NULL,
    value INT NOT NULL CHECK (value >= 1 AND value <= 5),
    rated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ratings_user_book UNIQUE (user_id, book_id)
);

CREATE TABLE IF NOT EXISTS interactions (
    interaction_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    book_id INT NOT NULL,
    interaction_type VARCHAR(50) NOT NULL,
    weight REAL NOT NULL DEFAULT 0.0,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS model_stats (
    version VARCHAR(50) PRIMARY KEY,
    rmse REAL NOT NULL,
    mae REAL NOT NULL,
    weights_path VARCHAR(500) NOT NULL,
    trained_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_loans_user_book ON loans(user_id, book_id);
CREATE INDEX IF NOT EXISTS idx_reservations_user_book ON reservations(user_id, book_id);
CREATE INDEX IF NOT EXISTS idx_ratings_user_book ON ratings(user_id, book_id);
CREATE INDEX IF NOT EXISTS idx_interactions_user_book ON interactions(user_id, book_id);
CREATE INDEX IF NOT EXISTS idx_books_title ON books(title);
CREATE INDEX IF NOT EXISTS idx_books_genre ON books(genre_id);

INSERT INTO genres (name, description) VALUES
('Фантастика', 'Книги про майбутнє, технології та альтернативні світи.'),
('Наука', 'Популярна та академічна наукова література.'),
('Історія', 'Історичні дослідження та документалістика.'),
('Програмування', 'Практичні книги з розробки програмного забезпечення.'),
('Психологія', 'Книги про мислення, поведінку та комунікацію.')
ON CONFLICT (name) DO NOTHING;

INSERT INTO authors (full_name, biography) VALUES
('Айзек Азімов', 'Автор класичної наукової фантастики.'),
('Дональд Кнут', 'Дослідник алгоритмів і автор фундаментальних праць з інформатики.'),
('Ювал Ной Харарі', 'Історик і автор праць про розвиток людства.'),
('Данієл Канеман', 'Психолог, лауреат Нобелівської премії з економіки.'),
('Карл Саган', 'Астроном і популяризатор науки.')
ON CONFLICT DO NOTHING;

INSERT INTO books (genre_id, title, isbn, publisher, publication_year, total_copies, available_copies, marc21_raw) VALUES
((SELECT genre_id FROM genres WHERE name = 'Фантастика'), 'Фундація', '9780553293357', 'Spectra', 1951, 5, 5, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780553293357","100":"Айзек Азімов","245":"Фундація","260":"Spectra","650":"Фантастика"}}'),
((SELECT genre_id FROM genres WHERE name = 'Програмування'), 'Мистецтво програмування, том 1', '9780201896831', 'Addison-Wesley', 1997, 3, 3, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780201896831","100":"Дональд Кнут","245":"Мистецтво програмування, том 1","260":"Addison-Wesley","650":"Програмування"}}'),
((SELECT genre_id FROM genres WHERE name = 'Історія'), 'Sapiens. Людина розумна', '9780062316097', 'Harper', 2011, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780062316097","100":"Ювал Ной Харарі","245":"Sapiens. Людина розумна","260":"Harper","650":"Історія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Психологія'), 'Мислення швидке й повільне', '9780374533557', 'Farrar, Straus and Giroux', 2011, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780374533557","100":"Данієл Канеман","245":"Мислення швидке й повільне","260":"Farrar, Straus and Giroux","650":"Психологія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Наука'), 'Космос', '9780345539434', 'Random House', 1980, 6, 6, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780345539434","100":"Карл Саган","245":"Космос","260":"Random House","650":"Наука"}}')
ON CONFLICT (isbn) DO NOTHING;

INSERT INTO book_authors (book_id, author_id)
SELECT b.book_id, a.author_id FROM books b JOIN authors a ON
    (b.title = 'Фундація' AND a.full_name = 'Айзек Азімов')
    OR (b.title = 'Мистецтво програмування, том 1' AND a.full_name = 'Дональд Кнут')
    OR (b.title = 'Sapiens. Людина розумна' AND a.full_name = 'Ювал Ной Харарі')
    OR (b.title = 'Мислення швидке й повільне' AND a.full_name = 'Данієл Канеман')
    OR (b.title = 'Космос' AND a.full_name = 'Карл Саган')
ON CONFLICT DO NOTHING;

INSERT INTO users (email, password_hash, role) VALUES
('reader@example.com', 'pbkdf2_sha256$1200000$smartlibrary2026$kA/T8YIT32uv2KfZaYBltyqsfWteN5YflZcw0xaCarM=', 'reader'),
('librarian@example.com', 'pbkdf2_sha256$1200000$smartlibrary2026$enYIMKce2hWtjjOrKG7eXfFoBcThpQbS6c4uoWVall0=', 'librarian')
ON CONFLICT (email) DO NOTHING;

INSERT INTO profiles (user_id, first_name, last_name, phone)
SELECT user_id, 'Марія', 'Коваленко', '+380501112233' FROM users WHERE email = 'reader@example.com'
AND NOT EXISTS (
    SELECT 1 FROM profiles WHERE profiles.user_id = users.user_id
);

INSERT INTO profiles (user_id, first_name, last_name, phone)
SELECT user_id, 'Олег', 'Бібліотекар', '+380501114455' FROM users WHERE email = 'librarian@example.com'
AND NOT EXISTS (
    SELECT 1 FROM profiles WHERE profiles.user_id = users.user_id
);

INSERT INTO ratings (user_id, book_id, value)
SELECT u.user_id, b.book_id, seed.value
FROM (VALUES
    ('reader@example.com', 'Фундація', 5),
    ('reader@example.com', 'Космос', 4),
    ('librarian@example.com', 'Sapiens. Людина розумна', 5),
    ('librarian@example.com', 'Мистецтво програмування, том 1', 4)
) AS seed(email, title, value)
JOIN users u ON u.email = seed.email
JOIN books b ON b.title = seed.title
ON CONFLICT (user_id, book_id) DO UPDATE SET value = EXCLUDED.value;

INSERT INTO authors (full_name, biography) VALUES
('Урсула Ле Гуїн', 'Авторка філософської фантастики та фентезі.'),
('Френк Герберт', 'Письменник, відомий масштабними науково-фантастичними світами.'),
('Артур Кларк', 'Класик твердої наукової фантастики.'),
('Рей Бредбері', 'Автор поетичної фантастики та антиутопій.'),
('Станіслав Лем', 'Польський письменник і мислитель про майбутнє технологій.'),
('Річард Докінз', 'Біолог і популяризатор еволюційної науки.'),
('Стівен Гокінг', 'Фізик-теоретик і популяризатор космології.'),
('Річард Фейнман', 'Фізик і блискучий викладач науки.'),
('Джеймс Глік', 'Автор науково-популярних книг про хаос і інформацію.'),
('Білл Брайсон', 'Автор доступних науково-популярних оглядів.'),
('Ерік Гобсбаум', 'Історик модерної Європи.'),
('Тімоті Снайдер', 'Історик Центральної та Східної Європи.'),
('Енн Епплбом', 'Дослідниця тоталітаризму та політичної історії.'),
('Норман Дейвіс', 'Історик Європи та Польщі.'),
('Орест Субтельний', 'Історик України.'),
('Роберт Мартін', 'Інженер і автор книг про якісний код.'),
('Мартін Фаулер', 'Автор праць про архітектуру та рефакторинг.'),
('Ерік Еванс', 'Автор концепції предметно-орієнтованого проєктування.'),
('Ендрю Гант', 'Співавтор практичних посібників для програмістів.'),
('Дейвід Томас', 'Співавтор практичних посібників для програмістів.'),
('Керол Двек', 'Дослідниця мислення розвитку.'),
('Роберт Чалдіні', 'Психолог, дослідник впливу та переконання.'),
('Віктор Франкл', 'Психіатр і автор праць про сенс життя.'),
('Олівер Сакс', 'Невролог і автор клінічних історій.'),
('Джонатан Гайдт', 'Психолог моралі та соціальної поведінки.'),
('Ніл Стівенсон', 'Автор кіберпанку та технологічної фантастики.'),
('Вільям Гібсон', 'Один із засновників кіберпанку.'),
('Лю Цисінь', 'Автор сучасної китайської наукової фантастики.'),
('Мері Шеллі', 'Авторка ранньої наукової фантастики.'),
('Джордж Орвелл', 'Автор антиутопій і політичної прози.'),
('Карло Ровеллі', 'Фізик і популяризатор сучасної науки.'),
('Едвард Вілсон', 'Біолог і дослідник біорізноманіття.'),
('Ніл Деграсс Тайсон', 'Астрофізик і популяризатор космосу.'),
('Мічіо Каку', 'Фізик і популяризатор майбутніх технологій.'),
('Джаред Даймонд', 'Дослідник історії цивілізацій.'),
('Сергій Плохій', 'Історик України та Східної Європи.'),
('Ентоні Бівор', 'Автор військово-історичних досліджень.'),
('Мері Бірд', 'Історикиня античного світу.'),
('Том Голланд', 'Автор історичних наративів про цивілізації.'),
('Кент Бек', 'Автор практик екстремального програмування.'),
('Джошуа Блох', 'Автор книг про ефективне програмування.'),
('Браян Керніган', 'Співавтор класичних текстів з програмування.'),
('Денніс Рітчі', 'Творець мови C та співавтор Unix.'),
('Стів Макконнелл', 'Автор практик конструювання програмного забезпечення.'),
('Еріх Гамма', 'Співавтор книги про шаблони проєктування.')
ON CONFLICT DO NOTHING;

INSERT INTO books (genre_id, title, isbn, publisher, publication_year, total_copies, available_copies, marc21_raw) VALUES
((SELECT genre_id FROM genres WHERE name = 'Фантастика'), 'Ліва рука темряви', '9780441478125', 'Ace Books', 1969, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780441478125","100":"Урсула Ле Гуїн","245":"Ліва рука темряви","260":"Ace Books","650":"Фантастика"}}'),
((SELECT genre_id FROM genres WHERE name = 'Фантастика'), 'Дюна', '9780441172719', 'Chilton Books', 1965, 6, 6, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780441172719","100":"Френк Герберт","245":"Дюна","260":"Chilton Books","650":"Фантастика"}}'),
((SELECT genre_id FROM genres WHERE name = 'Фантастика'), 'Кінець дитинства', '9780345347954', 'Ballantine Books', 1953, 3, 3, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780345347954","100":"Артур Кларк","245":"Кінець дитинства","260":"Ballantine Books","650":"Фантастика"}}'),
((SELECT genre_id FROM genres WHERE name = 'Фантастика'), '451 градус за Фаренгейтом', '9781451673319', 'Simon and Schuster', 1953, 5, 5, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9781451673319","100":"Рей Бредбері","245":"451 градус за Фаренгейтом","260":"Simon and Schuster","650":"Фантастика"}}'),
((SELECT genre_id FROM genres WHERE name = 'Фантастика'), 'Соляріс', '9780156027601', 'Harcourt', 1961, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780156027601","100":"Станіслав Лем","245":"Соляріс","260":"Harcourt","650":"Фантастика"}}'),
((SELECT genre_id FROM genres WHERE name = 'Наука'), 'Егоїстичний ген', '9780199291151', 'Oxford University Press', 1976, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780199291151","100":"Річард Докінз","245":"Егоїстичний ген","260":"Oxford University Press","650":"Наука"}}'),
((SELECT genre_id FROM genres WHERE name = 'Наука'), 'Коротка історія часу', '9780553380163', 'Bantam Books', 1988, 5, 5, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780553380163","100":"Стівен Гокінг","245":"Коротка історія часу","260":"Bantam Books","650":"Наука"}}'),
((SELECT genre_id FROM genres WHERE name = 'Наука'), 'Ви, звичайно, жартуєте, містере Фейнмане', '9780393316049', 'W. W. Norton', 1985, 3, 3, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780393316049","100":"Річард Фейнман","245":"Ви, звичайно, жартуєте, містере Фейнмане","260":"W. W. Norton","650":"Наука"}}'),
((SELECT genre_id FROM genres WHERE name = 'Наука'), 'Хаос: створення нової науки', '9780143113454', 'Penguin Books', 1987, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780143113454","100":"Джеймс Глік","245":"Хаос: створення нової науки","260":"Penguin Books","650":"Наука"}}'),
((SELECT genre_id FROM genres WHERE name = 'Наука'), 'Коротка історія майже всього', '9780767908184', 'Broadway Books', 2003, 5, 5, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780767908184","100":"Білл Брайсон","245":"Коротка історія майже всього","260":"Broadway Books","650":"Наука"}}'),
((SELECT genre_id FROM genres WHERE name = 'Історія'), 'Вік революцій', '9780679772538', 'Vintage', 1962, 3, 3, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780679772538","100":"Ерік Гобсбаум","245":"Вік революцій","260":"Vintage","650":"Історія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Історія'), 'Криваві землі', '9780465031474', 'Basic Books', 2010, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780465031474","100":"Тімоті Снайдер","245":"Криваві землі","260":"Basic Books","650":"Історія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Історія'), 'ГУЛАГ', '9781400034093', 'Anchor Books', 2003, 3, 3, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9781400034093","100":"Енн Епплбом","245":"ГУЛАГ","260":"Anchor Books","650":"Історія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Історія'), 'Європа: історія', '9780060974688', 'Oxford University Press', 1996, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780060974688","100":"Норман Дейвіс","245":"Європа: історія","260":"Oxford University Press","650":"Історія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Історія'), 'Україна: історія', '9781442609914', 'University of Toronto Press', 1988, 5, 5, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9781442609914","100":"Орест Субтельний","245":"Україна: історія","260":"University of Toronto Press","650":"Історія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Програмування'), 'Чистий код', '9780132350884', 'Prentice Hall', 2008, 6, 6, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780132350884","100":"Роберт Мартін","245":"Чистий код","260":"Prentice Hall","650":"Програмування"}}'),
((SELECT genre_id FROM genres WHERE name = 'Програмування'), 'Рефакторинг', '9780134757599', 'Addison-Wesley', 2018, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780134757599","100":"Мартін Фаулер","245":"Рефакторинг","260":"Addison-Wesley","650":"Програмування"}}'),
((SELECT genre_id FROM genres WHERE name = 'Програмування'), 'Предметно-орієнтоване проєктування', '9780321125217', 'Addison-Wesley', 2003, 3, 3, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780321125217","100":"Ерік Еванс","245":"Предметно-орієнтоване проєктування","260":"Addison-Wesley","650":"Програмування"}}'),
((SELECT genre_id FROM genres WHERE name = 'Програмування'), 'Програміст-прагматик', '9780135957059', 'Addison-Wesley', 2019, 5, 5, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780135957059","100":"Ендрю Гант","245":"Програміст-прагматик","260":"Addison-Wesley","650":"Програмування"}}'),
((SELECT genre_id FROM genres WHERE name = 'Програмування'), 'Програміст-прагматик: практика', '9780201616224', 'Addison-Wesley', 1999, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780201616224","100":"Дейвід Томас","245":"Програміст-прагматик: практика","260":"Addison-Wesley","650":"Програмування"}}'),
((SELECT genre_id FROM genres WHERE name = 'Психологія'), 'Мислення розвитку', '9780345472328', 'Random House', 2006, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780345472328","100":"Керол Двек","245":"Мислення розвитку","260":"Random House","650":"Психологія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Психологія'), 'Психологія впливу', '9780061241895', 'Harper Business', 1984, 5, 5, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780061241895","100":"Роберт Чалдіні","245":"Психологія впливу","260":"Harper Business","650":"Психологія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Психологія'), 'Людина в пошуках справжнього сенсу', '9780807014295', 'Beacon Press', 1946, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780807014295","100":"Віктор Франкл","245":"Людина в пошуках справжнього сенсу","260":"Beacon Press","650":"Психологія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Психологія'), 'Чоловік, який сплутав дружину з капелюхом', '9780684853949', 'Touchstone', 1985, 3, 3, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780684853949","100":"Олівер Сакс","245":"Чоловік, який сплутав дружину з капелюхом","260":"Touchstone","650":"Психологія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Психологія'), 'Праведний розум', '9780307455772', 'Pantheon', 2012, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780307455772","100":"Джонатан Гайдт","245":"Праведний розум","260":"Pantheon","650":"Психологія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Фантастика'), 'Снігопад', '9780553380958', 'Bantam Books', 1992, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780553380958","100":"Ніл Стівенсон","245":"Снігопад","260":"Bantam Books","650":"Фантастика"}}'),
((SELECT genre_id FROM genres WHERE name = 'Фантастика'), 'Нейромант', '9780441569595', 'Ace Books', 1984, 5, 5, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780441569595","100":"Вільям Гібсон","245":"Нейромант","260":"Ace Books","650":"Фантастика"}}'),
((SELECT genre_id FROM genres WHERE name = 'Фантастика'), 'Проблема трьох тіл', '9780765382030', 'Tor Books', 2008, 5, 5, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780765382030","100":"Лю Цисінь","245":"Проблема трьох тіл","260":"Tor Books","650":"Фантастика"}}'),
((SELECT genre_id FROM genres WHERE name = 'Фантастика'), 'Франкенштайн', '9780486282114', 'Dover Publications', 1818, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780486282114","100":"Мері Шеллі","245":"Франкенштайн","260":"Dover Publications","650":"Фантастика"}}'),
((SELECT genre_id FROM genres WHERE name = 'Фантастика'), '1984', '9780451524935', 'Signet Classics', 1949, 6, 6, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780451524935","100":"Джордж Орвелл","245":"1984","260":"Signet Classics","650":"Фантастика"}}'),
((SELECT genre_id FROM genres WHERE name = 'Наука'), 'Сім коротких лекцій з фізики', '9780399184413', 'Riverhead Books', 2014, 3, 3, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780399184413","100":"Карло Ровеллі","245":"Сім коротких лекцій з фізики","260":"Riverhead Books","650":"Наука"}}'),
((SELECT genre_id FROM genres WHERE name = 'Наука'), 'Різноманіття життя', '9780679768111', 'Harvard University Press', 1992, 3, 3, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780679768111","100":"Едвард Вілсон","245":"Різноманіття життя","260":"Harvard University Press","650":"Наука"}}'),
((SELECT genre_id FROM genres WHERE name = 'Наука'), 'Астрофізика для тих, хто поспішає', '9780393609394', 'W. W. Norton', 2017, 5, 5, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780393609394","100":"Ніл Деграсс Тайсон","245":"Астрофізика для тих, хто поспішає","260":"W. W. Norton","650":"Наука"}}'),
((SELECT genre_id FROM genres WHERE name = 'Наука'), 'Фізика майбутнього', '9780307473332', 'Doubleday', 2011, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780307473332","100":"Мічіо Каку","245":"Фізика майбутнього","260":"Doubleday","650":"Наука"}}'),
((SELECT genre_id FROM genres WHERE name = 'Історія'), 'Зброя, мікроби і сталь', '9780393317558', 'W. W. Norton', 1997, 5, 5, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780393317558","100":"Джаред Даймонд","245":"Зброя, мікроби і сталь","260":"W. W. Norton","650":"Історія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Історія'), 'Брама Європи', '9780465094868', 'Basic Books', 2015, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780465094868","100":"Сергій Плохій","245":"Брама Європи","260":"Basic Books","650":"Історія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Історія'), 'Сталінград', '9780140284584', 'Penguin Books', 1998, 3, 3, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780140284584","100":"Ентоні Бівор","245":"Сталінград","260":"Penguin Books","650":"Історія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Історія'), 'SPQR: історія Давнього Риму', '9780871404237', 'Liveright', 2015, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780871404237","100":"Мері Бірд","245":"SPQR: історія Давнього Риму","260":"Liveright","650":"Історія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Історія'), 'Домініон', '9780465093502', 'Basic Books', 2019, 3, 3, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780465093502","100":"Том Голланд","245":"Домініон","260":"Basic Books","650":"Історія"}}'),
((SELECT genre_id FROM genres WHERE name = 'Програмування'), 'Екстремальне програмування', '9780321278654', 'Addison-Wesley', 2004, 3, 3, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780321278654","100":"Кент Бек","245":"Екстремальне програмування","260":"Addison-Wesley","650":"Програмування"}}'),
((SELECT genre_id FROM genres WHERE name = 'Програмування'), 'Ефективна Java', '9780134685991', 'Addison-Wesley', 2018, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780134685991","100":"Джошуа Блох","245":"Ефективна Java","260":"Addison-Wesley","650":"Програмування"}}'),
((SELECT genre_id FROM genres WHERE name = 'Програмування'), 'Мова програмування C', '9780131103627', 'Prentice Hall', 1988, 5, 5, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780131103627","100":"Браян Керніган","245":"Мова програмування C","260":"Prentice Hall","650":"Програмування"}}'),
((SELECT genre_id FROM genres WHERE name = 'Програмування'), 'Unix і C: практичні основи', '9780139376818', 'Prentice Hall', 1989, 3, 3, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780139376818","100":"Денніс Рітчі","245":"Unix і C: практичні основи","260":"Prentice Hall","650":"Програмування"}}'),
((SELECT genre_id FROM genres WHERE name = 'Програмування'), 'Досконалий код', '9780735619678', 'Microsoft Press', 2004, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780735619678","100":"Стів Макконнелл","245":"Досконалий код","260":"Microsoft Press","650":"Програмування"}}'),
((SELECT genre_id FROM genres WHERE name = 'Програмування'), 'Шаблони проєктування', '9780201633610', 'Addison-Wesley', 1994, 4, 4, '{"leader":"00000nam a2200000 i 4500","fields":{"020":"9780201633610","100":"Еріх Гамма","245":"Шаблони проєктування","260":"Addison-Wesley","650":"Програмування"}}')
ON CONFLICT (isbn) DO NOTHING;

INSERT INTO book_authors (book_id, author_id)
SELECT b.book_id, a.author_id
FROM (VALUES
    ('Ліва рука темряви', 'Урсула Ле Гуїн'),
    ('Дюна', 'Френк Герберт'),
    ('Кінець дитинства', 'Артур Кларк'),
    ('451 градус за Фаренгейтом', 'Рей Бредбері'),
    ('Соляріс', 'Станіслав Лем'),
    ('Егоїстичний ген', 'Річард Докінз'),
    ('Коротка історія часу', 'Стівен Гокінг'),
    ('Ви, звичайно, жартуєте, містере Фейнмане', 'Річард Фейнман'),
    ('Хаос: створення нової науки', 'Джеймс Глік'),
    ('Коротка історія майже всього', 'Білл Брайсон'),
    ('Вік революцій', 'Ерік Гобсбаум'),
    ('Криваві землі', 'Тімоті Снайдер'),
    ('ГУЛАГ', 'Енн Епплбом'),
    ('Європа: історія', 'Норман Дейвіс'),
    ('Україна: історія', 'Орест Субтельний'),
    ('Чистий код', 'Роберт Мартін'),
    ('Рефакторинг', 'Мартін Фаулер'),
    ('Предметно-орієнтоване проєктування', 'Ерік Еванс'),
    ('Програміст-прагматик', 'Ендрю Гант'),
    ('Програміст-прагматик: практика', 'Дейвід Томас'),
    ('Мислення розвитку', 'Керол Двек'),
    ('Психологія впливу', 'Роберт Чалдіні'),
    ('Людина в пошуках справжнього сенсу', 'Віктор Франкл'),
    ('Чоловік, який сплутав дружину з капелюхом', 'Олівер Сакс'),
    ('Праведний розум', 'Джонатан Гайдт'),
    ('Снігопад', 'Ніл Стівенсон'),
    ('Нейромант', 'Вільям Гібсон'),
    ('Проблема трьох тіл', 'Лю Цисінь'),
    ('Франкенштайн', 'Мері Шеллі'),
    ('1984', 'Джордж Орвелл'),
    ('Сім коротких лекцій з фізики', 'Карло Ровеллі'),
    ('Різноманіття життя', 'Едвард Вілсон'),
    ('Астрофізика для тих, хто поспішає', 'Ніл Деграсс Тайсон'),
    ('Фізика майбутнього', 'Мічіо Каку'),
    ('Зброя, мікроби і сталь', 'Джаред Даймонд'),
    ('Брама Європи', 'Сергій Плохій'),
    ('Сталінград', 'Ентоні Бівор'),
    ('SPQR: історія Давнього Риму', 'Мері Бірд'),
    ('Домініон', 'Том Голланд'),
    ('Екстремальне програмування', 'Кент Бек'),
    ('Ефективна Java', 'Джошуа Блох'),
    ('Мова програмування C', 'Браян Керніган'),
    ('Unix і C: практичні основи', 'Денніс Рітчі'),
    ('Досконалий код', 'Стів Макконнелл'),
    ('Шаблони проєктування', 'Еріх Гамма')
) AS mapping(title, full_name)
JOIN books b ON b.title = mapping.title
JOIN authors a ON a.full_name = mapping.full_name
ON CONFLICT DO NOTHING;
