const express = require('express');
const router = express.Router();
const db = require('../db');

const FARES = { '1AC': 4500, '2AC': 2800, '3AC': 1800, 'SL': 750, 'GEN': 250 };

// Helper to verify admin access using SQL SHA2
async function verifyAdminAuth(req) {
  const adminKey = req.headers['x-admin-key'] || req.query.adminKey || (req.body && req.body.adminKey);
  const adminPass = process.env.ADMIN_PASSWORD || '1234';
  if (!adminKey) return false;

  try {
    const [check] = await db.query(
      'SELECT (SHA2(?, 256) = SHA2(?, 256)) AS is_valid',
      [adminKey, adminPass]
    );
    return check[0] && check[0].is_valid === 1;
  } catch (e) {
    return adminKey === adminPass;
  }
}

// POST /api/admin/verify — verify admin password using SQL cryptographic function SHA2()
router.post('/admin/verify', async (req, res) => {
  const { password } = req.body;
  const adminPass = process.env.ADMIN_PASSWORD || '1234';

  if (!password) {
    return res.status(400).json({ success: false, error: 'Password is required' });
  }

  try {
    // Utilize MySQL built-in SHA2() function for secure password verification
    const [rows] = await db.query(
      'SELECT (SHA2(?, 256) = SHA2(?, 256)) AS is_valid',
      [password, adminPass]
    );

    if (rows[0] && rows[0].is_valid === 1) {
      return res.json({ success: true, message: 'Administrator authenticated' });
    } else {
      return res.status(401).json({ success: false, error: 'Invalid Administrator Password' });
    }
  } catch (err) {
    if (password === adminPass) {
      return res.json({ success: true, message: 'Administrator authenticated' });
    }
    return res.status(401).json({ success: false, error: 'Invalid Administrator Password' });
  }
});

// DELETE /api/admin/booking/:id — Delete a single booking (and associated passenger if orphaned)
router.delete('/admin/booking/:id', async (req, res) => {
  const isAuth = await verifyAdminAuth(req);
  if (!isAuth) {
    return res.status(401).json({ success: false, error: 'Unauthorized: Administrator access required' });
  }

  const bookingId = req.params.id;
  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    // 1. Find passenger associated with this booking
    const [rows] = await connection.query(
      'SELECT Passenger_ID FROM BOOKING WHERE Booking_ID = ?',
      [bookingId]
    );
    if (rows.length === 0) {
      await connection.rollback();
      return res.status(404).json({ success: false, error: 'Booking #' + bookingId + ' not found' });
    }
    const passengerId = rows[0].Passenger_ID;

    // 2. Delete the booking (cascades to BOOKING_SEAT and PAYMENT)
    await connection.query('DELETE FROM BOOKING WHERE Booking_ID = ?', [bookingId]);

    // 3. Delete passenger if they have no other bookings remaining
    const [otherBookings] = await connection.query(
      'SELECT COUNT(*) AS cnt FROM BOOKING WHERE Passenger_ID = ?',
      [passengerId]
    );
    let passengerDeleted = false;
    if (otherBookings[0].cnt === 0) {
      await connection.query('DELETE FROM PASSENGER WHERE Passenger_ID = ?', [passengerId]);
      passengerDeleted = true;
    }

    await connection.commit();
    res.json({
      success: true,
      message: `Booking #${bookingId} ${passengerDeleted ? 'and Passenger #' + passengerId : ''} successfully deleted`
    });
  } catch (err) {
    await connection.rollback();
    console.error(err);
    res.status(500).json({ success: false, error: 'Failed to delete booking: ' + err.message });
  } finally {
    connection.release();
  }
});

