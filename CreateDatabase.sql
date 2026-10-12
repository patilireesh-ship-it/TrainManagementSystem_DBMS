-- ============================================================
-- TRAIN MANAGEMENT SYSTEM — DATABASE CREATION
-- Based on the ER Diagram
-- ============================================================

DROP DATABASE IF EXISTS TrainManagementSystem;
CREATE DATABASE TrainManagementSystem;
USE TrainManagementSystem;

-- ============================================================
-- 1. TRAIN — Strong Entity
-- ============================================================
CREATE TABLE TRAIN (
    Train_No      INT          PRIMARY KEY,
    Train_Name    VARCHAR(100) NOT NULL,
    Train_Type    VARCHAR(50)  NOT NULL,          -- Express, Superfast, Mail, Local
    Capacity      INT          NOT NULL CHECK (Capacity > 0)
);

-- ============================================================
-- 2. STATION — Strong Entity
-- ============================================================
CREATE TABLE STATION (
    Station_ID    INT          PRIMARY KEY AUTO_INCREMENT,
    Station_Name  VARCHAR(100) NOT NULL,
    City          VARCHAR(100) NOT NULL,
    Platform_No   INT          NOT NULL CHECK (Platform_No > 0)
);

-- ============================================================
-- 3. SCHEDULE — Weak Entity (depends on TRAIN via HAS)
--    Relationship: TRAIN 1 ——— HAS ——— N SCHEDULE
-- ============================================================
CREATE TABLE SCHEDULE (
    Schedule_ID    INT          PRIMARY KEY AUTO_INCREMENT,
    Train_No       INT          NOT NULL,
    Arrival_Time   TIME         NOT NULL,
    Departure_Time TIME         NOT NULL,
    Running_Date   DATE         NOT NULL,
    FOREIGN KEY (Train_No) REFERENCES TRAIN(Train_No)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================
-- 4. TRAIN_STOPS_AT — Junction table for N:M relationship
--    Relationship: TRAIN N ——— STOPS AT ——— M STATION
-- ============================================================
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
-- ============================================================
-- 5. TIMETABLE_EVENT — Aggregation of TRAIN, STATION, SCHEDULE
--    Links BOOKING and EMPLOYEE to the combined context of
--    which train, at which station, on which schedule
-- ============================================================
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

-- ============================================================
-- 6. EMPLOYEE — Strong Entity (supertype for DRIVER, MAINTENANCE_STAFF & TC)
-- ============================================================
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

-- ============================================================
-- 6. DRIVER — ISA subtype of EMPLOYEE
-- ============================================================
CREATE TABLE DRIVER (
    Employee_ID   INT          PRIMARY KEY,
    License_No    VARCHAR(50)  NOT NULL UNIQUE,
    FOREIGN KEY (Employee_ID) REFERENCES EMPLOYEE(Employee_ID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================
-- 7. TC (Ticket Collector) — ISA subtype of EMPLOYEE
-- ============================================================
CREATE TABLE TC (
    Employee_ID    INT          PRIMARY KEY,
    Badge_No       VARCHAR(50)  NOT NULL UNIQUE,
    Assigned_Zone  VARCHAR(50)  NOT NULL,
    FOREIGN KEY (Employee_ID) REFERENCES EMPLOYEE(Employee_ID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================
-- 8. MAINTENANCE_STAFF — ISA subtype of EMPLOYEE
-- ============================================================
CREATE TABLE MAINTENANCE_STAFF (
    Employee_ID    INT          PRIMARY KEY,
    Shift_Type     VARCHAR(50)  NOT NULL,          -- Day, Night, Rotational
    Trade_Skill    VARCHAR(100) NOT NULL,          -- Electrical, Mechanical, etc.
    FOREIGN KEY (Employee_ID) REFERENCES EMPLOYEE(Employee_ID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================
-- 9. COACH_SEAT — Weak Entity (depends on TRAIN via CONTAINS)
--    Relationship: TRAIN 1 ——— CONTAINS ——— N COACH_SEAT
--    Seat_ID is derived from Coach_No (shown as dashed oval)
-- ============================================================
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

-- ============================================================
-- 10. PASSENGER — Strong Entity
-- ============================================================
CREATE TABLE PASSENGER (
    Passenger_ID  INT          PRIMARY KEY AUTO_INCREMENT,
    Name          VARCHAR(100) NOT NULL,
    Age           INT          NOT NULL CHECK (Age > 0 AND Age < 150),
    Gender        ENUM('Male', 'Female', 'Other') NOT NULL,
    Phone_no      VARCHAR(15)  NOT NULL,
    Aadhar_no     VARCHAR(12)  NOT NULL UNIQUE
);

-- ============================================================
-- 11. BOOKING — Strong Entity
--     Relationships:
--       PASSENGER 1 ——— MAKES ——— N BOOKING
--       BOOKING   N ——— STARTS AT ——— 1 STATION
--       BOOKING   N ——— ENDS AT   ——— 1 STATION
--       BOOKING   N ——— BOOKED ON ——— 1 TIMETABLE_EVENT (aggregation)
-- ============================================================
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

-- ============================================================
-- 12. BOOKING_SEAT — Junction table for N:M relationship
--     Relationship: COACH_SEAT N ——— RESERVES ——— M BOOKING
-- ============================================================
CREATE TABLE BOOKING_SEAT (
    Booking_ID    INT NOT NULL,
    Seat_ID       INT NOT NULL,
    PRIMARY KEY (Booking_ID, Seat_ID),
    FOREIGN KEY (Booking_ID) REFERENCES BOOKING(Booking_ID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (Seat_ID)    REFERENCES COACH_SEAT(Seat_ID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================
-- 13. PAYMENT — Strong Entity
--     Relationship: BOOKING 1 ——— HAS ——— 1 PAYMENT
-- ============================================================
CREATE TABLE PAYMENT (
    Payment_ID     INT            PRIMARY KEY AUTO_INCREMENT,
    Booking_ID     INT            NOT NULL UNIQUE,   -- 1:1 with BOOKING
    Amount         DECIMAL(10,2)  NOT NULL CHECK (Amount > 0),
    Payment_Date   DATE           NOT NULL,
    Payment_Status VARCHAR(20)    NOT NULL DEFAULT 'Pending',  -- Pending, Completed, Refunded
    FOREIGN KEY (Booking_ID) REFERENCES BOOKING(Booking_ID)
        ON DELETE CASCADE ON UPDATE CASCADE
);

SELECT 'All 14 tables created successfully!' AS Result;
