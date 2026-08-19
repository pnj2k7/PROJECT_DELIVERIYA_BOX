/****************************************************
 * DELIVERIYA
 * IoT-Based Smart Cargo Consignment Unit
 *
 * FINAL VERSION
 *
 * Added:
 * - Reed door sensor on D0
 * - Servo lock at 0 degrees
 * - Servo unlock at 150 degrees
 * - Unauthorized door access detection
 * - Firebase alerts
 * - Physical door status from reed sensor
 * - Authorized door opening detection
 ****************************************************/


// ================= LIBRARIES =================

#include <ESP8266WiFi.h>

#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>

#include <DHT.h>

#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

#include <TinyGPS++.h>
#include <SoftwareSerial.h>

#include <Servo.h>


// ================= BOX ID =================

#define BOX_ID "YCAWZP"

String boxPath = "/boxes/" + String(BOX_ID);


// ================= THRESHOLDS =================

#define FAN_AUTO_THRESHOLD_C 35.0

#define HISTORY_LOG_INTERVAL_MS 60000

// Prevent repeated unauthorized alerts while
// the door remains physically open.
#define UNAUTHORIZED_ALERT_COOLDOWN_MS 10000


// ================= SERVO SETTINGS =================

#define SERVO_LOCKED_ANGLE 0
#define SERVO_UNLOCKED_ANGLE 150


// ================= WIFI =================

#define WIFI_SSID "Jk"
#define WIFI_PASSWORD "dm123456"


// ================= FIREBASE =================

#define API_KEY "AIzaSyB9ClgRHSEYR4yJjW9tHA0nFHoRlkL8Y9g"

#define DATABASE_URL "https://delivery-box-dc699-default-rtdb.asia-southeast1.firebasedatabase.app"


FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;


// ================= FIREBASE CONNECTION =================

void connectFirebase()
{
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  config.token_status_callback = tokenStatusCallback;

  Serial.println();
  Serial.println("Firebase Authentication...");

  if (Firebase.signUp(&config, &auth, "", ""))
  {
    Serial.println("Firebase Authentication OK");
  }
  else
  {
    Serial.print("Firebase Signup Error: ");
    Serial.println(config.signer.signupError.message.c_str());
  }

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  Serial.println("Firebase Ready");
}


// ================= WIFI CONNECTION =================

void connectWiFi()
{
  Serial.println();
  Serial.print("Connecting to WiFi");

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int counter = 0;

  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
    Serial.print(".");
    counter++;

    if (counter > 40)
    {
      Serial.println();
      Serial.println("WiFi Connection Failed");
      return;
    }
  }

  Serial.println();
  Serial.println("WiFi Connected");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
}


// ================= GLOBAL VARIABLES =================

float temperature = 0;
float humidity = 0;

float accelX = 0;
float accelY = 0;
float accelZ = 0;

double latitude = 0;
double longitude = 0;

bool fanState = false;
bool fanAutoActive = false;
bool lastFanAutoActive = false;

bool buzzerState = false;

// Firebase door command
// false = locked
// true  = unlocked
bool doorState = false;

// Servo position
int currentServoAngle = SERVO_LOCKED_ANGLE;


// ================= REED SENSOR =================

// D0 is now dedicated to the reed sensor.
#define REED_PIN D0

// Reed sensor state
bool reedDoorClosed = true;
bool lastReedDoorClosed = true;

// Used for detecting state changes
unsigned long lastReedChange = 0;

// Used to prevent repeated alerts
unsigned long lastUnauthorizedAlert = 0;


// ================= TIMERS =================

unsigned long lastUpdate = 0;
unsigned long lastHistoryLog = 0;


// ==================================================
// PIN CONFIGURATION
// ==================================================

#define DHT_PIN D4
#define DHT_TYPE DHT22

#define BUZZER_PIN D3
#define SERVO_PIN D5
#define RELAY_PIN D8

DHT dht(DHT_PIN, DHT_TYPE);

Adafruit_MPU6050 mpu;

Servo doorServo;

SoftwareSerial gpsSerial(D7, D6);

