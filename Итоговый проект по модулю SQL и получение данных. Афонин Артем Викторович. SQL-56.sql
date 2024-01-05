-- Задание 1. Вывести названия самолётов, которые имеют менее 50 посадочных мест.

select a.aircraft_code, a.model, count (s.seat_no)
from aircrafts a
left join seats s on a.aircraft_code = s.aircraft_code
group by a.aircraft_code, a.model
having count (s.seat_no) < 50;


-- Задание 2. Вывести процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.

with cte1 as (
    select date_trunc ('month', book_date) as month,
           sum (total_amount) as total_amount_per_month
    from bookings
    group by month)
select month, total_amount_per_month,
    round (
    ((total_amount_per_month -  lag (total_amount_per_month) over (order by month)) /
      lag (total_amount_per_month) over (order by month)) * 100,
     2) as percent_change
from cte1
order by month;

-- Задание 3. Вывести названия самолётов без бизнес-класса, используя в решении функцию array_agg.

select a.model, s.fare_conditions
from aircrafts a
join (
    select aircraft_code, array_agg (fare_conditions) as fare_conditions
    from seats
    group by aircraft_code
    having not 'Business' = any (array_agg(fare_conditions))
	) as s
on a.aircraft_code = s.aircraft_code; 









-- Задание 4. Выведите накопительный итог количества мест в самолётах по каждому аэропорту на каждый день.
-- Учтите только те самолеты, которые летали пустыми и только те дни, когда из одного аэропорта вылетело более одного такого самолёта.
-- Выведите в результат код аэропорта, дату вылета, количество пустых мест и накопительный итог.

with cte1 as (
    select
        f.flight_id,
        f.departure_airport,
        f.status,
        f.aircraft_code,
        f.actual_departure::date as date,
        s.seat_no
    from
        flights f
    left join
		boarding_passes bp on bp.flight_id = f.flight_id
    join
        seats s on f.aircraft_code = s.aircraft_code
    where
        bp.boarding_no is null
        and f.status in ('Departed', 'Arrived')
--- В CTE1 вывел необходимые данные для дальнейшей работы и отфильтровал данные.
), 
cte2 as (
    select
        cte1.departure_airport,
        cte1.date,
        count (distinct cte1.aircraft_code) as aircraft_count
    from
        cte1
    group by
        cte1.departure_airport, cte1.date
    having count(distinct cte1.aircraft_code) > 1
)
--- в CTE2 посчитал кол-во самолетов, вылетевших из аропорта и отфильтровал по условию '> 1' в день.
select
    cte1.departure_airport,
    cte1.date,
    count(cte1.seat_no) as total_seats,
    sum(count(cte1.seat_no)) over (partition by cte1.departure_airport order by cte1.date) as cumulative_total_seats
from
    cte1
join
    cte2 on cte1.departure_airport = cte2.departure_airport and cte1.date = cte2.date
group by
    cte1.departure_airport, cte1.date
order by
    cte1.departure_airport;
--- В основном запросе вывел необходиммые данные, посчитал сумму и агрегацию, соедил с CTE2 двойным условием,
--- чтобы учитывались только дни, когда вылетело более 1 пустого самолета.       
   
   
   
   
   
   
   
 
-- Задание 5. Найдите процентное соотношение перелётов по маршрутам от общего количества перелётов. Выведите в результат названия аэропортов и процентное отношение.
--            Используйте в решении оконную функцию.
 
select ad.airport_name, ad2.airport_name, qq.percent
from (
	select departure_airport, arrival_airport,
	       (count(flight_id) * 100.0 / sum (count(flight_id)) over ()) as percent
	from flights
	group by departure_airport, arrival_airport
	) qq
join airports_data ad on qq.departure_airport = ad.airport_code 
join airports_data ad2 on qq.arrival_airport = ad2.airport_code 
order by percent desc 

-- Задание 6. Выведите количество пассажиров по каждому коду сотового оператора. Код оператора – это три символа после +7

select
    substring (phone_number, position('+7' in phone_number) + 2, 3) as region_code,
    count (*) as region_code_count
from (
    select contact_data ->>'phone' as phone_number
    from tickets
) t
group by region_code
order by region_code;

-- Задание 7. Классифицируйте финансовые обороты (сумму стоимости перелетов) по маршрутам:
-- • до 50 млн – low
-- • от 50 млн включительно до 150 млн – middle
-- • от 150 млн включительно – high
-- Выведите в результат количество маршрутов в каждом полученном классе.

select classification,
	   count (direction) as amount_of_directions
from (
    select
        direction,
        sum (amount) as total_amount,
        case
            when sum (amount) < 50000000 then 'Low'
            when sum (amount) >= 50000000 and sum (amount) < 150000000 then 'Middle'
            else 'High'
        end as classification
    from (
        select tf.amount,
			   f.departure_airport || ' - ' || f.arrival_airport as direction,
               f.actual_departure
        from  ticket_flights tf
        right join flights f on tf.flight_id = f.flight_id
        where f.actual_departure is not null
    ) qq
	group by direction
) ww
group by classification
order by amount_of_directions

-- Задание 8. Вычислите медиану стоимости перелетов, медиану стоимости бронирования и отношение медианы бронирования к медиане стоимости перелетов, результат округлите до сотых. 

with medianflight as (
    select
        percentile_cont (0.5) within group (order by amount)::numeric as qq
    from
        ticket_flights
),
	medianreservation as (
    select
        percentile_cont (0.5) within group (order by total_amount)::numeric as ww
    from
        bookings
)
select
    round(medianflight.qq, 2) as median_flight_cost,
    round(medianreservation.ww, 2) as median_reservation_cost,
    round(medianreservation.ww / medianflight.qq, 2) as ratio
from medianflight
cross join medianreservation;

-- Задание 9. Найдите значение минимальной стоимости одного километра полёта для пассажира. Для этого определите расстояние между аэропортами и учтите стоимость перелета.
-- Для поиска расстояния между двумя точками на поверхности Земли используйте дополнительный модуль earthdistance. Для работы данного модуля нужно установить ещё один модуль – cube.
-- Важно: 
-- Установка дополнительных модулей происходит через оператор CREATE EXTENSION название_модуля.
-- В облачной базе данных модули уже установлены.
-- Функция earth_distance возвращает результат в метрах

select
  f.departure_airport as departure,
  f.arrival_airport as arrival,
  earth_distance (dep.coordinates, arr.coordinates) as distance_in_meters
from
  flights f
join
  airports_data dep on f.departure_airport = dep.airport_code
join
  airports_data arr on f.arrival_airport = arr.airport_code
where
  f.departure_airport <> f.arrival_airport
-- это начало кода, попытка написать первую часть.   
-- перепробовал много всего, но всегда выдает ошибку. ERROR: function earth_distance(point, point) does not existю No function matches the given name and argument types.
-- при попытке выполнить CREATE EXTENSION cube - ERROR: permission denied to create extension "cube" Подсказка: Must be superuser to create this extension.
-- при проверке показывает, что стоят версии 1.1 по деффолту, но не работают. Не знаю в чем дело. 