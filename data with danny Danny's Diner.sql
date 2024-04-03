CREATE SCHEMA dannys_diner;
SET search_path = dannys_diner;

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');


CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');


CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');






--What is the total amount each customer spent at the restaurant?
SELECT s.customer_id, SUM(m.price)
FROM menu AS m
JOIN sales AS s
ON s.product_id = m.product_id
GROUP BY s.customer_id;




--How many days has each customer visited the restaurant?
SELECT s.customer_id,  COUNT(s.order_date)
FROM sales AS s
GROUP BY s.customer_id;


--What was the first item from the menu purchased by each customer?
SELECT s.customer_id, m.product_name, s.order_date
FROM sales s
JOIN menu m
ON s.product_id = m.product_id
WHERE s.order_date = (SELECT MIN(s.order_date) AS date
					  FROM sales s)
ORDER BY s.customer_id;


--What is the most purchased item on the menu and how many times was it purchased by all customers?
WITH ItemPurchaseCounts AS (SELECT
       							 m.product_name AS _food, s.product_id,
        						 COUNT(*) AS purchase_count
    						FROM sales s
    						JOIN menu m ON s.product_id = m.product_id
    						GROUP BY m.product_name, s.product_id
),

t2 AS (
		SELECT
    		ipc._food AS food
		FROM ItemPurchaseCounts ipc
		WHERE ipc.purchase_count = (SELECT
                                  		MAX(purchase_count)
                                	FROM ItemPurchaseCounts)
)

SELECT s.customer_id, t2.food, count(*)
FROM sales s
JOIN menu m
ON m.product_id = s.product_id
JOIN t2
ON t2.food =  m.product_name
WHERE m.product_name = t2.food
GROUP BY s.customer_id, t2.food;



--Which item was the most popular for each customer?
WITH t1 AS ( SELECT
        		s.customer_id,
        		m.product_name AS popular_item,
        		COUNT(*) AS item_count
    		FROM sales s
    		JOIN menu m ON s.product_id = m.product_id
    		GROUP BY s.customer_id, m.product_name
    		ORDER BY item_count DESC
),

t2 AS (SELECT 
			t1.*,
        	ROW_NUMBER() OVER (PARTITION BY t1.customer_id ORDER BY t1.item_count DESC) AS row_num
		FROM t1)

SELECT t2.customer_id, t2.popular_item
FROM t2
WHERE t2.row_num =1;


--Which item was purchased first by the customer after they became a member?
WITH t1 AS (SELECT
      				s.customer_id AS customer,
      				m.product_name AS food,
      				ms.join_date AS date_join,
      				s.order_date AS date,
      				ROW_NUMBER() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS rank
  			FROM members ms
  			JOIN sales s
  			ON ms.customer_id = s.customer_id
  			JOIN menu m
  			ON m.product_id = s.product_id
  			WHERE ms.join_date <= s.order_date
)

SELECT
	t1.customer,
	t1.food, t1.date_join,
	t1.date
FROM t1
WHERE t1.rank = 1;



--Which item was purchased just before the customer became a member?
WITH t1 AS (SELECT
					ms.customer_id AS customer,
					m.product_name AS food,
					s.order_date AS sales_date,
					ms.join_date AS member_date
			FROM dannys_diner.sales s
			JOIN dannys_diner. members ms
			ON s.customer_id = ms.customer_id
			JOIN dannys_diner.menu m
			ON m.product_id = s.product_id),

t2 AS (SELECT *,
		   	ROW_NUMBER() OVER(PARTITION BY t1.customer ORDER BY t1.sales_date) AS rank
		FROM t1
		WHERE t1.member_date > t1.sales_date)

SELECT *
FROM t2
WHERE t2.rank IN (SELECT
						MAX(t2.rank)
				  FROM t2
				  WHERE t2.sales_date = t2.sales_date
				  GROUP BY t2.customer);

--What is the total items and amount spent for each member before they became a member?
SELECT
		ms.customer_id,
		m.product_name,
		sum(m.price),
		count(*)
FROM dannys_diner.sales s
JOIN dannys_diner.menu m
ON s.product_id = m.product_id
JOIN dannys_diner.members ms
ON s.customer_id = ms.customer_id
WHERE s.order_date < ms.join_date
GROUP BY ms.customer_id, m.product_name
ORDER BY ms.customer_id;



--If each $1 spent equates to 10 points and sushi has a 2x points multiplier how many points would each customer have?
SELECT
	s.customer_id,
	SUM(CASE
			WHEN m.price >= 1 AND m.product_name = 'sushi'
			THEN (m.price * 10)*2
			ELSE m.price * 10
			END) AS points
FROM dannys_diner.sales s
JOIN dannys_diner.menu m
ON s.product_id = m.product_id
GROUP BY s.customer_id
ORDER BY s.customer_id;






--In the first week after a customer joins the Program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
SELECT s.customer_Id,
		SUM(CASE
		WHEN ms.join_date <= (ms.join_date+7)
		THEN m.price*2
		END) AS points
FROM dannys_diner.sales s
JOIN dannys_diner.menu m
ON s.product_id = m.product_id
JOIN dannys_diner.members ms
ON s.customer_id = ms.customer_id
WHERE s.order_date BETWEEN '2021-01-01' AND '2021-01-31'
GROUP BY s.customer_id
ORDER BY s.customer_id;
