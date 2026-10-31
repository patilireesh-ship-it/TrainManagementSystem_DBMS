const express = require('express');
const router = express.Router();
const db = require('../db');

// Fare lookup
const FARES = { '1AC': 4500, '2AC': 2800, '3AC': 1800, 'SL': 750, 'GEN': 250 };

// GET /api/stations — list all stations
router.get('/stations', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT Station_ID, Station_Name, City, Platform_No FROM STATION ORDER BY Station_Name');
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch stations' });
  }
});

// GET /api/search-trains?from=1&to=2 — find trains between two stations
router.get('/search-trains', async (req, res) => {
  const { from, to } = req.query;
  if (!from || !to) return res.status(400).json({ error: 'from and to station IDs required' });
  if (from === to) return res.status(400).json({ error: 'Source and destination cannot be same' });

  try {
    // Find trains that stop at both stations where source comes before destination
    const [trains] = await db.query(`
      SELECT
        t.Train_No, t.Train_Name, t.Train_Type, t.Capacity,
        src.Departure_Time AS departure_time,
        dst.Arrival_Time AS arrival_time,
        src.Stop_Order AS src_order,
        dst.Stop_Order AS dst_order,
        ss.Station_Name AS source_station,
        ds.Station_Name AS dest_station
      FROM TRAIN t
      JOIN TRAIN_STOPS_AT src ON t.Train_No = src.Train_No AND src.Station_ID = ?
      JOIN TRAIN_STOPS_AT dst ON t.Train_No = dst.Train_No AND dst.Station_ID = ?
      JOIN STATION ss ON src.Station_ID = ss.Station_ID
      JOIN STATION ds ON dst.Station_ID = ds.Station_ID
      WHERE src.Stop_Order < dst.Stop_Order
      ORDER BY src.Departure_Time
    `, [from, to]);

    // For each train, get seat availability per class
    const results = [];
    for (const train of trains) {
      const [seats] = await db.query(`
        SELECT
          cs.Class,
          COUNT(cs.Seat_ID) AS total_seats,
          COUNT(bs.Seat_ID) AS booked_seats
        FROM COACH_SEAT cs
        LEFT JOIN BOOKING_SEAT bs ON cs.Seat_ID = bs.Seat_ID
          AND bs.Booking_ID IN (
            SELECT b.Booking_ID FROM BOOKING b
            WHERE b.Status != 'Cancelled'
            AND b.Start_Station = ? AND b.End_Station = ?
          )
        WHERE cs.Train_No = ?
        GROUP BY cs.Class
        ORDER BY FIELD(cs.Class, '1AC', '2AC', '3AC', 'SL', 'GEN')
      `, [from, to, train.Train_No]);

      let classInfo = seats.map(s => ({
        class: s.Class,
        totalSeats: s.total_seats,
        bookedSeats: s.booked_seats,
        available: Math.max(0, s.total_seats - s.booked_seats),
        fare: FARES[s.Class] || 0
      }));

      // If a train has no pre-defined seats in COACH_SEAT, provide default bookable tiers
      if (classInfo.length === 0) {
        const defaultClasses = train.Train_Type === 'Rajdhani' 
          ? ['1AC', '2AC', '3AC']
          : train.Train_Type === 'Shatabdi'
          ? ['1AC', '2AC']
          : train.Train_Type === 'Semi-Highspeed'
          ? ['1AC', '2AC', 'GEN']
          : ['2AC', '3AC', 'SL', 'GEN'];

        classInfo = defaultClasses.map(cls => ({
          class: cls,
          totalSeats: 30,
          bookedSeats: 0,
          available: 30,
          fare: FARES[cls] || 250
        }));
      }

      // Get all stops for route visualization
      const [stops] = await db.query(`
        SELECT tsa.Stop_Order, s.Station_Name,
               tsa.Arrival_Time, tsa.Departure_Time
        FROM TRAIN_STOPS_AT tsa
        JOIN STATION s ON tsa.Station_ID = s.Station_ID
        WHERE tsa.Train_No = ?
        ORDER BY tsa.Stop_Order
      `, [train.Train_No]);

      results.push({
        trainNo: train.Train_No,
        trainName: train.Train_Name,
        trainType: train.Train_Type,
        capacity: train.Capacity,
        departureTime: train.departure_time,
        arrivalTime: train.arrival_time,
        sourceStation: train.source_station,
        destStation: train.dest_station,
        classes: classInfo,
        stops
      });
    }

    res.json(results);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to search trains' });
  }
});

