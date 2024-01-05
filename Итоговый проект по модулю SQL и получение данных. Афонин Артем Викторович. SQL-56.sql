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




-- Задание 4. Вывести накопительный итог количества мест в самолётах по каждому аэропорту на каждый день.
-- Учтите только те самолеты, которые летали пустыми и только те дни, когда из одного аэропорта вылетело более одного такого самолёта.
-- Вывести в результат код аэропорта, дату вылета, количество пустых мест и накопительный итог.

with cte1 as (
    select
        f.departure_airport,
        f.status,
        f.aircraft_code,
        f.actual_departure,
        f.actual_departure::date as date,
        s.empty_seats
    from
        flights f
    left join
		boarding_passes bp on bp.flight_id = f.flight_id
    join (
		select aircraft_code, count(*) as empty_seats
		from seats
		group by aircraft_code) s on s.aircraft_code = f.aircraft_code
    where
        bp.boarding_no is null
        and f.status in ('Departed', 'Arrived')
)
--- В CTE1 вывел необходимые данные для дальнейшей работы, присоединил таблицы 
--- и отфильтровал данные, чтобы учитывались только пустые самолеты и состоявшиеся полеты.
select
    cte1.departure_airport,
    cte1.date,
    cte1.empty_seats,
    sum(cte1.empty_seats) over (partition by cte1.departure_airport, cte1.date order by cte1.actual_departure) as cumulative_total_seats
from
    cte1
 where (cte1.departure_airport, cte1.date) in (
	select departure_airport, date
	from cte1 
	group by 1,2 
	having count(*) > 1)
group by
    cte1.departure_airport, cte1.date,cte1.Empty_seats, cte1.actual_departure
order by
    cte1.departure_airport;
--- Вывел необходимые данные, учел только те дни, когда вылетело более 1 самолета.
