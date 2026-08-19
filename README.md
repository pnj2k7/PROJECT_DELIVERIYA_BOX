# DELIVERIYA 📦🌐

## IoT-Based Smart Cargo Consignment Monitoring and Access-Control System

**Real-Time Mobile Application Integration**

DELIVERIYA is an IoT-based smart cargo consignment system designed to provide real-time visibility, environmental monitoring, location tracking and role-restricted remote access to a physical delivery box.

The prototype combines an **ESP8266-based embedded device**, **Firebase Realtime Database / Authentication**, and a **cross-platform Flutter application** for Sender and Customer users.

> **Academic Project** — H M A P N L JAYAWICKRAMA  
> **NIBM - COLOMBO 07**  
> **Programme / Module:** HNDNE25.2F  
> **Student ID:** COHNDNE252F - 002  
> **Lecturer:** MR. SUPUN ASANGA

---

## ✨ Key Features

- 🌡️ Real-time temperature and humidity monitoring
- 📐 Motion / shock monitoring using MPU6050
- 📍 Live GPS location tracking
- 🚪 Remote electronic door-lock control
- 🌬️ Manual cooling-fan control
- 🔥 Automatic fan activation when temperature reaches **35°C**
- 🔐 Sender / Customer role-based access
- 🚨 Sender emergency-access function
- 📜 Timestamped, role-attributed activity history
- 📦 Box creation and Customer claiming
- ✅ Delivery confirmation
- 📞 Direct contact between Sender and Customer
- 📱 Flutter application for Android, iOS and Web
- ☁️ Firebase real-time cloud backend

---

## 🏗️ System Architecture

```text
                 ┌──────────────────────────┐
                 │    DELIVERIYA BOX        │
                 │       ESP8266            │
                 └────────────┬─────────────┘
                              │
              ┌───────────────┼────────────────┐
              │               │                │
           DHT22           MPU6050           GPS
        Temp / Humidity   Motion / Shock    Location
              │               │                │
              └───────────────┼────────────────┘
                              │
                              ▼
                 ┌──────────────────────────┐
                 │ Firebase Realtime DB     │
                 │ + Firebase Auth         │
                 └────────────┬─────────────┘
                              │
                 ┌────────────┴────────────┐
                 ▼                         ▼
          ┌──────────────┐          ┌──────────────┐
          │    Sender    │          │   Customer   │
          │ Flutter App  │          │ Flutter App  │
          └──────────────┘          └──────────────┘
```

For the detailed architecture, see [`docs/architecture.md`](docs/architecture.md).

---

## 🔧 Hardware

The prototype uses:

| Component | Purpose |
|---|---|
| ESP8266 NodeMCU | Main controller + Wi-Fi |
| DHT22 | Temperature / humidity |
| MPU6050 | Motion / acceleration |
| GPS receiver | Location tracking |
| SG90 servo | Door-lock actuator |
| Relay module | Fan switching |
| 12V DC fan | Cooling |
| Active buzzer | Reserved for future alerting |
| Status LED | Connectivity / device status |

See [`hardware/components.md`](hardware/components.md) for the GPIO mapping.

---

## 👥 User Roles

### Sender

The Sender can:

- Create a consignment box
- Generate Box ID / Box Password
- Monitor live sensor data
- View GPS location
- View activity history
- Trigger emergency door access
- View Customer contact information
- Receive delivery confirmation

### Customer

The Customer can:

- Claim a box using Box ID and Box Password
- Monitor live sensor data
- View GPS location
- Lock / unlock the door
- Control the cooling fan
- View activity history
- Confirm delivery
- Contact the Sender

---

## 🌡️ Automatic Safety Behaviour

The firmware includes an automatic temperature safety mechanism.

```text
Temperature >= 35°C
        ↓
Automatic fan activated
        ↓
Activity event recorded
        ↓
Firebase updated
        ↓
Flutter clients receive updated state
```

The automatic behaviour operates independently of the Customer's manual fan setting.

---

## ☁️ Firebase Data Model

Each consignment is represented under:

```text
boxes/{boxId}/
```

with logical sections for:

```text
meta
sensors
control
device
location
sender
customer
activity
sensorHistory
```

See [`firebase/database-schema.example.json`](firebase/database-schema.example.json).

---

## 📱 Flutter Application

