-- Этап 1. Создание и заполнение БД
-- Пропущена часть с созданием схемы и таблицы, делал через Helicopter и временные таблицы

-- Эта часть кода нужна так, как делал последовательно, через временные таблицы
DROP TABLE IF EXISTS origins CASCADE;
DROP TABLE IF EXISTS clients CASCADE;
DROP TABLE IF EXISTS colors CASCADE;
DROP TABLE IF EXISTS models CASCADE;
DROP TABLE IF EXISTS sales CASCADE;
-- CONSTRAINT закоменчен, т.к. делал на GP, там нет такого функционала
-- WITH (appendonly=false) тоже необходимость, из-за работы в ГП
CREATE TABLE origins(
    id SERIAL PRIMARY KEY,
    origin_name VARCHAR NOT NULL -- UNIQUE
) WITH (appendonly=false);


CREATE TABLE clients(
    id SERIAL PRIMARY KEY,
    name VARCHAR,
    phone VARCHAR
    --CONSTRAINT name_phone_unique(phone, name)
) WITH (appendonly=false);

CREATE TABLE colors(
    id SERIAL PRIMARY KEY,
    color_name VARCHAR NOT NULL -- UNIQUE
) WITH (appendonly=false);


CREATE TABLE models(
    id SERIAL PRIMARY KEY,
    model_name VARCHAR NOT NULL, -- UNIQUE,
    origin_id INTEGER REFERENCES origins,
    gasoline_consumption numeric(3,1)
) WITH (appendonly=false);

CREATE TABLE sales(
    id SERIAL PRIMARY KEY,
    car_id integer REFERENCES models NOT NULL,
    color_id integer REFERENCES colors NOT NULL,
    sale_date date NOT NULL,
    price numeric(9,2) NOT NULL,
    client_id integer REFERENCES clients NOT NULL,
    discount integer NOT NULL -- CHECK(discount >= 0) DEFAULT 0
) WITH (appendonly=false);

-- Заполняем таблицы
INSERT INTO origins (origin_name)
SELECT DISTINCT brand_origin
FROM temp_table
WHERE brand_origin IS NOT NULL;

-- select * from origins; -- использовал для самопроверки

INSERT INTO clients(name, phone)
SELECT DISTINCT person_name, phone
FROM temp_table;

-- select * from clients; -- использовал для самопроверки

INSERT INTO colors (color_name)
SELECT DISTINCT SPLIT_PART(auto, ', ', 2)
FROM temp_table;

-- select * from colors; -- использовал для самопроверки

INSERT INTO models(model_name, origin_id, gasoline_consumption)
SELECT DISTINCT SPLIT_PART(t.auto, ', ', 1),
    o.id,
    t.gasoline_consumption
FROM temp_table as t
LEFT JOIN origins as o ON o.origin_name = t.brand_origin;

-- select * from models; -- использовал для самопроверки


INSERT INTO sales (id, car_id, color_id, sale_date, price, client_id, discount)
SELECT 
    t.id,
    m.id as model_id,
    col.id as color_id,
    t.date :: date,
    t.price,
    cl.id as client_id,
    t.discount  
FROM temp_table as t
LEFT JOIN models as m ON SPLIT_PART(t.auto, ', ', 1) = m.model_name
LEFT JOIN colors as col ON SPLIT_PART(t.auto, ', ', 2) = col.color_name
LEFT JOIN clients as cl ON (t.person_name = cl.name AND t.phone = cl.phone);

-- select * from sales; -- использовал для самопроверки



-- Этап 2. Создание выборок

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.



---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.



---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.



---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.



---- Задание 5. Напишите запрос, который покажет количество всех пользователей из США.




