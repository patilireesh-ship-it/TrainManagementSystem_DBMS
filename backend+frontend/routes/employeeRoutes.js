const express = require('express');
const router = express.Router();
const db = require('../db');

// GET /api/employees — all employees with type using MySQL View view_employee_summary
router.get('/employees', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT 
        Employee_ID, 
        Name, 
        Salary, 
        Phone_no,
        CASE
          WHEN Role = 'Driver' THEN 'Driver'
          WHEN Role = 'Ticket Collector' THEN 'TC'
          WHEN Role = 'Maintenance Staff' THEN 'Maintenance'
          ELSE Role
        END AS role
      FROM view_employee_summary
      ORDER BY Employee_ID
    `);
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch employees' });
  }
});

// GET /api/employee/driver/:id
router.get('/employee/driver/:id', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT e.Employee_ID, e.Name, e.Salary, e.Aadhar_no, e.Phone_no,
             d.License_No,
             t.Train_No, t.Train_Name, t.Train_Type, t.Capacity,
             s.Station_Name, s.City, s.Platform_No,
             sc.Running_Date, sc.Arrival_Time AS Sched_Arrival, sc.Departure_Time AS Sched_Departure,
             te.Event_ID
      FROM EMPLOYEE e
      JOIN DRIVER d ON e.Employee_ID = d.Employee_ID
      LEFT JOIN TIMETABLE_EVENT te ON e.Event_ID = te.Event_ID
      LEFT JOIN TRAIN t ON te.Train_No = t.Train_No
      LEFT JOIN STATION s ON te.Station_ID = s.Station_ID
      LEFT JOIN SCHEDULE sc ON te.Schedule_ID = sc.Schedule_ID
      WHERE e.Employee_ID = ?
    `, [req.params.id]);

    if (rows.length === 0) return res.status(404).json({ error: 'Driver not found' });

    const [stops] = await db.query(`
      SELECT tsa.Stop_Order, tsa.Arrival_Time, tsa.Departure_Time,
             s.Station_Name, s.City
      FROM TRAIN_STOPS_AT tsa
      JOIN STATION s ON tsa.Station_ID = s.Station_ID
      WHERE tsa.Train_No = ?
      ORDER BY tsa.Stop_Order
    `, [rows[0].Train_No]);

    res.json({ employee: rows[0], stops });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch driver details' });
  }
});

// GET /api/employee/tc/:id
router.get('/employee/tc/:id', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT e.Employee_ID, e.Name, e.Salary, e.Aadhar_no, e.Phone_no,
             tc.Badge_No, tc.Assigned_Zone,
             t.Train_No, t.Train_Name, t.Train_Type,
             s.Station_Name, s.City, s.Platform_No,
             sc.Running_Date, sc.Arrival_Time AS Sched_Arrival, sc.Departure_Time AS Sched_Departure,
             te.Event_ID
      FROM EMPLOYEE e
      JOIN TC tc ON e.Employee_ID = tc.Employee_ID
      LEFT JOIN TIMETABLE_EVENT te ON e.Event_ID = te.Event_ID
      LEFT JOIN TRAIN t ON te.Train_No = t.Train_No
      LEFT JOIN STATION s ON te.Station_ID = s.Station_ID
      LEFT JOIN SCHEDULE sc ON te.Schedule_ID = sc.Schedule_ID
      WHERE e.Employee_ID = ?
    `, [req.params.id]);

    if (rows.length === 0) return res.status(404).json({ error: 'Ticket Collector not found' });

    const [passengers] = await db.query(`
      SELECT b.Booking_ID, b.Status, b.Class,
             p.Name AS Passenger_Name, p.Age, p.Gender,
             cs.Coach_No, cs.Seat_No
      FROM BOOKING b
      JOIN PASSENGER p ON b.Passenger_ID = p.Passenger_ID
      JOIN TIMETABLE_EVENT te ON b.Event_ID = te.Event_ID
      LEFT JOIN BOOKING_SEAT bs ON b.Booking_ID = bs.Booking_ID
      LEFT JOIN COACH_SEAT cs ON bs.Seat_ID = cs.Seat_ID
      WHERE te.Train_No = ?
      ORDER BY cs.Coach_No, cs.Seat_No
    `, [rows[0].Train_No]);

    res.json({ employee: rows[0], passengers });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch TC details' });
  }
});

// GET /api/employee/maintenance/:id
router.get('/employee/maintenance/:id', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT e.Employee_ID, e.Name, e.Salary, e.Aadhar_no, e.Phone_no,
             ms.Shift_Type, ms.Trade_Skill,
             t.Train_No, t.Train_Name, t.Train_Type,
             s.Station_Name, s.City, s.Platform_No,
             sc.Running_Date, sc.Arrival_Time AS Sched_Arrival, sc.Departure_Time AS Sched_Departure,
             te.Event_ID
      FROM EMPLOYEE e
      JOIN MAINTENANCE_STAFF ms ON e.Employee_ID = ms.Employee_ID
      LEFT JOIN TIMETABLE_EVENT te ON e.Event_ID = te.Event_ID
      LEFT JOIN TRAIN t ON te.Train_No = t.Train_No
      LEFT JOIN STATION s ON te.Station_ID = s.Station_ID
      LEFT JOIN SCHEDULE sc ON te.Schedule_ID = sc.Schedule_ID
      WHERE e.Employee_ID = ?
    `, [req.params.id]);

    if (rows.length === 0) return res.status(404).json({ error: 'Maintenance staff not found' });

    res.json({ employee: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch maintenance staff details' });
  }
});

module.exports = router;
