DROP DATABASE IF EXISTS TrainManagementSystem
CREATE DATABASE TrainManagementSystem;
USE TrainManagementSystem;

-- 1. TRAIN
CREATE TABLE TRAIN (
    Train_No      INT          PRIMARY KEY,
    Train_Name    VARCHAR(100) NOT NULL,
    Train_Type    VARCHAR(50)  NOT NULL,          -- Express, Superfast, Mail, Local
    Capacity      INT          NOT NULL CHECK (Capacity > 0)
);


-- 2. STATION 
CREATE TABLE STATION (
    Station_ID    INT          PRIMARY KEY AUTO_INCREMENT,
    Station_Name  VARCHAR(100) NOT NULL,
    City          VARCHAR(100) NOT NULL,
    Platform_No   INT          NOT NULL CHECK (Platform_No > 0)
);
SHOW TRIGGERS

  
-- 3. SCHEDULE 
CREATE TABLE SCHEDULE (
    Schedule_ID    INT          PRIMARY KEY AUTO_INCREMENT,
    Train_No       INT          NOT NULL,
    Arrival_Time   TIME         NOT NULL,
    Departure_Time TIME         NOT NULL,
    Running_Date   DATE         NOT NULL,
    FOREIGN KEY (Train_No) REFERENCES TRAIN(Train_No)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 4. TRAIN_STOPS_AT — Junction table for N:M relationship
CREATE TABLE TRAIN_STOPS_AT (
    Train_No      INT NOT NULL,
    Station_ID    INT NOT NULL,
    Stop_Order    INT NOT NULL,                   -- sequence of stop
    Arrival_Time  TIME,
    Departure_Time TIME,
    PRIMARY KEY (Train_No, Station_ID),
    FOREIGN KEY (Train_No)   REFERENCES TRAIN(Train_No)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (Station_ID) REFERENCES STATION(Station_ID)
        ON DELETE CASCADE ON UPDATE CASCADE
);


-- 5. TIMETABLE_EVENT — Aggregation of TRAIN, STATION, SCHEDULE
--    Links BOOKING and EMPLOYEE to the combined context of
--    which train, at which station, on which schedule
CREATE TABLE TIMETABLE_EVENT (
    Event_ID      VARCHAR(20)  PRIMARY KEY,
    Train_No      INT          NOT NULL,
    Station_ID    INT          NOT NULL,
    Schedule_ID   INT          NOT NULL,
    FOREIGN KEY (Train_No)    REFERENCES TRAIN(Train_No)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (Station_ID)  REFERENCES STATION(Station_ID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (Schedule_ID) REFERENCES SCHEDULE(Schedule_ID)
        ON DELETE CASCADE ON UPDATE CASCADE
);


-- 6. EMPLOYEE 
CREATE TABLE EMPLOYEE (
    Employee_ID   INT            PRIMARY KEY AUTO_INCREMENT,
    Name          VARCHAR(100)   NOT NULL,
    Salary        DECIMAL(10,2)  NOT NULL CHECK (Salary > 0),
    Aadhar_no     VARCHAR(12)    NOT NULL UNIQUE,
    Phone_no      VARCHAR(15)    NOT NULL,
    Event_ID      VARCHAR(20),                       -- MANAGES aggregation (M:1)
    FOREIGN KEY (Event_ID) REFERENCES TIMETABLE_EVENT(Event_ID)
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- 6. DRIVER — ISA subtype of EMPLOYEE
CREATE TABLE DRIVER (
    Employee_ID   INT          PRIMARY KEY,
    License_No    VARCHAR(50)  NOT NULL UNIQUE,
    FOREIGN KEY (Employee_ID) REFERENCES EMPLOYEE(Employee_ID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 7. TC (Ticket Collector)
CREATE TABLE TC (
    Employee_ID    INT          PRIMARY KEY,
    Badge_No       VARCHAR(50)  NOT NULL UNIQUE,
    Assigned_Zone  VARCHAR(50)  NOT NULL,
    FOREIGN KEY (Employee_ID) REFERENCES EMPLOYEE(Employee_ID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 8. MAINTENANCE_STAFF 
CREATE TABLE MAINTENANCE_STAFF (
    Employee_ID    INT          PRIMARY KEY,
    Shift_Type     VARCHAR(50)  NOT NULL,          
    Trade_Skill    VARCHAR(100) NOT NULL,          
    FOREIGN KEY (Employee_ID) REFERENCES EMPLOYEE(Employee_ID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 9. COACH_SEAT 
CREATE TABLE COACH_SEAT (
    Seat_ID       INT          PRIMARY KEY AUTO_INCREMENT,
    Train_No      INT          NOT NULL,
    Coach_No      VARCHAR(10)  NOT NULL,
    Seat_No       INT          NOT NULL,
    Class         VARCHAR(20)  NOT NULL,          -- 1AC, 2AC, 3AC, SL, GEN
    UNIQUE (Train_No, Coach_No, Seat_No),
    FOREIGN KEY (Train_No) REFERENCES TRAIN(Train_No)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 10. PASSENGER 
CREATE TABLE PASSENGER (
    Passenger_ID  INT          PRIMARY KEY AUTO_INCREMENT,
    Name          VARCHAR(100) NOT NULL,
    Age           INT          NOT NULL CHECK (Age > 0 AND Age < 150),
    Gender        ENUM('Male', 'Female', 'Other') NOT NULL,
    Phone_no      VARCHAR(15)  NOT NULL,
    Aadhar_no     VARCHAR(12)  NOT NULL UNIQUE
);


-- 11. BOOKING 
CREATE TABLE BOOKING (
    Booking_ID     INT          PRIMARY KEY AUTO_INCREMENT,
    Passenger_ID   INT          NOT NULL,
    Event_ID       VARCHAR(20)  NOT NULL,           -- BOOKED ON aggregation
    Start_Station  INT          NOT NULL,           -- STARTS AT
    End_Station    INT          NOT NULL,           -- ENDS AT
    Booking_Date   DATE         NOT NULL,
    Journey_Date   DATE         NOT NULL,
    Status         VARCHAR(20)  NOT NULL DEFAULT 'Confirmed',  -- Confirmed, Waiting, Cancelled
    Class          VARCHAR(20)  NOT NULL,
    FOREIGN KEY (Passenger_ID)  REFERENCES PASSENGER(Passenger_ID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (Event_ID)      REFERENCES TIMETABLE_EVENT(Event_ID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (Start_Station) REFERENCES STATION(Station_ID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (End_Station)   REFERENCES STATION(Station_ID)
        ON DELETE CASCADE ON UPDATE CASCADE
);


-- 12. BOOKING_SEAT — Junction table for N:M relationship
CREATE TABLE BOOKING_SEAT (
    Booking_ID    INT NOT NULL,
    Seat_ID       INT NOT NULL,
    PRIMARY KEY (Booking_ID, Seat_ID),
    FOREIGN KEY (Booking_ID) REFERENCES BOOKING(Booking_ID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (Seat_ID)    REFERENCES COACH_SEAT(Seat_ID)
        ON DELETE CASCADE ON UPDATE CASCADE
);


-- 13. PAYMENT — Strong Entity
CREATE TABLE PAYMENT (
    Payment_ID     INT            PRIMARY KEY AUTO_INCREMENT,
    Booking_ID     INT            NOT NULL UNIQUE,   -- 1:1 with BOOKING
    Amount         DECIMAL(10,2)  NOT NULL CHECK (Amount > 0),
    Payment_Date   DATE           NOT NULL,
    Payment_Status VARCHAR(20)    NOT NULL DEFAULT 'Pending',  -- Pending, Completed, Refunded
    FOREIGN KEY (Booking_ID) REFERENCES BOOKING(Booking_ID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 14. AUDIT_LOG — Logs database trigger actions
CREATE TABLE AUDIT_LOG (
    Log_ID        INT           PRIMARY KEY AUTO_INCREMENT,
    Action_Type   VARCHAR(50)   NOT NULL,
    Table_Name    VARCHAR(50)   NOT NULL,
    Record_ID     INT,
    Details       TEXT,
    Created_At    TIMESTAMP     DEFAULT CURRENT_TIMESTAMP
);


-- =======================================================
-- VIEWS
-- =======================================================

-- View 1: Complete Booking Details (combines BOOKING, PASSENGER, TRAIN, STATIONS, SEAT, PAYMENT)
CREATE OR REPLACE VIEW view_booking_details AS
SELECT 
    b.Booking_ID,
    p.Passenger_ID,
    p.Name AS Passenger_Name,
    p.Phone_no,
    p.Age,
    p.Gender,
    t.Train_No,
    t.Train_Name,
    s1.Station_Name AS Origin,
    s2.Station_Name AS Destination,
    b.Journey_Date,
    b.Booking_Date,
    b.Class,
    b.Status AS Booking_Status,
    cs.Coach_No,
    cs.Seat_No,
    pay.Payment_ID,
    pay.Amount,
    pay.Payment_Status
FROM BOOKING b
JOIN PASSENGER p ON b.Passenger_ID = p.Passenger_ID
JOIN TIMETABLE_EVENT te ON b.Event_ID = te.Event_ID
JOIN TRAIN t ON te.Train_No = t.Train_No
JOIN STATION s1 ON b.Start_Station = s1.Station_ID
JOIN STATION s2 ON b.End_Station = s2.Station_ID
LEFT JOIN BOOKING_SEAT bs ON b.Booking_ID = bs.Booking_ID
LEFT JOIN COACH_SEAT cs ON bs.Seat_ID = cs.Seat_ID
LEFT JOIN PAYMENT pay ON b.Booking_ID = pay.Booking_ID;

-- View 2: Employee Summary with polymorphic roles (Driver, TC, Maintenance)
CREATE OR REPLACE VIEW view_employee_summary AS
SELECT 
    e.Employee_ID,
    e.Name,
    e.Salary,
    e.Phone_no,
    CASE
        WHEN d.Employee_ID IS NOT NULL THEN 'Driver'
        WHEN tc.Employee_ID IS NOT NULL THEN 'Ticket Collector'
        WHEN ms.Employee_ID IS NOT NULL THEN 'Maintenance Staff'
        ELSE 'General Staff'
    END AS Role,
    d.License_No,
    tc.Badge_No,
    tc.Assigned_Zone,
    ms.Shift_Type,
    ms.Trade_Skill,
    t.Train_No,
    t.Train_Name,
    s.Station_Name AS Station
FROM EMPLOYEE e
LEFT JOIN DRIVER d ON e.Employee_ID = d.Employee_ID
LEFT JOIN TC tc ON e.Employee_ID = tc.Employee_ID
LEFT JOIN MAINTENANCE_STAFF ms ON e.Employee_ID = ms.Employee_ID
LEFT JOIN TIMETABLE_EVENT te ON e.Event_ID = te.Event_ID
LEFT JOIN TRAIN t ON te.Train_No = t.Train_No
LEFT JOIN STATION s ON te.Station_ID = s.Station_ID;

-- View 3: Train Seat Occupancy and Availability
CREATE OR REPLACE VIEW view_train_occupancy AS
SELECT 
    t.Train_No,
    t.Train_Name,
    t.Train_Type,
    t.Capacity,
    COUNT(DISTINCT cs.Seat_ID) AS Total_Configured_Seats,
    COUNT(DISTINCT bs.Seat_ID) AS Booked_Seats,
    (COUNT(DISTINCT cs.Seat_ID) - COUNT(DISTINCT bs.Seat_ID)) AS Available_Seats
FROM TRAIN t
LEFT JOIN COACH_SEAT cs ON t.Train_No = cs.Train_No
LEFT JOIN BOOKING_SEAT bs ON cs.Seat_ID = bs.Seat_ID
GROUP BY t.Train_No, t.Train_Name, t.Train_Type, t.Capacity;

-- View 4: Route Schedules with station order and timings
CREATE OR REPLACE VIEW view_route_schedule AS
SELECT 
    t.Train_No,
    t.Train_Name,
    tsa.Stop_Order,
    s.Station_Name,
    s.City,
    s.Platform_No,
    tsa.Arrival_Time,
    tsa.Departure_Time
FROM TRAIN_STOPS_AT tsa
JOIN TRAIN t ON tsa.Train_No = t.Train_No
JOIN STATION s ON tsa.Station_ID = s.Station_ID
ORDER BY t.Train_No, tsa.Stop_Order;


-- =======================================================
-- TRIGGERS
-- =======================================================

-- Trigger 1: AFTER INSERT ON BOOKING — logs created booking into AUDIT_LOG
DELIMITER $$
CREATE TRIGGER trg_after_booking_insert
AFTER INSERT ON BOOKING
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (Action_Type, Table_Name, Record_ID, Details)
    VALUES ('BOOKING_CREATED', 'BOOKING', NEW.Booking_ID, 
            CONCAT('Passenger ID ', NEW.Passenger_ID, ' booked class ', NEW.Class, ' on event ', NEW.Event_ID));
END$$

-- Trigger 2: AFTER DELETE ON BOOKING — logs deleted/cancelled booking into AUDIT_LOG
CREATE TRIGGER trg_after_booking_delete
AFTER DELETE ON BOOKING
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (Action_Type, Table_Name, Record_ID, Details)
    VALUES ('BOOKING_DELETED', 'BOOKING', OLD.Booking_ID, 
            CONCAT('Passenger ID ', OLD.Passenger_ID, ' booking was cancelled/deleted'));
END$$

-- Trigger 3: BEFORE INSERT ON PAYMENT — validates amount > 0
CREATE TRIGGER trg_before_payment_insert
BEFORE INSERT ON PAYMENT
FOR EACH ROW
BEGIN
    IF NEW.Amount <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment amount must be greater than zero';
    END IF;
END$$

-- Trigger 4: AFTER INSERT ON PAYMENT — logs payment record into AUDIT_LOG
CREATE TRIGGER trg_after_payment_insert
AFTER INSERT ON PAYMENT
FOR EACH ROW
BEGIN
    INSERT INTO AUDIT_LOG (Action_Type, Table_Name, Record_ID, Details)
    VALUES ('PAYMENT_RECORDED', 'PAYMENT', NEW.Payment_ID, 
            CONCAT('Amount: ₹', NEW.Amount, ', Status: ', NEW.Payment_Status, ', Booking ID: ', NEW.Booking_ID));
END$$
DELIMITER ;

SELECT 'All tables, views, and triggers created successfully!' AS Result;
