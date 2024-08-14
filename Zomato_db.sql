create database zomato;
use zomato;

-- Uploaded tables
-- 1. delivery_partner
-- 2. food
-- 3. menu
-- 4. order_details
-- 5. orders
-- 6. restaurants
-- 7. users


-- Show the avg rating for each partner ID and restaurant
SELECT 
    r_name, ROUND(AVG(restaurant_rating), 1) AS avg_rating
FROM
    orders
        JOIN
    restaurants r ON orders.r_id = r.r_id
GROUP BY r.r_name
ORDER BY avg_rating DESC;

SELECT 
    partner_name,
    ROUND(AVG(delivery_time), 0) AS avg_del_time,
    ROUND(AVG(delivery_rating), 1) AS avg_partner_rating
FROM
    orders o
        JOIN
    delivery_partner dp ON o.partner_id = dp.partner_id
GROUP BY partner_name order by avg_partner_rating desc;

-- Find customers who have never ordered
 SELECT 
    *
FROM
    users
WHERE
    user_id NOT IN (SELECT DISTINCT
            (user_id)
        FROM
            orders);
            
 
 -- Avg price/dish
 SELECT 
    f_name, round(AVG(price),2) AS 'Averag Price'
FROM
    menu
        JOIN
    food ON food.f_id = menu.f_id
GROUP BY f_name
ORDER BY f_name ASC;
 
 -- Find top 10 restaurnats in terms of no. of order for a given month
SELECT 
    r_name, COUNT(*) AS order_count
FROM
    orders
        JOIN
    restaurants ON orders.r_id = restaurants.r_id
WHERE
    MONTHNAME(date) = 'June'
GROUP BY r_name
ORDER BY order_count DESC
LIMIT 10;   -- Month can be replaced by May/June/July as needed

-- Restaurants with monthly sales > X
SELECT 
    r_name, SUM(amount) AS sales
FROM
    orders
        JOIN
    restaurants ON orders.r_id = restaurants.r_id
WHERE
    MONTHNAME(date) = 'June'	-- month
GROUP BY r_name
HAVING sales > 400  			-- X value
ORDER BY SUM(amount) DESC
LIMIT 10; -- (Month can be May/June/July and X can be variable)

-- show all orders from a particlar customer in a particular date range
SELECT 
    name, date, od.order_id, r_name, f_name, amount
FROM
    orders o
        JOIN
    users ON users.user_id = o.user_id
        JOIN
    restaurants r ON r.r_id = o.r_id
        JOIN
    order_details od ON od.order_id = o.order_id
        JOIN
    food ON food.f_id = od.f_id
WHERE
    name = 'Ankit'											-- name can be changed
        AND date BETWEEN '2022-05-10' AND '2022-06-10'		-- date range can be set as needed
ORDER BY date ASC;

-- Find restaurants with max repeated customers (loyal customers)
SELECT 
    r_name, COUNT(r_name) AS rep_count
FROM
    (SELECT 
        r_name, user_id, COUNT(*) AS visits
    FROM
        orders
    JOIN restaurants r ON r.r_id = orders.r_id
    GROUP BY r_name , user_id
    HAVING visits > 1) AS a
GROUP BY r_name
ORDER BY rep_count DESC;

-- Month over month revenue growth of Zomato

-- WINDOW Function LAG()
select month, CM_sales, LM_sales, 
	(CM_sales-LM_sales)*100/LM_sales as growth 
	from (select monthname(date) as month , sum(amount) as CM_sales, 
    lag(sum(amount)) over() as LM_sales 
    from orders 
    group by month) as t;

-- Find the top 2 spenders for all the 3 momths
select * 
from (select monthname(date) as Month,user_id,sum(amount) as spent ,
rank() over(partition by monthname(date) order by sum(amount) desc) 
as Month_rank 
from orders group by Month,user_id) as a 
where Month_rank < 3 
order by Month desc, Month_rank asc;

-- customer -wise favourite food
-- 1st method (without Common Table Expressions (CTEs))
select customer,food from
(select customer, food, rank() over(partition by customer 
order by class desc) as r 
from(select users.name as customer, food.f_name as food, count(*) as class 
from orders 
join order_details on orders.order_id= order_details.order_id
join users on users.user_id= orders.user_id
join food on food.f_id = order_details.f_id 
group by users.name, food.f_name 
order by users.name) as t) as tt 
where r=1 
order by customer;

-- 2nd method using Common Table Expressions (CTEs)
with temp as (
select users.name,f_name,count(*) as frequency 
	from orders o join order_details od 
	on o.order_id= od.order_id
    join users on users.user_id=o.user_id 
    join food on food.f_id=od.f_id
    group by users.name,f_name)

select name,f_name from temp t1 
where t1.frequency = (select max(frequency) 
from temp t2 where t1.name=t2.name);

-- find most loyal customers for all restaurants

create view v1 as
(select r_name,name, count(*) as visits 
from orders o join restaurants r on o.r_id=r.r_id
join users on users.user_id=o.user_id 
group by r_name, name 
order by r_name);

-- 1st method: without window function
select r_name,name 
from v1 t1 where t1	.visits = 
(select max(visits) from v1 t2 
where t1.r_name =t2.r_name);


-- 2nd method: with window fucnction
select r_name,name from
(select *,rank() over(partition by r_name order by visits desc) 
as top_visit from v1) as a 
where top_visit=1;


-- most paired products
create view v2 as
select orders.order_id,f_id 
from orders join order_details od on orders.order_id= od.order_id ;

-- self join to create pairs
create view v3 as
select t1.order_id as order_id, 
	t1.f_id as item_1,t2.f_id as item_2 
from v2 t1 join v2 t2 on t1.order_id =t2.order_id and t1.f_id<t2.f_id;

create view v4 as
select item_1,item_2, count(*) as freq 
	from v3 group by item_1,item_2 order by freq desc;

select f1.f_name as prod_1, f2.f_name as prod_2, freq
from v4 join food f1 on f1.f_id =v4.item_1 
	join food f2 on f2.f_id =v4.item_2 order by freq desc;

