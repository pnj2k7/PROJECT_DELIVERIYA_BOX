/****************************************************
 * DELIVERIYA (formerly SMARTPETTI)
 * IoT-Based Smart Cargo Consignment Unit
 *
 * Adds: automatic fan activation on high temperature,
 * with device-side activity logging for the History feed.
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
// Set this to the exact Box ID shown when the sender generated
// this box in the app. Every physical unit needs its own BOX_ID.

#define BOX_ID "PUT_YOUR_BOX_ID_HERE"

String boxPath = "/boxes/" + String(BOX_ID);



// ================= AUTO-FAN THRESHOLD =================
// If temperature reaches this value (Celsius), the fan turns on
// automatically regardless of the manual app control.

#define FAN_AUTO_THRESHOLD_C 35.0



// ================= WIFI =================

#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"



// ================= FIREBASE =================

#define API_KEY "YOUR_FIREBASE_API_KEY"

#define DATABASE_URL "YOUR_FIREBASE_DATABASE_URL"



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

bool fanState = false;     // manual command from app
bool fanAutoActive = false; // true when temperature triggered it
bool lastFanAutoActive = false;

bool buzzerState = false;  // reserved — not wired to logic yet
bool doorState = false;

unsigned long lastUpdate = 0;


/****************************************************
 * PIN CONFIGURATION + HARDWARE OBJECTS + SETUP
 ****************************************************/

#define DHT_PIN D4
#define DHT_TYPE DHT22

#define BUZZER_PIN D3
#define SERVO_PIN D5
#define RELAY_PIN D8
#define LED_PIN D0

DHT dht(DHT_PIN, DHT_TYPE);
Adafruit_MPU6050 mpu;
Servo doorServo;

// GPS TX -> ESP8266 D7 (RX) / GPS RX -> ESP8266 D6 (TX)
SoftwareSerial gpsSerial(D7, D6);
TinyGPSPlus gps;



// ================= ACTIVITY LOGGING =================
// Pushes a timestamped event to /boxes/{BOX_ID}/activity so the
// app's History screen shows it live.

void logActivity(String type)
{
  FirebaseJson json;
  json.set("type", type);
  json.set("byUid", "device");
  json.set("timestamp/.sv", "timestamp");

  Firebase.RTDB.pushJSON(&fbdo, boxPath + "/activity", &json);
}



// ================= SETUP =================

void setup()
{
  Serial.begin(115200);

  Serial.println();
  Serial.println("================================");
  Serial.println("DELIVERIYA STARTING");
  Serial.print("Box ID: ");
  Serial.println(BOX_ID);
  Serial.println("================================");

  gpsSerial.begin(9600);

  pinMode(RELAY_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);

  // Relay OFF (active-HIGH relay module — LOW keeps it off at boot)
  digitalWrite(RELAY_PIN, LOW);
  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(LED_PIN, HIGH);

  doorServo.attach(SERVO_PIN);
  delay(500);
  doorServo.write(0);
  delay(1000);

  dht.begin();

  Wire.begin(D2, D1);

  if (!mpu.begin())
  {
    Serial.println("MPU6050 NOT FOUND");
    while (1) { delay(100); }
  }

  Serial.println("MPU6050 Connected");

  connectWiFi();
  connectFirebase();

  if (Firebase.ready())
  {
    Firebase.RTDB.setString(&fbdo, boxPath + "/device/status", "online");
    Firebase.RTDB.setString(&fbdo, boxPath + "/sensors/doorStatus", "Closed");
  }

  Serial.println();
  Serial.println("================================");
  Serial.println("DELIVERIYA READY");
  Serial.println("================================");
}

/****************************************************
 * SENSOR READING FUNCTIONS
 ****************************************************/

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


void readMPU()
{
  sensors_event_t accel, gyro, temp;
  mpu.getEvent(&accel, &gyro, &temp);

  accelX = accel.acceleration.x;
  accelY = accel.acceleration.y;
  accelZ = accel.acceleration.z;

  Serial.println();
  Serial.println("------ MPU6050 ------");
  Serial.print("Accel X: "); Serial.println(accelX);
  Serial.print("Accel Y: "); Serial.println(accelY);
  Serial.print("Accel Z: "); Serial.println(accelZ);
}


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
    Serial.print("Latitude: "); Serial.println(latitude);
    Serial.print("Longitude: "); Serial.println(longitude);
  }
  else
  {
    Serial.println();
    Serial.println("GPS Searching...");
  }
}

/****************************************************
 * FIREBASE SENSOR UPLOAD
 ****************************************************/

