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




-- Задание 5. Найти процентное соотношение перелётов по маршрутам от общего количества перелётов, с использованием в решении оконной функции.
-- В результат вывести названия аэропортов и процентное отношение.
 
select ad.airport_name as departure_airport, ad2.airport_name as arrival_airport,
round ((count(flight_id) * 100.0 / sum (count(flight_id)) over ()), 3) as percent
from flights f
join airports ad on f.departure_airport = ad.airport_code 
join airports ad2 on f.arrival_airport = ad2.airport_code 
group by 1, 2 
order by percent desc 




-- Задание 6. Выведите количество пассажиров по каждому коду сотового оператора (три символа после +7).

select
    substring (phone_number, position('+7' in phone_number) + 2, 3) as region_code,
    count (*) as region_code_count
from (
    select contact_data ->>'phone' as phone_number
    from tickets
) t
group by region_code
order by region_code;




-- Задание 7. Классифицировать финансовые обороты (сумму стоимости перелетов) по маршрутам:
-- • до 50 млн – low
-- • от 50 млн включительно до 150 млн – middle
-- • от 150 млн включительно – high
-- Вывести в результат количество маршрутов в каждом полученном классе.

select classification,
	   count (*) as amount_of_directions
from (
    select
        case
            when sum (amount) < 50000000 then 'Low'
            when sum (amount) >= 50000000 and sum (amount) < 150000000 then 'Middle'
            else 'High'
        end as classification
    from flights f
    join ticket_flights tf on tf.flight_id = f.flight_id
    where f.actual_departure is not null
    group by f.flight_no
    ) qq
group by classification
order by amount_of_directions




-- Задание 8. Вычислить медиану стоимости перелетов, медиану стоимости бронирования и отношение медианы бронирования к медиане стоимости перелетов,
-- результат округлит до сотых. 

with median_flight as (
    select
        percentile_cont (0.5) within group (order by amount)::numeric as qq
    from
        ticket_flights
),
	median_reservation as (
    select
        percentile_cont (0.5) within group (order by total_amount)::numeric as ww
    from
        bookings
)
select
    round (median_flight.qq, 2) as median_flight_cost,
    round (median_reservation.ww, 2) as median_reservation_cost,
    round (median_reservation.ww / median_flight.qq, 2) as ratio
from median_flight
cross join median_reservation;
