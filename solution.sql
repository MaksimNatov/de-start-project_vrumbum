
-- Этап 1. Создание и заполнение БД
create schema IF NOT EXISTS raw_data;

create table if not EXISTS raw_data.sales( --везде выбрал VARCHAR, преобразовывать в нужный тип буду далее
id INTEGER,
auto VARCHAR,
gasoline_consumption VARCHAR,
price VARCHAR,
date VARCHAR,
person_name VARCHAR,
phone VARCHAR,
discount VARCHAR,
brand_origin VARCHAR
);
--\copy raw_data.sales(id,auto,gasoline_consumption,price,date,person_name,phone,discount,brand_origin) FROM 'C:\Temp\cars.csv' CSV HEADER;
create schema IF NOT EXISTS car_shop;

-- Эта часть кода нужна, чтоб полноценно создались таблички ниже
DROP TABLE IF EXISTS car_shop.origins CASCADE;
DROP TABLE IF EXISTS car_shop.clients CASCADE;
DROP TABLE IF EXISTS car_shop.brands CASCADE;
DROP TABLE IF EXISTS car_shop.colors CASCADE;
DROP TABLE IF EXISTS car_shop.models CASCADE;
DROP TABLE IF EXISTS car_shop.sales CASCADE;

CREATE TABLE car_shop.origins(
    id SERIAL PRIMARY KEY, -- здесь и далее все ключи подобным образом создаются
    origin_name VARCHAR NOT NULL unique  -- страна = текст, пустой быть не может
);


CREATE TABLE car_shop.clients(
    id SERIAL PRIMARY KEY,
    name VARCHAR, -- текст, т.к. имя
    phone VARCHAR, -- текс, т.к. содержит символы +() и т.п.
    CONSTRAINT name_phone_unique unique (name, phone) -- пара имя и телефон = уникальный клиент
);

CREATE TABLE car_shop.brands(
    id SERIAL PRIMARY KEY,
    brand_name VARCHAR NOT NULL unique -- текст, т.к. имя бренда
    );

CREATE TABLE car_shop.colors(
    id SERIAL PRIMARY KEY,
    color_name VARCHAR NOT NULL unique -- не может быть пустой, название цвета = текст
);


CREATE TABLE car_shop.models(
    id SERIAL PRIMARY KEY,
    model_name VARCHAR NOT null UNIQUE, -- наименование модели, уникальное, не пустое
    brand_id INTEGER REFERENCES car_shop.brands,  -- зависимость от "словаря" стран
    origin_id INTEGER REFERENCES car_shop.origins, -- зависимость от "словаря" брендов
    gasoline_consumption numeric(3,1) -- потребление переводим в нумерик
);

CREATE TABLE car_shop.sales(
    id SERIAL PRIMARY KEY,
    car_id integer REFERENCES car_shop.models NOT NULL, -- зависимость от "словаря" моделей
    color_id integer REFERENCES car_shop.colors NOT NULL, -- зависимость от "словаря" цвета
    sale_date date NOT NULL, -- дата = дата
    price numeric(9,2) NOT NULL, -- цена = число, плюс требование в задании
    client_id integer REFERENCES car_shop.clients NOT NULL, -- зависимость от "словаря" клиента
    discount integer NOT NULL CHECK(discount >= 0) DEFAULT 0 -- дисконт = число, без дроби, по умолчанию дисконт 0
);

-- Заполняем таблицы
INSERT INTO car_shop.origins (origin_name)
SELECT DISTINCT brand_origin
FROM raw_data.sales
WHERE brand_origin IS NOT NULL;



INSERT INTO car_shop.clients(name, phone)
SELECT DISTINCT person_name, phone
FROM raw_data.sales;

INSERT INTO car_shop.brands(brand_name)
SELECT DISTINCT SPLIT_PART(auto, ' ', 1)
FROM raw_data.sales;

INSERT INTO car_shop.colors (color_name)
SELECT DISTINCT SPLIT_PART(auto, ', ', 2)
FROM raw_data.sales;



INSERT INTO car_shop.models(model_name, brand_id, origin_id, gasoline_consumption)
SELECT DISTINCT trim(substr(SPLIT_PART(t.auto, ', ', 1), position(' ' IN SPLIT_PART(t.auto, ', ', 1)) + 1)), -- получаем название модели
	b.id,
    o.id,
    case when t.gasoline_consumption = 'null' then null -- в таблице raw_data.sales, тип var поэтому null-текст надо преобразовать
    else t.gasoline_consumption
    end :: numeric(3,1)
FROM raw_data.sales as t
LEFT JOIN car_shop.origins as o ON o.origin_name = t.brand_origin
left join car_shop.brands as b on b.brand_name = SPLIT_PART(t.auto, ' ', 1);



INSERT INTO car_shop.sales (id, car_id, color_id, sale_date, price, client_id, discount)
SELECT 
    t.id,
    m.id as model_id,
    col.id as color_id,
    t.date :: date,
    t.price :: numeric(9,2),
    cl.id as client_id,
    t.discount  :: integer
FROM raw_data.sales as t
LEFT JOIN car_shop.models as m ON trim(substr(SPLIT_PART(t.auto, ', ', 1), position(' ' IN SPLIT_PART(t.auto, ', ', 1)) + 1)) = m.model_name
LEFT JOIN car_shop.colors as col ON SPLIT_PART(t.auto, ', ', 2) = col.color_name
LEFT JOIN car_shop.clients as cl ON (t.person_name = cl.name AND t.phone = cl.phone);





-- Этап 2. Создание выборок

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.
SELECT 
    (COUNT(*) FILTER (WHERE gasoline_consumption IS NULL) * 100 / COUNT(*)) as nulls_percentage_gasoline_consumption
FROM car_shop.models;    


---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.
SELECT 
    b.brand_name as brand_name,
    EXTRACT('year' FROM s.sale_date) as year,
    AVG(s.price) :: numeric(7,2) as price_avg
FROM car_shop.sales as s
LEFT JOIN car_shop.models as m ON s.car_id = m.id
left join car_shop.brands as b on b.id = m.brand_id
GROUP BY 1, 2
ORDER BY 1, 2;


---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.
SELECT 
    EXTRACT('month' FROM s.sale_date) as month,
    EXTRACT('year' FROM s.sale_date) as year,
    AVG(s.price) :: numeric(7,2)
FROM car_shop.sales as s
LEFT JOIN car_shop.models as m ON s.car_id = m.id
GROUP BY 1, 2
HAVING EXTRACT('year' FROM s.sale_date) = '2022'
ORDER BY 1, 2;


---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.
SELECT
    o.origin_name as brand_origin,
    max((s.price /(100-s.discount))*100):: numeric(7,2) as price_max,
    min((s.price /(100-s.discount))*100):: numeric(7,2) as price_min
FROM car_shop.sales as s
LEFT JOIN car_shop.models as m ON s.car_id = m.id
LEFT JOIN car_shop.origins as o ON o.id = m.origin_id
WHERE  o.origin_name != 'null' -- У порше стоит NULL, не знаю стоит, ли их относить на этапе сборке данных к какой то стране. Тут я их исключил.
GROUP BY 1;


---- Задание 5. Напишите запрос, который покажет количество всех пользователей из США.

SELECT
    COUNT(*) as persons_from_usa_count
FROM car_shop.clients
WHERE phone like '+1%';