// DELETE /api/admin/bookings/all — Delete all bookings and all passenger records
router.delete('/admin/bookings/all', async (req, res) => {
  const isAuth = await verifyAdminAuth(req);
  if (!isAuth) {
    return res.status(401).json({ success: false, error: 'Unauthorized: Administrator access required' });
  }

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    // 1. Delete all bookings (cascades to BOOKING_SEAT and PAYMENT)
    await connection.query('DELETE FROM BOOKING');
    // 2. Delete all passengers
    await connection.query('DELETE FROM PASSENGER');

    // 3. Reset auto-increment counters back to 1
    await connection.query('ALTER TABLE BOOKING AUTO_INCREMENT = 1');
    await connection.query('ALTER TABLE PASSENGER AUTO_INCREMENT = 1');
    await connection.query('ALTER TABLE PAYMENT AUTO_INCREMENT = 1');

    await connection.commit();
    res.json({ success: true, message: 'All bookings and passenger records have been cleared from database' });
  } catch (err) {
    await connection.rollback();
    console.error(err);
    res.status(500).json({ success: false, error: 'Failed to clear bookings and passengers: ' + err.message });
  } finally {
    connection.release();
  }
});

// POST /api/admin/demo-data — Add/restore the 10 demo passengers, bookings & payments from code
router.post('/admin/demo-data', async (req, res) => {
  const isAuth = await verifyAdminAuth(req);
  if (!isAuth) {
    return res.status(401).json({ success: false, error: 'Unauthorized: Administrator access required' });
  }

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    // 1. Insert/restore 10 demo passengers from InsertionOFdata.sql
    await connection.query(`
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
      (10, 'Divya Pillai',     22, 'Female', '8001234510', '100020003010')
      ON DUPLICATE KEY UPDATE Name = VALUES(Name), Phone_no = VALUES(Phone_no)
    `);

    // 2. Insert/ensure 10 demo bookings from InsertionOFdata.sql
    await connection.query(`
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
      (10, 10, 'EVT-12627-DEL', 1, 5,  '2026-10-10', '2026-10-13', 'Confirmed', 'SL')
      ON DUPLICATE KEY UPDATE Status = VALUES(Status), Class = VALUES(Class)
    `);

    // 3. Link sample seats
    await connection.query(`
      INSERT IGNORE INTO BOOKING_SEAT (Booking_ID, Seat_ID) VALUES
      (1, 1),
      (2, 4),
      (2, 5),
      (3, 11),
      (5, 9),
      (7, 24),
      (8, 10),
      (9, 13),
      (10, 21)
    `);

    // 4. Insert sample payments
    await connection.query(`
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
      (10,  750.00,  '2026-10-10', 'Completed')
      ON DUPLICATE KEY UPDATE Amount = VALUES(Amount), Payment_Status = VALUES(Payment_Status)
    `);

    await connection.commit();
    res.json({ success: true, message: 'Sample demo passengers, bookings (1-10), and payments restored successfully' });
  } catch (err) {
    await connection.rollback();
    console.error(err);
    res.status(500).json({ success: false, error: 'Failed to insert demo data: ' + err.message });
  } finally {
    connection.release();
  }
});

// GET /api/all-bookings — get all live bookings with passenger, seat, and payment details (Admin Only)
// Supports optional SQL query search via ?search=passengerName
router.get('/all-bookings', async (req, res) => {
  const adminKey = req.headers['x-admin-key'] || req.query.adminKey;
  const adminPass = process.env.ADMIN_PASSWORD || '1234';

  if (!adminKey) {
    return res.status(401).json({ error: 'Unauthorized: Administrator access required' });
  }

  try {
    // Verify Administrator access using SQL SHA2() function
    const [check] = await db.query(
      'SELECT (SHA2(?, 256) = SHA2(?, 256)) AS is_valid',
      [adminKey, adminPass]
    );

    if (!check[0] || check[0].is_valid !== 1) {
      return res.status(401).json({ error: 'Unauthorized: Invalid Administrator Password' });
    }

    const searchQuery = (req.query.search || '').trim();
    let sql = `
      SELECT 
        Booking_ID,
        Passenger_Name,
        Phone_no,
        Age,
        Gender,
        Train_No,
        Train_Name,
        Origin,
        Destination,
        Journey_Date,
        Booking_Date,
        Class,
        Booking_Status,
        Coach_No,
        Seat_No,
        Payment_ID,
        Amount,
        Payment_Status
      FROM view_booking_details
    `;

    const params = [];
    if (searchQuery) {
      sql += ' WHERE Passenger_Name LIKE ?';
      params.push(`%${searchQuery}%`);
    }

    sql += ' ORDER BY Booking_ID DESC';

    const [rows] = await db.query(sql, params);
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch bookings' });
  }
});

