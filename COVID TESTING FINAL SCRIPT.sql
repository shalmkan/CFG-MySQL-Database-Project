-- Creating the database.
CREATE DATABASE covid_testing;

-- Specify the database.
USE covid_testing;

-- Creating the tables(note foreign keys are added in alter statements afterwards).
CREATE TABLE patient_info (
patient_ID INT UNIQUE NOT NULL PRIMARY KEY , 
first_name VARCHAR(30) NOT NULL , 
last_name VARCHAR(30) NOT NULL, 
address_ID INT , 
DOB DATE NOT NULL, 
underlying_health_conditions BOOLEAN NOT NULL);

CREATE TABLE address_list(
address_ID INT UNIQUE NOT NULL PRIMARY KEY, 
house_number VARCHAR(30) NOT NULL, 
street_name VARCHAR(30) NOT NULL, 
city VARCHAR(30), 
post_code VARCHAR(7) NOT NULL, 
positive_result BOOLEAN DEFAULT FALSE,
date_of_positive_result DATE);

ALTER TABLE address_list
MODIFY COLUMN post_code VARCHAR(12);

CREATE TABLE symptoms(
symptom_ID INT UNIQUE NOT NULL PRIMARY KEY, 
symptom_description VARCHAR(100) NOT NULL);

CREATE TABLE patient_visits(
visit_ID INT UNIQUE NOT NULL PRIMARY KEY, 
date_of_visit DATE NOT NULL,
patient_ID INT NOT NULL, 
location_ID INT NOT NULL, 
staff_ID INT NOT NULL,
test_result VARCHAR(30) NOT NULL,
symptom1_ID INT DEFAULT NULL, 
symptom2_ID INT DEFAULT NULL, 
symptom3_ID INT DEFAULT NULL);

CREATE TABLE staff(
staff_ID INT UNIQUE NOT NULL PRIMARY KEY, 
first_name VARCHAR(30) NOT NULL, 
last_name VARCHAR(30) NOT NULL, 
location_ID INT NOT NULL, 
address_ID INT);

CREATE TABLE centre_location(
location_ID INT NOT NULL UNIQUE PRIMARY KEY, 
centre_name VARCHAR(30) NOT NULL, 
address_ID INT NOT NULL);

-- Now  tables have been created, foreign keys can also be established:
ALTER TABLE patient_info 
ADD CONSTRAINT fk_address_ID FOREIGN KEY (address_ID) REFERENCES address_list (address_ID);

ALTER TABLE centre_location
ADD CONSTRAINT fk_address_ID2 FOREIGN KEY (address_ID) REFERENCES address_list (address_ID);

ALTER TABLE staff
ADD CONSTRAINT fk_address_ID3 FOREIGN KEY (address_ID) REFERENCES address_list (address_ID),
ADD CONSTRAINT fk_location_ID FOREIGN KEY(location_ID) REFERENCES centre_location(location_ID);

ALTER TABLE patient_visits
ADD CONSTRAINT fk_patient_ID FOREIGN KEY(patient_ID) REFERENCES patient_info (patient_ID), 
ADD CONSTRAINT fk_location_ID2 FOREIGN KEY(location_ID) REFERENCES centre_location(location_ID),
ADD CONSTRAINT fk_staff_ID FOREIGN KEY(staff_ID) REFERENCES staff (staff_ID), 
ADD CONSTRAINT fk_symptoms FOREIGN KEY(symptom1_ID) REFERENCES symptoms (symptom_ID),
ADD CONSTRAINT fk_symptoms2 FOREIGN KEY(symptom2_ID) REFERENCES symptoms (symptom_ID),
ADD CONSTRAINT fk_symptoms3 FOREIGN KEY(symptom3_ID) REFERENCES symptoms (symptom_ID);

ALTER TABLE address_list 
ALTER positive_result SET DEFAULT NULL;

ALTER TABLE patient_info
ADD COLUMN gender CHAR(1);