TinyGPSPlus gps;


// ==================================================
// ACTIVITY LOGGING
// ==================================================

void logActivity(String type)
{
  if (!Firebase.ready())
  {
    return;
  }

  FirebaseJson json;

  json.set("type", type);
  json.set("byUid", "device");
  json.set("timestamp/.sv", "timestamp");

  if (!Firebase.RTDB.pushJSON(
        &fbdo,
        boxPath + "/activity",
        &json))
  {
    Serial.print("Activity log failed: ");
    Serial.println(fbdo.errorReason());
  }
}


// ==================================================
// TEMPERATURE ACTIVITY LOG
// ==================================================

void logActivityWithTemp(String type, float tempValue)
{
  if (!Firebase.ready())
  {
    return;
  }

  FirebaseJson json;

  json.set("type", type);
  json.set("byUid", "device");
  json.set("temperature", tempValue);
  json.set("timestamp/.sv", "timestamp");

  Firebase.RTDB.pushJSON(
    &fbdo,
    boxPath + "/activity",
    &json
  );
}


// ==================================================
// UNAUTHORIZED DOOR ALERT
// ==================================================

void createUnauthorizedDoorAlert()
{
  if (!Firebase.ready())
  {
    Serial.println("Firebase not ready - cannot create alert");
    return;
  }

  unsigned long now = millis();

  // Prevent alert spam
  if (
    lastUnauthorizedAlert != 0 &&
    (now - lastUnauthorizedAlert) <
    UNAUTHORIZED_ALERT_COOLDOWN_MS
  )
  {
    return;
  }

  lastUnauthorizedAlert = now;

  Serial.println();
  Serial.println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
  Serial.println("!!! UNAUTHORIZED DOOR ACCESS !!!");
  Serial.println("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");

  // ================= ALERT =================

  FirebaseJson alert;

  alert.set(
    "type",
    "unauthorized_door_access"
  );

  alert.set(
    "title",
    "Unauthorized Door Access"
  );

  alert.set(
    "message",
    "The door was opened while the lock was engaged."
  );

  alert.set(
    "by",
    "device"
  );

  alert.set(
    "servoAngle",
    currentServoAngle
  );

  alert.set(
    "doorStatus",
    "Open"
  );

  alert.set(
    "acknowledged",
    false
  );

  alert.set(
    "timestamp/.sv",
    "timestamp"
  );


  // Save under /alerts
  if (
    Firebase.RTDB.pushJSON(
      &fbdo,
      boxPath + "/alerts",
      &alert
    )
  )
  {
    Serial.println("Firebase SECURITY ALERT SAVED");
  }
  else
  {
    Serial.print("Alert save failed: ");
    Serial.println(fbdo.errorReason());
  }


  // ================= ACTIVITY =================

  logActivity(
    "unauthorized_door_access"
  );
}


// ==================================================
// SENSOR HISTORY
// ==================================================

void pushSensorHistory()
{
  if (!Firebase.ready())
  {
    return;
  }

  FirebaseJson json;

  json.set("temperature", temperature);
  json.set("humidity", humidity);

  json.set("accelX", accelX);
  json.set("accelY", accelY);
  json.set("accelZ", accelZ);

  json.set("latitude", latitude);
  json.set("longitude", longitude);

  json.set("timestamp/.sv", "timestamp");

  Firebase.RTDB.pushJSON(
    &fbdo,
    boxPath + "/sensorHistory",
    &json
  );
}


// ==================================================
// REED SENSOR INITIALIZATION
// ==================================================

void initializeReedSensor()
{
  pinMode(REED_PIN, INPUT_PULLUP);

  delay(100);

  int state = digitalRead(REED_PIN);

  reedDoorClosed = (state == LOW);
  lastReedDoorClosed = reedDoorClosed;

  Serial.println();
  Serial.println("------ REED SENSOR ------");

  if (reedDoorClosed)
  {
    Serial.println("Initial Door: CLOSED");
  }
  else
  {
    Serial.println("Initial Door: OPEN");
  }
}


// ==================================================
// READ REED SENSOR
// ==================================================

