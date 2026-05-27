
WITH seed(title, full_name, genre_name, isbn, publisher, publication_year, total_copies) AS (
    VALUES
    ('Ліва рука темряви', 'Урсула Ле Гуїн', 'Фантастика', '9780441478125', 'Ace Books', 1969, 4),
    ('Дюна', 'Френк Герберт', 'Фантастика', '9780441172719', 'Chilton Books', 1965, 6),
    ('Кінець дитинства', 'Артур Кларк', 'Фантастика', '9780345347954', 'Ballantine Books', 1953, 3),
    ('451 градус за Фаренгейтом', 'Рей Бредбері', 'Фантастика', '9781451673319', 'Simon and Schuster', 1953, 5),
    ('Соляріс', 'Станіслав Лем', 'Фантастика', '9780156027601', 'Harcourt', 1961, 4),
    ('Егоїстичний ген', 'Річард Докінз', 'Наука', '9780199291151', 'Oxford University Press', 1976, 4),
    ('Коротка історія часу', 'Стівен Гокінг', 'Наука', '9780553380163', 'Bantam Books', 1988, 5),
    ('Ви, звичайно, жартуєте, містере Фейнмане', 'Річард Фейнман', 'Наука', '9780393316049', 'W. W. Norton', 1985, 3),
    ('Хаос: створення нової науки', 'Джеймс Глік', 'Наука', '9780143113454', 'Penguin Books', 1987, 4),
    ('Коротка історія майже всього', 'Білл Брайсон', 'Наука', '9780767908184', 'Broadway Books', 2003, 5),
    ('Вік революцій', 'Ерік Гобсбаум', 'Історія', '9780679772538', 'Vintage', 1962, 3),
    ('Криваві землі', 'Тімоті Снайдер', 'Історія', '9780465031474', 'Basic Books', 2010, 4),
    ('ГУЛАГ', 'Енн Епплбом', 'Історія', '9781400034093', 'Anchor Books', 2003, 3),
    ('Європа: історія', 'Норман Дейвіс', 'Історія', '9780060974688', 'Oxford University Press', 1996, 4),
    ('Україна: історія', 'Орест Субтельний', 'Історія', '9781442609914', 'University of Toronto Press', 1988, 5),
    ('Чистий код', 'Роберт Мартін', 'Програмування', '9780132350884', 'Prentice Hall', 2008, 6),
    ('Рефакторинг', 'Мартін Фаулер', 'Програмування', '9780134757599', 'Addison-Wesley', 2018, 4),
    ('Предметно-орієнтоване проєктування', 'Ерік Еванс', 'Програмування', '9780321125217', 'Addison-Wesley', 2003, 3),
    ('Програміст-прагматик', 'Ендрю Гант', 'Програмування', '9780135957059', 'Addison-Wesley', 2019, 5),
    ('Програміст-прагматик: практика', 'Дейвід Томас', 'Програмування', '9780201616224', 'Addison-Wesley', 1999, 4),
    ('Мислення розвитку', 'Керол Двек', 'Психологія', '9780345472328', 'Random House', 2006, 4),
    ('Психологія впливу', 'Роберт Чалдіні', 'Психологія', '9780061241895', 'Harper Business', 1984, 5),
    ('Людина в пошуках справжнього сенсу', 'Віктор Франкл', 'Психологія', '9780807014295', 'Beacon Press', 1946, 4),
    ('Чоловік, який сплутав дружину з капелюхом', 'Олівер Сакс', 'Психологія', '9780684853949', 'Touchstone', 1985, 3),
    ('Праведний розум', 'Джонатан Гайдт', 'Психологія', '9780307455772', 'Pantheon', 2012, 4),
    ('Снігопад', 'Ніл Стівенсон', 'Фантастика', '9780553380958', 'Bantam Books', 1992, 4),
    ('Нейромант', 'Вільям Гібсон', 'Фантастика', '9780441569595', 'Ace Books', 1984, 5),
    ('Проблема трьох тіл', 'Лю Цисінь', 'Фантастика', '9780765382030', 'Tor Books', 2008, 5),
    ('Франкенштайн', 'Мері Шеллі', 'Фантастика', '9780486282114', 'Dover Publications', 1818, 4),
    ('1984', 'Джордж Орвелл', 'Фантастика', '9780451524935', 'Signet Classics', 1949, 6),
    ('Сім коротких лекцій з фізики', 'Карло Ровеллі', 'Наука', '9780399184413', 'Riverhead Books', 2014, 3),
    ('Різноманіття життя', 'Едвард Вілсон', 'Наука', '9780679768111', 'Harvard University Press', 1992, 3),
    ('Астрофізика для тих, хто поспішає', 'Ніл Деграсс Тайсон', 'Наука', '9780393609394', 'W. W. Norton', 2017, 5),
    ('Фізика майбутнього', 'Мічіо Каку', 'Наука', '9780307473332', 'Doubleday', 2011, 4),
    ('Зброя, мікроби і сталь', 'Джаред Даймонд', 'Історія', '9780393317558', 'W. W. Norton', 1997, 5),
    ('Брама Європи', 'Сергій Плохій', 'Історія', '9780465094868', 'Basic Books', 2015, 4),
    ('Сталінград', 'Ентоні Бівор', 'Історія', '9780140284584', 'Penguin Books', 1998, 3),
    ('SPQR: історія Давнього Риму', 'Мері Бірд', 'Історія', '9780871404237', 'Liveright', 2015, 4),
    ('Домініон', 'Том Голланд', 'Історія', '9780465093502', 'Basic Books', 2019, 3),
    ('Екстремальне програмування', 'Кент Бек', 'Програмування', '9780321278654', 'Addison-Wesley', 2004, 3),
    ('Ефективна Java', 'Джошуа Блох', 'Програмування', '9780134685991', 'Addison-Wesley', 2018, 4),
    ('Мова програмування C', 'Браян Керніган', 'Програмування', '9780131103627', 'Prentice Hall', 1988, 5),
    ('Unix і C: практичні основи', 'Денніс Рітчі', 'Програмування', '9780139376818', 'Prentice Hall', 1989, 3),
    ('Досконалий код', 'Стів Макконнелл', 'Програмування', '9780735619678', 'Microsoft Press', 2004, 4),
    ('Шаблони проєктування', 'Еріх Гамма', 'Програмування', '9780201633610', 'Addison-Wesley', 1994, 4)
),
inserted_authors AS (
    INSERT INTO authors (full_name, biography)
    SELECT DISTINCT seed.full_name, 'Демо-автор для розширеного каталогу SmartLibraryAI.'
    FROM seed
    WHERE NOT EXISTS (
        SELECT 1 FROM authors WHERE authors.full_name = seed.full_name
    )
    RETURNING author_id, full_name
),
all_authors AS (
    SELECT author_id, full_name FROM inserted_authors
    UNION
    SELECT authors.author_id, authors.full_name
    FROM authors
    JOIN seed ON seed.full_name = authors.full_name
),
inserted_books AS (
    INSERT INTO books (genre_id, title, isbn, publisher, publication_year, total_copies, available_copies, marc21_raw)
    SELECT
        genres.genre_id,
        seed.title,
        seed.isbn,
        seed.publisher,
        seed.publication_year,
        seed.total_copies,
        seed.total_copies,
        jsonb_build_object(
            'leader', '00000nam a2200000 i 4500',
            'fields', jsonb_build_object(
                '020', seed.isbn,
                '100', seed.full_name,
                '245', seed.title,
                '260', seed.publisher,
                '650', seed.genre_name
            )
        )
    FROM seed
    JOIN genres ON genres.name = seed.genre_name
    ON CONFLICT (isbn) DO NOTHING
    RETURNING book_id, title
),
all_books AS (
    SELECT book_id, title FROM inserted_books
    UNION
    SELECT books.book_id, books.title
    FROM books
    JOIN seed ON seed.title = books.title
)
INSERT INTO book_authors (book_id, author_id)
SELECT all_books.book_id, all_authors.author_id
FROM seed
JOIN all_books ON all_books.title = seed.title
JOIN all_authors ON all_authors.full_name = seed.full_name
ON CONFLICT DO NOTHING;
