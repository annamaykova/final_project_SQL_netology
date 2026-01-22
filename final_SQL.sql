-- 1. Выведите название самолетов, которые имеют менее 50 посадочных мест?

select a.model, count(s.seat_no)
from aircrafts a 
left join seats s on a.aircraft_code =s.aircraft_code
group by a.aircraft_code 
having count(s.seat_no)<50




-- 2. Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.

select s.b_date, s.sum, 
	round((s.sum-lag(s.sum) over (order by s.b_date))/(lag(s.sum) over (order by s.b_date))*100, 2) as "Процентное изменение"
from (
	select date_trunc('month',book_date)::date as "b_date", sum(total_amount)
	from bookings b 
	group by 1) s



	
-- 3. Выведите названия самолетов не имеющих бизнес - класс. Решение должно быть через функцию array_agg.
	
	select f.model
	from (
			select a.model , array_agg(s.fare_conditions) as "class"	--подзапрос с названиямит самолетов и массивом с классами всех сидений в нем
			from aircrafts a 
			left join seats s  on a.aircraft_code =s.aircraft_code
			group by a.aircraft_code) f
	where 'Business'!=all(f.class)										--отсортировали вывод где каждый элемент массива НЕ равен Business
			
			

-- 4. Вывести накопительный итог количества мест в самолетах по каждому аэропорту на каждый день, учитывая только те самолеты, 
-- которые летали пустыми и только те дни, где из одного аэропорта таких самолетов вылетало более одного.
-- В результате должны быть код аэропорта, дата, количество пустых мест в самолете и накопительный итог.
			
select t.departure_airport, t.day_departure::date, t.count_seats,
	sum(t.count_seats) over (partition by t.departure_airport, t.day_departure::date order by t.day_departure)
from (
	select departure_airport, day_departure, count_seats
	from (
		select f.flight_id, f.departure_airport, f.actual_departure as day_departure, 
				count(f.flight_id) over (partition by f.departure_airport, f.actual_departure::date), s.count_seats
		from flights f 
		left join boarding_passes bp on bp.flight_id = f.flight_id 
		join (	select aircraft_code, count (seat_no) as "count_seats"
					from seats
					group by 1) s 
			on s.aircraft_code = f.aircraft_code
		where (f.status = 'Departed' or f.status = 'Arrived') and bp.boarding_no is null) 
	where count>1) t		

-- 5. Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов.
-- Выведите в результат названия аэропортов и процентное отношение.
-- Решение должно быть через оконную функцию.


select  distinct a_d.airport_name, a_a.airport_name, 
		round(count(*) over (partition by f.departure_airport, f.arrival_airport)::numeric/count(f.flight_id) over ()::numeric*100,2) 
from flights f 
join airports a_d on f.departure_airport = a_d.airport_code
join airports a_a on f.arrival_airport = a_a.airport_code
order by 1, 2



-- 6. Выведите количество пассажиров по каждому коду сотового оператора, если учесть, что код оператора - это три символа после +7

select left(split_part(contact_data->>'phone', '+7',2),3), count(passenger_id)		
from tickets
group by 1
order by 1

	

-- 7. Классифицируйте финансовые обороты (сумма стоимости перелетов) по маршрутам:
-- До 50 млн - low
-- От 50 млн включительно до 150 млн - middle
-- От 150 млн включительно - high
-- Выведите в результат количество маршрутов в каждом полученном классе
	

select count(t.case_sum), t.case_sum 
from (
	select departure_airport, arrival_airport, sum, 
			case 
				when sum < 50000000 then 'low'
				when sum >= 50000000 and sum < 150000000	then 'middle'		
				else 'high'
			end case_sum
	from (
		select distinct f.departure_airport, f.arrival_airport, sum(tf.amount)
		from flights f 
		join ticket_flights tf on f.flight_id = tf.flight_id  
		group by 1, 2 ))t
group by 2
		


--  8. Вычислите медиану стоимости перелетов, медиану размера бронирования и отношение медианы бронирования к медиане стоимости перелетов, округленной до сотых

	select m_b, m_tf, round(m_b::numeric/m_tf::numeric,2)
	from (
		select percentile_cont(0.5) within group (order by total_amount) as m_b	
		from bookings),
		(select percentile_cont(0.5) within group (order by amount) as m_tf
		from ticket_flights)
	
	
	

--  9. Найдите значение минимальной стоимости полета 1 км для пассажиров. То есть нужно найти расстояние между аэропортами и с учетом стоимости перелетов получить искомый результат
--  Для поиска расстояния между двумя точками на поверхности Земли используется модуль earthdistance.
--  Для работы модуля earthdistance необходимо предварительно установить модуль cube.

create extension cube
create extension earthdistance

		
		select min(min_amount/(earth_distance(ll_to_earth(a_departure.latitude, a_departure.longitude), ll_to_earth(a_arrival.latitude, a_arrival.longitude))/1000))
		from (
			select f.departure_airport, f.arrival_airport, min(tf.amount) as "min_amount"
			from flights f 
			join ticket_flights tf on f.flight_id = tf.flight_id
			group by 1,2) m
		join airports a_departure on m.departure_airport = a_departure.airport_code 
		join airports a_arrival on m.arrival_airport = a_arrival.airport_code
		
		
		