void readReedSensor()
{
  int state = digitalRead(REED_PIN);

  bool currentDoorClosed = (state == LOW);

  // Detect physical door state change
  if (currentDoorClosed != lastReedDoorClosed)
  {
    lastReedChange = millis();

    // Small debounce period
    delay(30);

    state = digitalRead(REED_PIN);

    currentDoorClosed = (state == LOW);

    if (currentDoorClosed != lastReedDoorClosed)
    {
      lastReedDoorClosed = currentDoorClosed;

      reedDoorClosed = currentDoorClosed;

      Serial.println();
      Serial.println("------ DOOR SENSOR ------");

      if (reedDoorClosed)
      {
        Serial.println("Physical Door: CLOSED");
      }
      else
      {
        Serial.println("Physical Door: OPEN");
      }

      // ================= FIREBASE =================

      if (Firebase.ready())
      {
        Firebase.RTDB.setString(
          &fbdo,
          boxPath + "/sensors/doorStatus",
          reedDoorClosed ? "Closed" : "Open"
        );

        Firebase.RTDB.setBool(
          &fbdo,
          boxPath + "/sensors/reedStatus",
          reedDoorClosed
        );
      }

      // ==================================================
      // SECURITY CHECK
      // ==================================================

      // If door physically opens while servo is LOCKED,
      // this is unauthorized access.

      if (!reedDoorClosed)
      {
        if (currentServoAngle == SERVO_LOCKED_ANGLE)
        {
          Serial.println();
          Serial.println(
            "SECURITY: Door opened while LOCKED!"
          );

          createUnauthorizedDoorAlert();
        }
        else
        {
          Serial.println(
            "Door opened while AUTHORIZED UNLOCK is active."
          );

          logActivity(
            "authorized_door_opened"
          );
        }
      }
      else
      {
        Serial.println(
          "Door physically closed."
        );
      }
    }
  }
}


// ==================================================
// DHT22
// ==================================================

void readDHT()
{
  temperature = dht.readTemperature();
  humidity = dht.readHumidity();

  if (isnan(temperature) || isnan(humidity))
  {
    Serial.println("DHT22 Reading Failed");
    return;
  }

  Serial.println();
  Serial.println("------ DHT22 ------");

  Serial.print("Temperature: ");
  Serial.print(temperature);
  Serial.println(" C");

  Serial.print("Humidity: ");
  Serial.print(humidity);
  Serial.println(" %");
}


// ==================================================
// MPU6050
// ==================================================

void readMPU()
{
  sensors_event_t accel, gyro, temp;

  mpu.getEvent(
    &accel,
    &gyro,
    &temp
  );

  accelX = accel.acceleration.x;
  accelY = accel.acceleration.y;
  accelZ = accel.acceleration.z;

  Serial.println();
  Serial.println("------ MPU6050 ------");

  Serial.print("Accel X: ");
  Serial.println(accelX);

  Serial.print("Accel Y: ");
  Serial.println(accelY);

  Serial.print("Accel Z: ");
  Serial.println(accelZ);
}


// ==================================================
// GPS
// ==================================================

void readGPS()
{
  while (gpsSerial.available())
  {
    gps.encode(gpsSerial.read());
  }

  if (gps.location.isValid())
  {
    latitude = gps.location.lat();
    longitude = gps.location.lng();

    Serial.println();
    Serial.println("------ GPS ------");

    Serial.print("Latitude: ");
    Serial.println(latitude);

    Serial.print("Longitude: ");
    Serial.println(longitude);
  }
  else
  {
    Serial.println();
    Serial.println("GPS Searching...");
  }
}


// ==================================================
// FIREBASE SENSOR UPLOAD
// ==================================================