/*Now adding data to the tables (some using INSERT INTO method and some by importing mock csv data generated through Mockaroo) 
Please Note: address_list data is 100% random and so each row does not accurately represent the likely address' of the rows they are linked to). */

INSERT INTO symptoms 
( symptom_ID, symptom_description)
VALUES 
(101, 'New contagious cough'),
(102, 'High temperature'),
(103,'Loss of taste/smell');

INSERT INTO centre_location
(location_ID, centre_name, address_ID)
VALUES
(11, 'Twickenham Test Centre', 1),
(22,'Brighton Stadium Test Centre',2),
(33,'Leeds Test Centre',3),
(44,'Coventry Test Centre',4),
(55,'Gloucester Test Centre',5);

INSERT INTO staff
(staff_ID, first_name, last_name, location_ID, address_ID)
VALUES 
(1,'Bob', 'Masberry',22,6),
(2,'Sacha', 'Nicholls',44,7),
(3,'Ashley', 'Lee',22,8),
(4,'Amelie', 'Halmer',11,9),
(5,'Leo','Halmer',11,19),
(6,'Frederik', 'Smith',33,10),
(7,'Jean', 'West',55,11),
(8,'Alison', 'Baptiste',55,12),
(9,'Pablo', 'Falmer',22,13),
(10,'Sarah', 'Francis', 55, 14),
(11,'Benjamin', 'East',11,15),
(12,'Owen', 'El-Paso',44,16),
(13,'Deborah', 'West',33,17),
(14,'Fiona', 'Mckinnon',44,18),
(15,'Alexandra', 'Wilcox',55,20);


-- Function to make the Boolean ,underlying health condition, column in patient_info more understandable to a non-SQL user.
    DELIMITER // 
CREATE FUNCTION boolean_to_string( health BOOLEAN )
RETURNS VARCHAR(60) 
DETERMINISTIC 
BEGIN 
	DECLARE message VARCHAR(60);
    IF health=1 THEN 
    SET message= 'Yes';
    ELSE 
    SET message = 'No';
	END IF;
    RETURN message;
    END // 
    DELIMITER ; 
    
-- A stored function to determine whether a patient should be self-isolating.

DELIMITER // 
CREATE FUNCTION need_for_isolation( f_name VARCHAR(50), DOB DATE, health BOOLEAN )
RETURNS VARCHAR(100) 
DETERMINISTIC 
BEGIN 
	DECLARE message VARCHAR(100);
    declare max_bday date;
    SET max_bday=  ADDDATE(CURDATE(), INTERVAL -65 YEAR);
	IF health =1 OR DOB <= max_bday THEN 
		SET message= CONCAT(f_name, ' should be be self isolating!');
	ELSE 
		SET  message=CONCAT(f_name," does not need to self isolate currently.");
	END IF;
    RETURN message;
    END // 
    DELIMITER ; 
    
/* Now creating some appropriate joins and saving them as views. 
 Please Note: MYSQL did not allow for the following views to have a check with option*/


-- This view shows the percentage of positive results from all tests per test centre. 
CREATE OR REPLACE VIEW positive_results_by_locations
AS
SELECT c.centre_name, count(p.patient_ID) AS 'Number of Tests',
(SELECT COUNT(p.visit_ID)
FROM patient_visits p
WHERE p.test_result = 'positive' and p.location_ID=c.location_ID) as 'Number of Positive Results' ,
(SELECT COUNT(p.visit_ID)
FROM patient_visits p
WHERE p.test_result = 'positive' and p.location_ID=c.location_ID)/count(p.patient_ID) *100 AS 'Percentage of Positive Results(%)'
FROM centre_location c
INNER JOIN patient_visits p
ON  p.location_ID = c.location_ID
GROUP BY c.location_ID;

-- This view shows the top 5 staff members who have given out the most tests.
CREATE VIEW top_5_staff
AS
SELECT s.first_name, c.centre_name as 'Centre of Employment',COUNT(p.visit_ID) AS 'Number of Tests Given'
FROM patient_visits p
INNER JOIN staff s 
ON s.staff_ID=p.staff_ID
INNER JOIN centre_location c
ON s.location_ID=c.location_ID
GROUP BY s.staff_ID
ORDER BY COUNT(p.visit_ID) DESC
LIMIT 5;

