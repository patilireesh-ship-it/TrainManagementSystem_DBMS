const express = require('express');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 9295;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'public')));

// View engine
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// API Routes
const trainRoutes = require('./routes/trainRoutes');
const employeeRoutes = require('./routes/employeeRoutes');
const bookingRoutes = require('./routes/bookingRoutes');

app.use('/api', trainRoutes);
app.use('/api', employeeRoutes);
app.use('/api', bookingRoutes);

// Page Routes
app.get('/', (req, res) => res.redirect('/user'));
app.get('/user', (req, res) => res.render('user'));
app.get('/timetable', (req, res) => res.render('timetable'));
app.get('/bookings', (req, res) => res.render('bookings'));
app.get('/employee', (req, res) => res.render('employee'));

// Employee dashboards — fetch data and render
const db = require('./db');

app.get('/employee/driver/:id', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT e.Employee_ID, e.Name, e.Salary, e.Aadhar_no, e.Phone_no,
             d.License_No,
             t.Train_No, t.Train_Name, t.Train_Type,
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

    if (rows.length === 0) return res.status(404).send('Driver not found');

    // Get route stops for the assigned train
    const [stops] = await db.query(`
      SELECT tsa.Stop_Order, tsa.Arrival_Time, tsa.Departure_Time,
             s.Station_Name, s.City
      FROM TRAIN_STOPS_AT tsa
      JOIN STATION s ON tsa.Station_ID = s.Station_ID
      WHERE tsa.Train_No = ?
      ORDER BY tsa.Stop_Order
    `, [rows[0].Train_No]);

    res.render('driver', { employee: rows[0], stops });
  } catch (err) {
    console.error(err);
    res.status(500).send('Server error');
  }
});

app.get('/employee/tc/:id', async (req, res) => {
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

    if (rows.length === 0) return res.status(404).send('Ticket Collector not found');

    // Get passengers booked on the assigned train
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

    res.render('tc', { employee: rows[0], passengers });
  } catch (err) {
    console.error(err);
    res.status(500).send('Server error');
  }
});

app.get('/employee/maintenance/:id', async (req, res) => {
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

    if (rows.length === 0) return res.status(404).send('Maintenance Staff not found');

    res.render('maintenance', { employee: rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).send('Server error');
  }
});

app.listen(PORT, () => {
  console.log(`🚂 Train Management System running on http://localhost:${PORT}`);
});