void uploadSensorData()
{
  if (!Firebase.ready())
  {
    Serial.println("Firebase Not Ready");
    return;
  }

  Serial.println();
  Serial.println("Uploading to Firebase...");

  Firebase.RTDB.setFloat(
    &fbdo,
    boxPath + "/sensors/temperature",
    temperature
  );

  Firebase.RTDB.setFloat(
    &fbdo,
    boxPath + "/sensors/humidity",
    humidity
  );

  Firebase.RTDB.setFloat(
    &fbdo,
    boxPath + "/sensors/accelerationX",
    accelX
  );

  Firebase.RTDB.setFloat(
    &fbdo,
    boxPath + "/sensors/accelerationY",
    accelY
  );

  Firebase.RTDB.setFloat(
    &fbdo,
    boxPath + "/sensors/accelerationZ",
    accelZ
  );

  Firebase.RTDB.setFloat(
    &fbdo,
    boxPath + "/location/latitude",
    latitude
  );

  Firebase.RTDB.setFloat(
    &fbdo,
    boxPath + "/location/longitude",
    longitude
  );

  Firebase.RTDB.setString(
    &fbdo,
    boxPath + "/device/status",
    "online"
  );

  Firebase.RTDB.setInt(
    &fbdo,
    boxPath + "/device/lastSeen",
    millis()
  );

  Serial.println("Firebase Upload Complete");
}


// ==================================================
// REMOTE CONTROL
// ==================================================

void readControls()
{
  if (!Firebase.ready())
  {
    Serial.println(
      "Firebase Not Ready For Control"
    );

    return;
  }


  // ==================================================
  // FAN CONTROL
  // ==================================================

  if (
    Firebase.RTDB.getBool(
      &fbdo,
      boxPath + "/control/fan"
    )
  )
  {
    fanState = fbdo.boolData();
  }

  fanAutoActive =
    (temperature >= FAN_AUTO_THRESHOLD_C);

  bool effectiveFan =
    fanState || fanAutoActive;

  digitalWrite(
    RELAY_PIN,
    effectiveFan ? HIGH : LOW
  );

  Firebase.RTDB.setBool(
    &fbdo,
    boxPath + "/control/fanAuto",
    fanAutoActive
  );

  if (
    fanAutoActive &&
    !lastFanAutoActive
  )
  {
    logActivityWithTemp(
      "fan_auto_on",
      temperature
    );

    Serial.println(
      "AUTO FAN ON — high temperature"
    );
  }

  if (
    !fanAutoActive &&
    lastFanAutoActive
  )
  {
    logActivityWithTemp(
      "fan_auto_off",
      temperature
    );

    Serial.println(
      "AUTO FAN OFF — temperature normal"
    );
  }

  lastFanAutoActive =
    fanAutoActive;


  // ==================================================
  // BUZZER
  // ==================================================

  if (
    Firebase.RTDB.getBool(
      &fbdo,
      boxPath + "/control/buzzer"
    )
  )
  {
    buzzerState =
      fbdo.boolData();

    digitalWrite(
      BUZZER_PIN,
      buzzerState ? HIGH : LOW
    );
  }


  // ==================================================
  // SERVO DOOR CONTROL
  // ==================================================

  if (
    Firebase.RTDB.getBool(
      &fbdo,
      boxPath + "/control/door"
    )
  )
  {
    bool requestedDoorState =
      fbdo.boolData();

    // Only move servo if command actually changed.
    if (
      requestedDoorState != doorState
    )
    {
      doorState =
        requestedDoorState;

      Serial.println();
      Serial.println("------ DOOR COMMAND ------");

      if (doorState)
      {
        // ================= UNLOCK =================

        currentServoAngle =
          SERVO_UNLOCKED_ANGLE;

        doorServo.write(
          SERVO_UNLOCKED_ANGLE
        );

        Serial.print(
          "Servo moved to UNLOCK: "
        );

        Serial.print(
          SERVO_UNLOCKED_ANGLE
        );

        Serial.println(" degrees");

        Firebase.RTDB.setString(
          &fbdo,
          boxPath + "/sensors/lockStatus",
          "Unlocked"
        );

        logActivity(
          "door_unlocked"
        );
      }
      else
      {
        // ================= LOCK =================

        currentServoAngle =
          SERVO_LOCKED_ANGLE;

        doorServo.write(
          SERVO_LOCKED_ANGLE
        );

        Serial.print(
          "Servo moved to LOCK: "
        );

        Serial.print(
          SERVO_LOCKED_ANGLE
        );

        Serial.println(" degrees");

        Firebase.RTDB.setString(
          &fbdo,
          boxPath + "/sensors/lockStatus",
          "Locked"
        );

        // If the physical door is still open when
        // we lock the servo, immediately create alert.
        if (!reedDoorClosed)
        {
          Serial.println();
          Serial.println(
            "WARNING: Lock command received "
            "while physical door is OPEN!"
          );

          createUnauthorizedDoorAlert();
        }
        else
        {
          logActivity(
            "door_locked"
          );
        }
      }
    }
  }
}