-- View to show the advice on whether each patient should be self-isolating (depending on age and health).
CREATE VIEW patients_isolation_advice
AS
SELECT p.patient_ID, p.first_name, p.DOB, 
boolean_to_string(p.underlying_health_conditions) as 'Underlying health Conditions?',
need_for_isolation(first_name, DOB, underlying_health_conditions) AS 'Isolation advice'
FROM patient_info p;

-- Creating a stored procedure to determine the number of visits per centre on a given date.
DELIMITER //
CREATE PROCEDURE daily_visits_per_centre(a_date DATE)
BEGIN 
    SELECT c.location_ID,c.centre_name , COUNT(p.visit_ID), p.date_of_visit
    FROM centre_location c
    INNER JOIN patient_visits p
    ON p.location_ID=c.location_ID
    GROUP BY p.location_ID, P.date_of_visit
	HAVING p.date_of_visit = a_date;
END // 
DELIMITER ;

call daily_visits_per_centre('2020-08-20');
call daily_visits_per_centre('2020-07-23');

-- list all the people visiting the Leeds test centre before Bethany Montoya ID NO=289 (Using another subquery for core requirements)

SELECT pi.first_name, pi.last_name, pv.date_of_visit
FROM patient_info pi
INNER JOIN patient_visits pv
ON pi.patient_ID= pv.patient_ID 
WHERE pv.location_ID= 33 AND 
pv.date_of_visit< (SELECT date_of_visit FROM patient_visits WHERE patient_ID=289);

-- Who were the first 3 people to test positive at the Brighton test centre?
SELECT pi.patient_ID, pi.first_name, pv.date_of_visit
FROM patient_info pi
INNER JOIN patient_visits pv
ON pv.patient_ID=pi.patient_ID
WHERE pv.location_ID =22 AND pv.test_result='positive'
ORDER BY pv.date_of_visit
LIMIT 3;

/* Prepare an example query using both GROUP BY and HAVING (as required for advanced criteria).
Doing so by answering the question: How many of each gender have underlying health conditions who are also in the vulnerable age category?
 Please Note: SQL would not allow me to do this without also displaying DOB column!!) */


SELECT p.gender, COUNT(p.patient_ID) AS 'Number of patients who are 65+ and with health conditions', 
p.DOB
FROM patient_info p
GROUP BY p.gender 
HAVING p.DOB <= (ADDDATE(CURDATE(), INTERVAL -65 YEAR));

-- Creating an 'AFTER DELETE' trigger to add all previous employees to previous_staff table when deleted from staff (as required for advanced criteria).
CREATE TABLE previous_staff
(staff_ID INT , first_name VARCHAR(50), last_name VARCHAR(50), centre_ID INT , date_left DATE );

delimiter //
CREATE TRIGGER past_staff
            AFTER DELETE
            ON staff FOR EACH ROW
            BEGIN
            
            INSERT INTO previous_staff 
            (staff_ID, first_name, last_name, centre_ID, date_left )
            VALUES
            (OLD.staff_ID,OLD.first_name, OLD.last_name, OLD.location_ID,CURDATE());
            
            END; // 
            
-- Testing out the trigger past_staff:
INSERT INTO staff
(staff_ID, first_name, last_name, location_ID, address_ID)
VALUES
(16,'Freya', 'Holden', 22, 90);

-- Must temporarily drop the foreign keys from staff,this way I can delete something from the table to test it out.
ALTER TABLE staff
DROP FOREIGN KEY fk_address_ID3,
DROP FOREIGN KEY fk_location_ID;

DELETE FROM staff
WHERE staff_ID=16;

ALTER TABLE staff
ADD CONSTRAINT fk_address_ID3 FOREIGN KEY (address_ID) REFERENCES address_list (address_ID),
ADD CONSTRAINT fk_location_ID FOREIGN KEY(location_ID) REFERENCES centre_location(location_ID);
