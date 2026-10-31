# Train Management System — Project Context

## Overview
A full-stack web application for managing train bookings, station timetables, and employee operations. Built on top of an existing MySQL database schema with 14 relational tables.

**Tech Stack:** Node.js + Express + EJS + MySQL2  
**Server Port:** 9295 (with nodemon for hot-reload)  
**Design Inspiration:** RedBus app

---

## Database Schema Summary

| Table | Description |
|---|---|
| `TRAIN` | 10 trains (Rajdhani, Shatabdi, Superfast, Mail, Duronto, Express, Semi-Highspeed) |
| `STATION` | 12 stations across India (Delhi, Mumbai, Kolkata, Chennai, Bangalore, etc.) |
| `SCHEDULE` | 12 schedule entries with arrival/departure times and running dates |
| `TRAIN_STOPS_AT` | Route stops with sequence order (N:M junction table) |
| `TIMETABLE_EVENT` | Aggregation linking Train + Station + Schedule (13 events) |
| `EMPLOYEE` | 12 employees across 3 roles |
| `DRIVER` | ISA subtype — 5 drivers with license numbers |
| `TC` | ISA subtype — 5 ticket collectors with badges and zones |
| `MAINTENANCE_STAFF` | ISA subtype — 2 staff with shift types and trade skills |
| `COACH_SEAT` | Seat inventory per train with coach and class info |
| `PASSENGER` | 10 registered passengers |
| `BOOKING` | 10 bookings with status (Confirmed/Waiting/Cancelled) |
| `BOOKING_SEAT` | Junction table linking bookings to seats |
| `PAYMENT` | 1:1 with Booking — **Stores the Journey Fare** (`Amount`) & payment records |

### Train Routes in Database
- **Mumbai Rajdhani (12951):** Delhi → Jaipur → Mumbai Central
- **Howrah Rajdhani (12301):** Delhi → Howrah Junction
- **Karnataka Express (12627):** Delhi → Agra → Bangalore
- **Gatimaan Express (12049):** Delhi → Agra

### Where is Journey Fare Stored?
In the relational database schema, the fare for each journey is recorded in the **`PAYMENT`** entity:
- **`PAYMENT.Amount` (`DECIMAL(10,2)`)**: Holds the exact journey fare charged for that specific booking.
- **`PAYMENT.Booking_ID`**: Maintains a 1:1 foreign key relationship with the `BOOKING` entity.
- **`PAYMENT.Payment_Status`**: Records `Completed`, `Pending`, or `Refunded`.
- **`PAYMENT.Payment_Date`**: Date the transaction was processed.
- The journey fare is calculated based on the travel tier (`BOOKING.Class`):

| Class | Fare (₹) | Description |
|---|---|---|
| 1AC | 4,500 | First AC Sleeper |
| 2AC | 2,800 | 2-Tier AC Sleeper |
| 3AC | 1,800 | 3-Tier AC Sleeper |
| SL | 750 | Sleeper Class |
| GEN | 250 | General Unreserved |

### Payment Options Available in UI
When booking tickets in the interface (inspired by Redbus & IRCTC), passengers can choose from:
1. ⚡ **UPI (Instant)**: Google Pay, PhonePe, Paytm, BHIM with UPI ID/VPA
2. 💳 **Credit / Debit Cards**: Visa, MasterCard, RuPay (Card Number, Expiry, CVV, Name)
3. 🏦 **Net Banking**: Major Indian banks (SBI, HDFC, ICICI, Axis, PNB, Kotak, BOB)
4. 👛 **Digital Wallets**: Amazon Pay, Paytm Wallet, Mobikwik
5. 💵 **Pay at Station Counter**: Generates a confirmed booking in 'Pending' payment status to pay cash at the reservation counter.

---

## Employee Breakdown (3 Types, 3 Different Dashboards)

### 🚂 Drivers (Blue-themed Dashboard)
| ID | Name | License | Assigned Event |
|---|---|---|---|
| 1 | Rajesh Kumar | DL-2020-RLY-001 | Mumbai Rajdhani @ Delhi |
| 2 | Sunil Sharma | DL-2019-RLY-045 | Howrah Rajdhani @ Delhi |
| 3 | Amit Patel | DL-2021-RLY-112 | Bhopal Shatabdi @ Delhi |
| 4 | Vikram Singh | DL-2018-RLY-078 | Karnataka Express @ Delhi |
| 9 | Pradeep Joshi | DL-2022-RLY-203 | Chennai Mail @ Delhi |

### 🎫 Ticket Collectors (Green-themed Dashboard)
| ID | Name | Badge | Zone | Assigned Event |
|---|---|---|---|---|
| 5 | Deepak Verma | TC-MUM-0501 | Western | Mumbai Rajdhani @ Delhi |
| 6 | Manoj Tiwari | TC-HWH-0602 | Eastern | Howrah Rajdhani @ Delhi |
| 7 | Ravi Mishra | TC-BPL-0703 | West Central | Bhopal Shatabdi @ Delhi |
| 8 | Sanjay Gupta | TC-BNG-0804 | South Western | Karnataka Express @ Delhi |
| 10 | Ankit Chauhan | TC-CHN-1005 | Southern | Chennai Mail @ Delhi |