// GET /api/train/:trainNo/seats?class=2AC — seat details
router.get('/train/:trainNo/seats', async (req, res) => {
  const { trainNo } = req.params;
  const classType = req.query.class;

  try {
    let query = `
      SELECT cs.Seat_ID, cs.Coach_No, cs.Seat_No, cs.Class,
             CASE WHEN bs.Seat_ID IS NOT NULL THEN 'Booked' ELSE 'Available' END AS status
      FROM COACH_SEAT cs
      LEFT JOIN BOOKING_SEAT bs ON cs.Seat_ID = bs.Seat_ID
        AND bs.Booking_ID IN (SELECT b.Booking_ID FROM BOOKING b WHERE b.Status != 'Cancelled')
      WHERE cs.Train_No = ?
    `;
    const params = [trainNo];

    if (classType) {
      query += ' AND cs.Class = ?';
      params.push(classType);
    }

    query += ' ORDER BY cs.Coach_No, cs.Seat_No';

    const [rows] = await db.query(query, params);
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch seats' });
  }
});

// GET /api/timetable/:stationId — all trains at a station
router.get('/timetable/:stationId', async (req, res) => {
  try {
    const [station] = await db.query('SELECT * FROM STATION WHERE Station_ID = ?', [req.params.stationId]);
    if (station.length === 0) return res.status(404).json({ error: 'Station not found' });

    const [trains] = await db.query(`
      SELECT
        t.Train_No, t.Train_Name, t.Train_Type,
        tsa.Stop_Order, tsa.Arrival_Time, tsa.Departure_Time,
        s.Platform_No,
        sc.Running_Date,
        (SELECT MIN(tsa2.Stop_Order) FROM TRAIN_STOPS_AT tsa2 WHERE tsa2.Train_No = t.Train_No) AS first_stop,
        (SELECT MAX(tsa2.Stop_Order) FROM TRAIN_STOPS_AT tsa2 WHERE tsa2.Train_No = t.Train_No) AS last_stop,
        (SELECT st2.Station_Name FROM TRAIN_STOPS_AT tsa2 JOIN STATION st2 ON tsa2.Station_ID = st2.Station_ID
         WHERE tsa2.Train_No = t.Train_No ORDER BY tsa2.Stop_Order ASC LIMIT 1) AS origin_station,
        (SELECT st2.Station_Name FROM TRAIN_STOPS_AT tsa2 JOIN STATION st2 ON tsa2.Station_ID = st2.Station_ID
         WHERE tsa2.Train_No = t.Train_No ORDER BY tsa2.Stop_Order DESC LIMIT 1) AS final_station
      FROM TRAIN_STOPS_AT tsa
      JOIN TRAIN t ON tsa.Train_No = t.Train_No
      JOIN STATION s ON tsa.Station_ID = s.Station_ID
      LEFT JOIN TIMETABLE_EVENT te ON te.Train_No = t.Train_No AND te.Station_ID = tsa.Station_ID
      LEFT JOIN SCHEDULE sc ON te.Schedule_ID = sc.Schedule_ID
      WHERE tsa.Station_ID = ?
      ORDER BY COALESCE(tsa.Departure_Time, tsa.Arrival_Time)
    `, [req.params.stationId]);

    const departures = trains.filter(t => t.Departure_Time !== null);
    const arrivals = trains.filter(t => t.Arrival_Time !== null);

    res.json({
      station: station[0],
      departures,
      arrivals,
      all: trains
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch timetable' });
  }
});

module.exports = router;
