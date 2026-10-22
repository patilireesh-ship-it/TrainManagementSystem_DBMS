
USE TrainManagementSystem;


-- TRAIN (10 trains)
INSERT INTO TRAIN (Train_No, Train_Name, Train_Type, Capacity) VALUES
(12951, 'Mumbai Rajdhani Express',   'Rajdhani',   1200),
(12301, 'Howrah Rajdhani Express',   'Rajdhani',   1100),
(12002, 'Bhopal Shatabdi',          'Shatabdi',    800),
(12627, 'Karnataka Express',        'Superfast',   1500),
(12839, 'Chennai Mail',             'Mail',        1800),
(22691, 'Bangalore Rajdhani',       'Rajdhani',    1000),
(12259, 'Sealdah Duronto',          'Duronto',      900),
(12431, 'Trivandrum Rajdhani',      'Rajdhani',    1050),
(11301, 'Udyan Express',            'Express',     1400),
(12049, 'Gatimaan Express',         'Semi-Highspeed', 700);


-- STATION (12 stations)
INSERT INTO STATION (Station_ID, Station_Name, City, Platform_No) VALUES
(1,  'New Delhi',               'Delhi',       16),
(2,  'Mumbai Central',          'Mumbai',      12),
(3,  'Howrah Junction',         'Kolkata',     23),
(4,  'Chennai Central',         'Chennai',     17),
(5,  'Bangalore City Junction', 'Bangalore',   10),
(6,  'Bhopal Junction',         'Bhopal',       6),
(7,  'Jaipur Junction',         'Jaipur',       5),
(8,  'Agra Cantt',              'Agra',         5),
(9,  'Trivandrum Central',      'Thiruvananthapuram', 5),
(10, 'Pune Junction',           'Pune',         6),
(11, 'Nagpur Junction',         'Nagpur',       8),
(12, 'Sealdah',                 'Kolkata',      13);


-- SCHEDULE 
INSERT INTO SCHEDULE (Train_No, Arrival_Time, Departure_Time, Running_Date) VALUES
(12951, '06:00:00', '06:15:00', '2026-10-12'),   -- Schedule_ID = 1
(12951, '16:35:00', '16:35:00', '2026-10-12'),   -- Schedule_ID = 2
(12301, '17:00:00', '17:10:00', '2026-10-12'),   
(12002, '06:15:00', '06:20:00', '2026-10-12'),   
(12627, '21:00:00', '21:15:00', '2026-10-13'),   
(12839, '22:30:00', '22:45:00', '2026-10-13'),   
(22691, '20:50:00', '21:05:00', '2026-10-13'),   
(12259, '12:30:00', '12:45:00', '2026-10-14'),    
(12431, '11:00:00', '11:15:00', '2026-10-14'),   
(11301, '08:10:00', '08:25:00', '2026-10-14'),   
(12049, '08:10:00', '08:10:00', '2026-10-15'),   
(12049, '09:50:00', '09:50:00', '2026-10-15');   

-- TRAIN_STOPS_AT (route stops)
INSERT INTO TRAIN_STOPS_AT (Train_No, Station_ID, Stop_Order, Arrival_Time, Departure_Time) VALUES
-- Mumbai Rajdhani: Delhi → Jaipur → Mumbai
(12951, 1,  1, NULL,        '16:35:00'),
(12951, 7,  2, '22:10:00', '22:15:00'),
(12951, 2,  3, '06:00:00',  NULL),
-- Howrah Rajdhani: Delhi → Howrah
(12301, 1,  1, NULL,        '17:10:00'),
(12301, 3,  2, '09:55:00',  NULL),
-- Karnataka Express: Delhi → Agra → Bangalore
(12627, 1,  1, NULL,        '21:15:00'),
(12627, 8,  2, '00:05:00', '00:10:00'),
(12627, 5,  3, '06:40:00',  NULL),
-- Gatimaan Express: Delhi → Agra
(12049, 1,  1, NULL,        '08:10:00'),
(12049, 8,  2, '09:50:00',  NULL);