### 🔧 Maintenance Staff (Amber-themed Dashboard)
| ID | Name | Shift | Trade | Assigned Event |
|---|---|---|---|---|
| 11 | Ramesh Yadav | Night | Electrical | Mumbai Rajdhani @ Mumbai |
| 12 | Suresh Pandey | Rotational | Mechanical | Howrah Rajdhani @ Howrah |

---

## Application Structure

```
backend+frontend/
├── .env                          # Database & port configuration
├── package.json                  # Dependencies & scripts
├── server.js                     # Express server entry point
├── db.js                         # MySQL2 connection pool
├── routes/
│   ├── trainRoutes.js            # /api/stations, /api/search-trains, /api/timetable
│   ├── employeeRoutes.js         # /api/employees, /api/employee/driver|tc|maintenance/:id
│   └── bookingRoutes.js          # POST /api/book
├── public/
│   └── css/
│       └── style.css             # Full design system (RedBus-inspired)
└── views/
    ├── user.ejs                  # Passenger booking interface
    ├── timetable.ejs             # Station timetable board
    ├── employee.ejs              # Employee login portal
    ├── driver.ejs                # Driver dashboard (blue theme)
    ├── tc.ejs                    # TC dashboard (green theme)
    └── maintenance.ejs           # Maintenance dashboard (amber theme)
```

---

## API Endpoints

### Train & Station APIs
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/stations` | List all 12 stations |
| GET | `/api/search-trains?from=X&to=Y` | Find trains between stations with fares & availability |
| GET | `/api/train/:trainNo/seats?class=X` | Seat details for a train |
| GET | `/api/timetable/:stationId` | All arrivals/departures at a station |

### Booking & Admin APIs
| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/book` | Create booking (auto-creates passenger, assigns seat, processes payment) |
| POST | `/api/admin/verify` | Authenticates administrator using SQL `SHA2(?, 256)` function |
| GET | `/api/all-bookings` | Fetch live database records (Protected: requires Administrator access; supports SQL passenger search via `?search=name`) |
| GET | `/api/admin/search-passenger` | Dedicated SQL search query for passengers by name with total booking counts (`?name=keyword`) |
| DELETE | `/api/admin/booking/:id` | Deletes a specific booking (and removes the passenger from `PASSENGER` if they have no other bookings) |
| DELETE | `/api/admin/bookings/all` | Deletes all bookings and clears all passenger records from `PASSENGER` |
| POST | `/api/admin/demo-data` | Restores the 10 demo passengers, bookings & payments from `InsertionOFdata.sql` |

### Employee APIs
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/employees` | List all employees with roles |
| GET | `/api/employee/driver/:id` | Driver details + route stops |
| GET | `/api/employee/tc/:id` | TC details + passenger manifest |
| GET | `/api/employee/maintenance/:id` | Maintenance details |

---

## Page Routes

| URL | Page | Description |
|---|---|---|
| `/` | Redirect → `/user` | Home redirect |
| `/user` | Booking Page | Search trains, view fares, select payment & book tickets |
| `/timetable` | Timetable | Station departure/arrival board with live clock |
| `/bookings` | Live Database | **Administrator Only** monitor protected by password (`1234`) & SQL `SHA2` |
| `/employee` | Employee Portal | Role selection + login |
| `/employee/driver/:id` | Driver Dashboard | Blue theme, route map, assignment |
| `/employee/tc/:id` | TC Dashboard | Green theme, passenger list, ticket verification |
| `/employee/maintenance/:id` | Maintenance Dashboard | Amber theme, checklist, shift schedule |

---

## How to Run

```bash
cd backend+frontend
npm install
npm run dev    # starts with nodemon on port 9295
```

Then open: **http://localhost:9295**

> **Prerequisites:** MySQL server running with the `TrainManagementSystem` database created and populated using `CreateDatabase.sql` and `InsertionOFdata.sql`.

---

## Feature Highlights

### 1. User Booking Interface (RedBus-inspired)
- Station-to-station search with swap button
- Train cards with departure/arrival times, route visualization
- Class-wise fare display (1AC to GEN) with seat availability color-coding
- Booking modal with passenger form and animated confirmation
- Filter trains by type (Rajdhani, Shatabdi, etc.)

### 2. Station Timetable
- Railway-station-style dark board with live clock
- Departures and Arrivals tabs
- Blinking "On Time" indicators, platform badges
- Auto-refreshes every 30 seconds

### 3. Employee Dashboards (3 distinct interfaces)
- **Driver:** Dark blue theme, license info, route map visualization, duty stats
- **Ticket Collector:** Dark green theme, badge/zone, live passenger manifest table, PNR verification tool
- **Maintenance:** Dark amber theme, trade-specific checklists with progress bar, weekly shift grid