// ==================================================
// SETUP
// ==================================================

void setup()
{
  Serial.begin(115200);

  Serial.println();
  Serial.println("================================");
  Serial.println("DELIVERIYA STARTING");
  Serial.print("Box ID: ");
  Serial.println(BOX_ID);
  Serial.println("================================");


  // GPS
  gpsSerial.begin(9600);


  // Outputs
  pinMode(
    RELAY_PIN,
    OUTPUT
  );

  pinMode(
    BUZZER_PIN,
    OUTPUT
  );

  digitalWrite(
    RELAY_PIN,
    LOW
  );

  digitalWrite(
    BUZZER_PIN,
    LOW
  );


  // Reed sensor
  initializeReedSensor();


  // Servo
  doorServo.attach(
    SERVO_PIN
  );

  delay(500);

  currentServoAngle =
    SERVO_LOCKED_ANGLE;

  doorState = false;

  doorServo.write(
    SERVO_LOCKED_ANGLE
  );

  delay(1000);


  // DHT
  dht.begin();


  // MPU6050
  Wire.begin(
    D2,
    D1
  );

  if (!mpu.begin())
  {
    Serial.println(
      "MPU6050 NOT FOUND"
    );

    while (1)
    {
      delay(100);
    }
  }

  Serial.println(
    "MPU6050 Connected"
  );


  // WiFi
  connectWiFi();


  // Firebase
  connectFirebase();


  // Initial Firebase state
  if (Firebase.ready())
  {
    Firebase.RTDB.setString(
      &fbdo,
      boxPath + "/device/status",
      "online"
    );

    Firebase.RTDB.setString(
      &fbdo,
      boxPath + "/sensors/doorStatus",
      reedDoorClosed
        ? "Closed"
        : "Open"
    );

    Firebase.RTDB.setBool(
      &fbdo,
      boxPath + "/sensors/reedStatus",
      reedDoorClosed
    );

    Firebase.RTDB.setString(
      &fbdo,
      boxPath + "/sensors/lockStatus",
      "Locked"
    );
  }


  Serial.println();
  Serial.println("================================");
  Serial.println("DELIVERIYA READY");
  Serial.println("================================");

  Serial.println();
  Serial.println(
    "SERVO LOCK  : 0 degrees"
  );

  Serial.println(
    "SERVO UNLOCK: 150 degrees"
  );

  Serial.println(
    "REED SENSOR : D0"
  );

  Serial.println();
}


// ==================================================
// MAIN LOOP
// ==================================================

void loop()
{
  unsigned long currentMillis =
    millis();


  // ==================================================
  // REED SENSOR
  // ==================================================

  // Check continuously.
  readReedSensor();


  // ==================================================
  // NORMAL SENSOR UPDATE
  // ==================================================

  if (
    currentMillis - lastUpdate >= 2000
  )
  {
    lastUpdate =
      currentMillis;

    Serial.println();
    Serial.println("==============================");
    Serial.println("DELIVERIYA UPDATE");
    Serial.println("==============================");


    readDHT();

    readMPU();

    readGPS();

    uploadSensorData();

    readControls();


    Serial.println("==============================");
  }


  // ==================================================
  // HISTORY
  // ==================================================

  if (
    currentMillis - lastHistoryLog >=
    HISTORY_LOG_INTERVAL_MS
  )
  {
    lastHistoryLog =
      currentMillis;

    pushSensorHistory();

    Serial.println(
      "Sensor history snapshot logged"
    );
  }
}