-- TIMETABLE_EVENT — Aggregation of TRAIN + STATION + SCHEDULE
INSERT INTO TIMETABLE_EVENT (Event_ID, Train_No, Station_ID, Schedule_ID) VALUES
('EVT-12951-DEL',  12951, 1,  2),   -- Mumbai Rajdhani at Delhi (departure schedule)
('EVT-12951-JPR',  12951, 7,  1),   -- Mumbai Rajdhani at Jaipur
('EVT-12951-MUM',  12951, 2,  1),   -- Mumbai Rajdhani at Mumbai (arrival schedule)
('EVT-12301-DEL',  12301, 1,  3),   -- Howrah Rajdhani at Delhi
('EVT-12301-HWH',  12301, 3,  3),   -- Howrah Rajdhani at Howrah
('EVT-12002-DEL',  12002, 1,  4),   -- Bhopal Shatabdi at Delhi
('EVT-12627-DEL',  12627, 1,  5),   -- Karnataka Express at Delhi
('EVT-12627-AGR',  12627, 8,  5),   -- Karnataka Express at Agra
('EVT-12627-BNG',  12627, 5,  5),   -- Karnataka Express at Bangalore
('EVT-12839-DEL',  12839, 1,  6),   -- Chennai Mail at Delhi
('EVT-12839-CHN',  12839, 4,  6),   -- Chennai Mail at Chennai
('EVT-12049-DEL',  12049, 1,  11),  -- Gatimaan Express at Delhi
('EVT-12049-AGR',  12049, 8,  12);  -- Gatimaan Express at Agra

-- EMPLOYEE (12)
INSERT INTO EMPLOYEE (Employee_ID, Name, Salary, Aadhar_no, Phone_no, Event_ID) VALUES
(1,  'Rajesh Kumar',     65000.00, '234567890123', '9876543210', 'EVT-12951-DEL'),
(2,  'Sunil Sharma',     60000.00, '345678901234', '9876543211', 'EVT-12301-DEL'),
(3,  'Amit Patel',       55000.00, '456789012345', '9876543212', 'EVT-12002-DEL'),
(4,  'Vikram Singh',     62000.00, '567890123456', '9876543213', 'EVT-12627-DEL'),
(5,  'Deepak Verma',     40000.00, '678901234567', '9876543214', 'EVT-12951-DEL'),
(6,  'Manoj Tiwari',     38000.00, '789012345678', '9876543215', 'EVT-12301-DEL'),
(7,  'Ravi Mishra',      42000.00, '890123456789', '9876543216', 'EVT-12002-DEL'),
(8,  'Sanjay Gupta',     39000.00, '901234567890', '9876543217', 'EVT-12627-DEL'),
(9,  'Pradeep Joshi',    58000.00, '123456789012', '9876543218', 'EVT-12839-DEL'),
(10, 'Ankit Chauhan',    37000.00, '112233445566', '9876543219', 'EVT-12839-DEL'),
(11, 'Ramesh Yadav',     35000.00, '223344556677', '9876543220', 'EVT-12951-MUM'),
(12, 'Suresh Pandey',    36000.00, '334455667788', '9876543221', 'EVT-12301-HWH');

-- DRIVER 
INSERT INTO DRIVER (Employee_ID, License_No) VALUES
(1, 'DL-2020-RLY-001'),
(2, 'DL-2019-RLY-045'),
(3, 'DL-2021-RLY-112'),
(4, 'DL-2018-RLY-078'),
(9, 'DL-2022-RLY-203');

-- TC
INSERT INTO TC (Employee_ID, Badge_No, Assigned_Zone) VALUES
(5,  'TC-MUM-0501', 'Western Zone'),
(6,  'TC-HWH-0602', 'Eastern Zone'),
(7,  'TC-BPL-0703', 'West Central Zone'),
(8,  'TC-BNG-0804', 'South Western Zone'),
(10, 'TC-CHN-1005', 'Southern Zone');


-- MAINTENANCE_STAFF 
INSERT INTO MAINTENANCE_STAFF (Employee_ID, Shift_Type, Trade_Skill) VALUES
(11, 'Night',       'Electrical'),
(12, 'Rotational',  'Mechanical');

-- COACH_SEAT 
INSERT INTO COACH_SEAT (Train_No, Coach_No, Seat_No, Class) VALUES
-- Mumbai Rajdhani 
(12951, 'A1', 1,  '1AC'),
(12951, 'A1', 2,  '1AC'),
(12951, 'A1', 3,  '1AC'),
(12951, 'B1', 1,  '2AC'),
(12951, 'B1', 2,  '2AC'),
(12951, 'B1', 3,  '2AC'),
(12951, 'B2', 1,  '2AC'),
(12951, 'B2', 2,  '2AC'),
(12951, 'S1', 1,  'SL'),
(12951, 'S1', 2,  'SL'),
-- Howrah Rajdhani 
(12301, 'A1', 1,  '1AC'),
(12301, 'A1', 2,  '1AC'),
(12301, 'B1', 1,  '2AC'),
(12301, 'B1', 2,  '2AC'),
(12301, 'B1', 3,  '2AC'),
(12301, 'S1', 1,  'SL'),
(12301, 'S1', 2,  'SL'),
(12301, 'S1', 3,  'SL'),
-- Karnataka Express
(12627, 'B1', 1,  '2AC'),
(12627, 'B1', 2,  '2AC'),
(12627, 'S1', 1,  'SL'),
(12627, 'S1', 2,  'SL'),
(12627, 'S1', 3,  'SL'),
(12627, 'G1', 1,  'GEN'),
(12627, 'G1', 2,  'GEN');