// GET /api/admin/search-passenger — Dedicated SQL search for passengers by name with booking count
router.get('/admin/search-passenger', async (req, res) => {
  const isAuth = await verifyAdminAuth(req);
  if (!isAuth) {
    return res.status(401).json({ success: false, error: 'Unauthorized: Administrator access required' });
  }

  const name = (req.query.name || '').trim();
  try {
    let sql = `
      SELECT 
        p.Passenger_ID,
        p.Name,
        p.Age,
        p.Gender,
        p.Phone_no,
        p.Aadhar_no,
        COUNT(b.Booking_ID) AS Total_Bookings
      FROM PASSENGER p
      LEFT JOIN BOOKING b ON p.Passenger_ID = b.Passenger_ID
    `;
    const params = [];
    if (name) {
      sql += ' WHERE p.Name LIKE ?';
      params.push(`%${name}%`);
    }
    sql += ' GROUP BY p.Passenger_ID, p.Name, p.Age, p.Gender, p.Phone_no, p.Aadhar_no ORDER BY p.Name ASC';

    const [passengers] = await db.query(sql, params);
    res.json({ success: true, count: passengers.length, passengers });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: 'Failed to search passengers: ' + err.message });
  }
});

// POST /api/book — create a booking
router.post('/book', async (req, res) => {
  const { passengerName, age, gender, phone, aadhar, trainNo, startStation, endStation, journeyDate, seatClass, paymentMethod } = req.body;

  if (!passengerName || !age || !gender || !phone || !aadhar || !trainNo || !startStation || !endStation || !journeyDate || !seatClass) {
    return res.status(400).json({ error: 'All fields are required' });
  }

  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();

    // 1. Find or create passenger
    let [existing] = await connection.query(
      'SELECT Passenger_ID FROM PASSENGER WHERE Aadhar_no = ?', [aadhar]
    );

    let passengerId;
    if (existing.length > 0) {
      passengerId = existing[0].Passenger_ID;
    } else {
      const [result] = await connection.query(
        'INSERT INTO PASSENGER (Name, Age, Gender, Phone_no, Aadhar_no) VALUES (?, ?, ?, ?, ?)',
        [passengerName, parseInt(age), gender, phone, aadhar]
      );
      passengerId = result.insertId;
    }

    // 2. Find matching event_id
    const [events] = await connection.query(
      `SELECT te.Event_ID FROM TIMETABLE_EVENT te
       WHERE te.Train_No = ? AND te.Station_ID = ?
       LIMIT 1`,
      [trainNo, startStation]
    );

    let eventId;
    if (events.length > 0) {
      eventId = events[0].Event_ID;
    } else {
      // Create a fallback event ID if one doesn't exist
      eventId = `EVT-${trainNo}-BK${Date.now()}`;
      // Find any schedule for this train
      const [schedules] = await connection.query(
        'SELECT Schedule_ID FROM SCHEDULE WHERE Train_No = ? LIMIT 1', [trainNo]
      );
      if (schedules.length === 0) {
        await connection.rollback();
        return res.status(400).json({ error: 'No schedule found for this train' });
      }
      await connection.query(
        'INSERT INTO TIMETABLE_EVENT (Event_ID, Train_No, Station_ID, Schedule_ID) VALUES (?, ?, ?, ?)',
        [eventId, trainNo, startStation, schedules[0].Schedule_ID]
      );
    }

    // 3. Find or directly create and allocate an available seat in the database
    const [availableSeats] = await connection.query(`
      SELECT cs.Seat_ID, cs.Coach_No, cs.Seat_No, cs.Class FROM COACH_SEAT cs
      WHERE cs.Train_No = ? AND cs.Class = ?
        AND cs.Seat_ID NOT IN (
          SELECT bs.Seat_ID FROM BOOKING_SEAT bs
          JOIN BOOKING b ON bs.Booking_ID = b.Booking_ID
          WHERE b.Status != 'Cancelled'
        )
      ORDER BY cs.Coach_No, cs.Seat_No
      LIMIT 1
    `, [trainNo, seatClass]);

    let seatId = null;
    let coachNo = '';
    let seatNo = 1;

    if (availableSeats.length > 0) {
      seatId = availableSeats[0].Seat_ID;
      coachNo = availableSeats[0].Coach_No;
      seatNo = availableSeats[0].Seat_No;
    } else {
      // Direct automatic seat creation in COACH_SEAT table
      const coachMap = { '1AC': 'A1', '2AC': 'B1', '3AC': 'B2', 'SL': 'S1', 'GEN': 'G1' };
      coachNo = coachMap[seatClass] || 'G1';

      // Find next seat number for this coach on this train
      const [maxSeatRow] = await connection.query(
        'SELECT COALESCE(MAX(Seat_No), 0) + 1 AS next_seat FROM COACH_SEAT WHERE Train_No = ? AND Coach_No = ?',
        [trainNo, coachNo]
      );
      seatNo = maxSeatRow[0].next_seat;

      // Insert new seat directly into COACH_SEAT table
      const [newSeatResult] = await connection.query(
        'INSERT INTO COACH_SEAT (Train_No, Coach_No, Seat_No, Class) VALUES (?, ?, ?, ?)',
        [trainNo, coachNo, seatNo, seatClass]
      );
      seatId = newSeatResult.insertId;
    }

    const status = 'Confirmed';

    // 4. Create booking
    const bookingDate = new Date().toISOString().split('T')[0];
    const [booking] = await connection.query(
      `INSERT INTO BOOKING (Passenger_ID, Event_ID, Start_Station, End_Station, Booking_Date, Journey_Date, Status, Class)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [passengerId, eventId, startStation, endStation, bookingDate, journeyDate, status, seatClass]
    );

    const bookingId = booking.insertId;

    // 5. Directly link the booked seat into BOOKING_SEAT junction table
    await connection.query(
      'INSERT INTO BOOKING_SEAT (Booking_ID, Seat_ID) VALUES (?, ?)',
      [bookingId, seatId]
    );

    // 6. Create payment
    const fare = FARES[seatClass] || 250;
    const selectedMethod = paymentMethod || 'UPI';
    // Online payments (UPI, Card, NetBanking, Wallets) are immediately Completed; only Counter is Pending
    const payStatus = selectedMethod === 'Counter' ? 'Pending' : 'Completed';

    const [payResult] = await connection.query(
      `INSERT INTO PAYMENT (Booking_ID, Amount, Payment_Date, Payment_Status) VALUES (?, ?, ?, ?)`,
      [bookingId, fare, bookingDate, payStatus]
    );

    await connection.commit();

    const seatInfo = {
      Coach_No: coachNo,
      Seat_No: seatNo,
      Class: seatClass
    };

    res.json({
      success: true,
      booking: {
        bookingId,
        passengerId,
        passengerName,
        trainNo,
        status,
        class: seatClass,
        fare,
        journeyDate,
        seat: seatInfo,
        paymentId: payResult.insertId,
        paymentMethod: selectedMethod,
        paymentStatus: payStatus
      }
    });
  } catch (err) {
    await connection.rollback();
    console.error(err);
    res.status(500).json({ error: 'Booking failed: ' + err.message });
  } finally {
    connection.release();
  }
});

module.exports = router;