The Flutter application contains services and role-specific screens for authentication, box management, Firebase communication, monitoring, location, controls, history and settings.

### Main services

- `AuthService` — authentication
- `BoxService` — consignment / box management
- `FirebaseService` — real-time sensor and control I/O
- `AppSession` — current role and active Box ID

The application uses Firebase streams for real-time updates.

---

## 📁 Repository Structure

```text
DELIVERIYA/
│
├── README.md
├── LICENSE
├── .gitignore
│
├── firmware/
│   ├── final/
│   │   └── DELIVERIYA.ino
│   └── testing/
│       ├── sketch_BUZZER/
│       ├── sketch_DHT22/
│       ├── sketch_GPS/
│       ├── sketch_LED/
│       ├── sketch_esp12e-blink/
│       ├── sketch_fan_relay/
│       ├── sketch_gps2/
│       ├── sketch_mpu6050/
│       └── sketch_servo/
│
├── flutter_app/
│
├── firebase/
│   ├── README.md
│   └── database-schema.example.json
│
├── hardware/
│   ├── README.md
│   ├── components.md
│   └── images/
│
├── docs/
│   ├── architecture.md
│   ├── project-overview.md
│   └── DELIVERIYA_Project_Report.docx
│
└── assets/
```

---

## 🚀 Getting Started

### 1. Clone the repository

```bash
git clone <YOUR_GITHUB_REPOSITORY_URL>
cd DELIVERIYA
```

### 2. Flutter application

Install Flutter and verify the environment:

```bash
flutter doctor
```

Then:

```bash
cd flutter_app
flutter pub get
flutter run
```

Configure your own Firebase project before running the application in a new environment.

### 3. ESP8266 firmware

Open:

```text
firmware/final/DELIVERIYA.ino
```

Install the required Arduino libraries for the ESP8266, DHT22, MPU6050, GPS and Firebase client.

Before flashing, configure:

```cpp
#define BOX_ID "YOUR_BOX_ID"
#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"
#define API_KEY "YOUR_FIREBASE_API_KEY"
#define DATABASE_URL "YOUR_FIREBASE_DATABASE_URL"
```

**Never commit your real Wi-Fi password or other private credentials.**

---

## 🧪 Testing

The project includes individual hardware testing sketches under `firmware/testing/` for the main components.

The project report records functional tests covering registration, box creation, Customer claiming, incorrect credentials, servo control, automatic fan activation, emergency access, delivery confirmation, calling, GPS and activity history.

The reported functional tests passed, with direct in-app calling noted as unavailable on desktop web browsers because the browser does not provide the same native dialing behaviour.

---

## ⚠️ Current Limitations

The prototype currently has several known limitations:

- No dedicated tamper-detection hardware
- No battery/power telemetry
- ESP8266 requires Internet-connected Wi-Fi
- No background push notifications while the application is fully closed
- Multiple physical devices were not simultaneously validated
- Adverse network conditions were not systematically characterised

These are documented as future development areas rather than hidden limitations.

---

## 🔮 Future Development

Potential next steps include:

1. Dedicated magnetic tamper detection
2. Battery and power telemetry
3. Background push notifications using Firebase Cloud Messaging / Cloud Functions
4. Cellular or LPWAN connectivity
5. Public Android / iOS distribution
6. Multi-device fleet management

---

## 📄 Documentation

- [Project Overview](docs/project-overview.md)
- [System Architecture](docs/architecture.md)
- [Hardware Components](hardware/components.md)
- [Firebase Documentation](firebase/README.md)
- [Project Report](docs/DELIVERIYA_Project_Report.docx)

---

## 🎓 Academic Information

**Project:** DELIVERIYA — An IoT-Based Smart Cargo Consignment Monitoring and Access-Control System with Real-Time Mobile Application Integration

**Institution:** NIBM - COLOMBO 07  
**Student:** H M A P N L JAYAWICKRAMA  
**Student ID:** COHNDNE252F - 002  
**Module:** HNDNE25.2F  
**Lecturer:** MR. SUPUN ASANGA

---

## 📜 License

This repository is intended primarily as an academic project and portfolio submission. See [`LICENSE`](LICENSE).

---

## 🔒 Security Notice

This repository is prepared without the original Wi-Fi passwords and other private configuration values found in the development archive.

If credentials have previously been committed to any public repository, rotate/revoke them and replace them with new credentials before deployment.