-- PASSENGER 
INSERT INTO PASSENGER (Passenger_ID, Name, Age, Gender, Phone_no, Aadhar_no) VALUES
(1,  'Aarav Mehta',      28, 'Male',   '8001234501', '100020003001'),
(2,  'Priya Sharma',     35, 'Female', '8001234502', '100020003002'),
(3,  'Rohan Desai',      42, 'Male',   '8001234503', '100020003003'),
(4,  'Sneha Iyer',       25, 'Female', '8001234504', '100020003004'),
(5,  'Karthik Nair',     55, 'Male',   '8001234505', '100020003005'),
(6,  'Ananya Reddy',     30, 'Female', '8001234506', '100020003006'),
(7,  'Vikash Yadav',     19, 'Male',   '8001234507', '100020003007'),
(8,  'Meera Joshi',      60, 'Female', '8001234508', '100020003008'),
(9,  'Arjun Kapoor',     33, 'Male',   '8001234509', '100020003009'),
(10, 'Divya Pillai',     22, 'Female', '8001234510', '100020003010');


-- BOOKING (10 bookings)
INSERT INTO BOOKING (Booking_ID, Passenger_ID, Event_ID, Start_Station, End_Station, Booking_Date, Journey_Date, Status, Class) VALUES
(1,  1,  'EVT-12951-DEL', 1, 2,  '2026-10-01', '2026-10-12', 'Confirmed', '1AC'),
(2,  2,  'EVT-12951-DEL', 1, 2,  '2026-10-02', '2026-10-12', 'Confirmed', '2AC'),
(3,  3,  'EVT-12301-DEL', 1, 3,  '2026-10-03', '2026-10-12', 'Confirmed', '1AC'),
(4,  4,  'EVT-12627-DEL', 1, 5,  '2026-10-04', '2026-10-13', 'Waiting',   '2AC'),
(5,  5,  'EVT-12839-DEL', 1, 4,  '2026-10-05', '2026-10-13', 'Confirmed', 'SL'),
(6,  6,  'EVT-12002-DEL', 1, 6,  '2026-10-06', '2026-10-12', 'Cancelled', '2AC'),
(7,  7,  'EVT-12049-DEL', 1, 8,  '2026-10-07', '2026-10-15', 'Confirmed', 'GEN'),
(8,  8,  'EVT-12951-DEL', 1, 7,  '2026-10-08', '2026-10-12', 'Confirmed', 'SL'),
(9,  9,  'EVT-12301-DEL', 1, 3,  '2026-10-09', '2026-10-12', 'Confirmed', '2AC'),
(10, 10, 'EVT-12627-DEL', 1, 5,  '2026-10-10', '2026-10-13', 'Confirmed', 'SL');


-- BOOKING_SEAT 
INSERT INTO BOOKING_SEAT (Booking_ID, Seat_ID) VALUES
(1, 1),   -- Booking 1 → Seat A1-1 on 12951
(2, 4),   -- Booking 2 → Seat B1-1 on 12951
(2, 5),   -- Booking 2 → Seat B1-2 on 12951 (2 seats booked)
(3, 11),  -- Booking 3 → Seat A1-1 on 12301
(5, 9),   -- Booking 5 → Seat S1-1 on 12951
(7, 24),  -- Booking 7 → GEN seat on 12627
(8, 10),  -- Booking 8 → SL seat S1-2 on 12951
(9, 13),  -- Booking 9 → B1-1 on 12301
(10, 21); -- Booking 10 → SL seat on 12627


-- PAYMENT 
INSERT INTO PAYMENT (Booking_ID, Amount, Payment_Date, Payment_Status) VALUES
(1,  4500.00,  '2026-10-01', 'Completed'),
(2,  2800.00,  '2026-10-02', 'Completed'),
(3,  4200.00,  '2026-10-03', 'Completed'),
(4,  2600.00,  '2026-10-04', 'Pending'),
(5,   850.00,  '2026-10-05', 'Completed'),
(6,  2800.00,  '2026-10-06', 'Refunded'),
(7,   250.00,  '2026-10-07', 'Completed'),
(8,   650.00,  '2026-10-08', 'Completed'),
(9,  3200.00,  '2026-10-09', 'Completed'),
(10,  750.00,  '2026-10-10', 'Completed');

SELECT 'Sample data inserted successfully!' AS Result;