void uploadSensorData()
{
  if (!Firebase.ready())
  {
    Serial.println("Firebase Not Ready");
    return;
  }

  Serial.println();
  Serial.println("Uploading to Firebase...");

  Firebase.RTDB.setFloat(&fbdo, boxPath + "/sensors/temperature", temperature);
  Firebase.RTDB.setFloat(&fbdo, boxPath + "/sensors/humidity", humidity);
  Firebase.RTDB.setFloat(&fbdo, boxPath + "/sensors/accelerationX", accelX);
  Firebase.RTDB.setFloat(&fbdo, boxPath + "/sensors/accelerationY", accelY);
  Firebase.RTDB.setFloat(&fbdo, boxPath + "/sensors/accelerationZ", accelZ);
  Firebase.RTDB.setFloat(&fbdo, boxPath + "/location/latitude", latitude);
  Firebase.RTDB.setFloat(&fbdo, boxPath + "/location/longitude", longitude);
  Firebase.RTDB.setString(&fbdo, boxPath + "/device/status", "online");
  Firebase.RTDB.setInt(&fbdo, boxPath + "/device/lastSeen", millis());

  Serial.println("Firebase Upload Complete");
}

/****************************************************
 * REMOTE CONTROL FUNCTIONS
 ****************************************************/

void readControls()
{
  if (!Firebase.ready())
  {
    Serial.println("Firebase Not Ready For Control");
    return;
  }

  // ================= FAN CONTROL (manual + auto) =================

  if (Firebase.RTDB.getBool(&fbdo, boxPath + "/control/fan"))
  {
    fanState = fbdo.boolData();
  }

  // Auto-trigger: temperature crosses the danger threshold
  fanAutoActive = (temperature >= FAN_AUTO_THRESHOLD_C);

  bool effectiveFan = fanState || fanAutoActive;

  /*
    This relay module is ACTIVE-HIGH:
    HIGH = Relay ON
    LOW  = Relay OFF
  */
  digitalWrite(RELAY_PIN, effectiveFan ? HIGH : LOW);

  Firebase.RTDB.setBool(&fbdo, boxPath + "/control/fanAuto", fanAutoActive);

  // Only log a transition, not every loop iteration
  if (fanAutoActive && !lastFanAutoActive)
  {
    logActivity("fan_auto_on");
    Serial.println("AUTO FAN ON — high temperature");
  }
  if (!fanAutoActive && lastFanAutoActive)
  {
    logActivity("fan_auto_off");
    Serial.println("AUTO FAN OFF — temperature normal");
  }
  lastFanAutoActive = fanAutoActive;


  // ================= BUZZER =================
  // Reserved for tamper detection — not driven by any logic yet.

  if (Firebase.RTDB.getBool(&fbdo, boxPath + "/control/buzzer"))
  {
    buzzerState = fbdo.boolData();
    digitalWrite(BUZZER_PIN, buzzerState ? HIGH : LOW);
  }


  // ================= SERVO DOOR CONTROL =================

  if (Firebase.RTDB.getBool(&fbdo, boxPath + "/control/door"))
  {
    doorState = fbdo.boolData();

    Serial.print("Door Command: ");
    Serial.println(doorState ? "OPEN" : "CLOSE");

    if (doorState)
    {
      doorServo.write(180);
      delay(500);
      Firebase.RTDB.setString(&fbdo, boxPath + "/sensors/doorStatus", "Open");
      Serial.println("Door OPEN");
    }
    else
    {
      doorServo.write(0);
      delay(500);
      Firebase.RTDB.setString(&fbdo, boxPath + "/sensors/doorStatus", "Closed");
      Serial.println("Door CLOSED");
    }
  }
  else
  {
    Serial.print("Door Read Error: ");
    Serial.println(fbdo.errorReason());
  }
}

/****************************************************
 * LED STATUS + MAIN LOOP
 ****************************************************/

void updateLED()
{
  if (WiFi.status() == WL_CONNECTED && Firebase.ready())
  {
    digitalWrite(LED_PIN, LOW);
  }
  else
  {
    digitalWrite(LED_PIN, HIGH);
  }
}


void loop()
{
  unsigned long currentMillis = millis();

  if (currentMillis - lastUpdate >= 2000)
  {
    lastUpdate = currentMillis;

    Serial.println();
    Serial.println("==============================");
    Serial.println("DELIVERIYA UPDATE");
    Serial.println("==============================");

    readDHT();
    readMPU();
    readGPS();

    uploadSensorData();
    readControls();
    updateLED();

    Serial.println("==============================");
  }
}
