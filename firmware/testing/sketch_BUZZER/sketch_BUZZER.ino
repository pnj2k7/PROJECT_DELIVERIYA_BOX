/****************************************************
 * SMARTPETTI
 * IoT-Based Smart Delivery Box
 *
 * FINAL CORRECTED CODE
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


// ================= WIFI =================

#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"


// ================= FIREBASE =================

#define API_KEY "YOUR_FIREBASE_API_KEY"

#define DATABASE_URL "YOUR_FIREBASE_DATABASE_URL"


// Firebase objects

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

// Sensor values

float temperature = 0;
float humidity = 0;


// MPU6050 values

float accelX = 0;
float accelY = 0;
float accelZ = 0;


// GPS values

double latitude = 0;
double longitude = 0;


// Control states

bool fanState = false;
bool buzzerState = false;
bool doorState = false;


// Timer

unsigned long lastUpdate = 0;


// ====================================================
// PIN CONFIGURATION
// ====================================================

// DHT22

#define DHT_PIN D4
#define DHT_TYPE DHT22


// Outputs

#define BUZZER_PIN D3
#define SERVO_PIN D5
#define RELAY_PIN D8
#define LED_PIN D0


// ====================================================
// HARDWARE OBJECTS
// ====================================================

// DHT22

DHT dht(DHT_PIN, DHT_TYPE);


// MPU6050

Adafruit_MPU6050 mpu;


// Servo

Servo doorServo;


// GPS
//
// GPS TX -> ESP8266 D7 (RX)
// GPS RX -> ESP8266 D6 (TX)

SoftwareSerial gpsSerial(D7, D6);
TinyGPSPlus gps;


// ====================================================
// SETUP
// ====================================================

void setup()
{
  Serial.begin(115200);

  Serial.println();
  Serial.println("================================");
  Serial.println("SMARTPETTI STARTING");
  Serial.println("================================");


  // ================= GPS =================

  gpsSerial.begin(9600);


  // ================= OUTPUT PINS =================

  pinMode(RELAY_PIN, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);


  // ================= INITIAL OUTPUT STATES =================

  // Relay OFF
  // Your relay is configured as ACTIVE-HIGH

  digitalWrite(RELAY_PIN, LOW);


  // Buzzer OFF

  digitalWrite(BUZZER_PIN, LOW);


  // LED OFF
  // ESP8266 built-in LED is active LOW

  digitalWrite(LED_PIN, HIGH);


  // ================= SERVO =================

  doorServo.attach(SERVO_PIN);

  delay(500);

  // Door closed

  doorServo.write(0);

  delay(1000);


  // ================= DHT22 =================

  dht.begin();


  // ================= MPU6050 =================

  Wire.begin(D2, D1);

  if (!mpu.begin())
  {
    Serial.println("MPU6050 NOT FOUND");

    while (1)
    {
      delay(100);
    }
  }

  Serial.println("MPU6050 Connected");


  // ================= WIFI =================

  connectWiFi();


  // ================= FIREBASE =================

  connectFirebase();


  // ================= INITIAL FIREBASE STATUS =================

  if (Firebase.ready())
  {
    Firebase.RTDB.setString(
      &fbdo,
      "/SmartPetti/device/status",
      "online"
    );

    Firebase.RTDB.setString(
      &fbdo,
      "/SmartPetti/sensors/doorStatus",
      "Closed"
    );

    Firebase.RTDB.setBool(
      &fbdo,
      "/SmartPetti/control/fan",
      false
    );

    Firebase.RTDB.setBool(
      &fbdo,
      "/SmartPetti/control/buzzer",
      false
    );

    Firebase.RTDB.setBool(
      &fbdo,
      "/SmartPetti/control/door",
      false
    );
  }


  Serial.println();
  Serial.println("================================");
  Serial.println("SMARTPETTI READY");
  Serial.println("================================");
}


// ====================================================
// READ DHT22
// ====================================================

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


// ====================================================
// READ MPU6050
// ====================================================

void readMPU()
{
  sensors_event_t accel;
  sensors_event_t gyro;
  sensors_event_t temp;

  mpu.getEvent(&accel, &gyro, &temp);

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

  Serial.print("Gyro X: ");
  Serial.println(gyro.gyro.x);

  Serial.print("Gyro Y: ");
  Serial.println(gyro.gyro.y);

  Serial.print("Gyro Z: ");
  Serial.println(gyro.gyro.z);
}


// ====================================================
// READ GPS
// ====================================================

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
    Serial.println(latitude, 6);

    Serial.print("Longitude: ");
    Serial.println(longitude, 6);
  }
  else
  {
    Serial.println();
    Serial.println("GPS Searching...");
  }
}


// ====================================================
// UPLOAD SENSOR DATA TO FIREBASE
// ====================================================

void uploadSensorData()
{
  if (!Firebase.ready())
  {
    Serial.println("Firebase Not Ready");
    return;
  }

  Serial.println();
  Serial.println("Uploading to Firebase...");


  // ================= TEMPERATURE =================

  if (Firebase.RTDB.setFloat(
        &fbdo,
        "/SmartPetti/sensors/temperature",
        temperature))
  {
    Serial.println("Temperature uploaded");
  }
  else
  {
    Serial.print("Temperature Error: ");
    Serial.println(fbdo.errorReason());
  }


  // ================= HUMIDITY =================

  if (Firebase.RTDB.setFloat(
        &fbdo,
        "/SmartPetti/sensors/humidity",
        humidity))
  {
    Serial.println("Humidity uploaded");
  }
  else
  {
    Serial.print("Humidity Error: ");
    Serial.println(fbdo.errorReason());
  }


  // ================= MPU ACCELERATION =================

  Firebase.RTDB.setFloat(
    &fbdo,
    "/SmartPetti/sensors/accelerationX",
    accelX
  );

  Firebase.RTDB.setFloat(
    &fbdo,
    "/SmartPetti/sensors/accelerationY",
    accelY
  );

  Firebase.RTDB.setFloat(
    &fbdo,
    "/SmartPetti/sensors/accelerationZ",
    accelZ
  );


  // ================= GPS =================

  Firebase.RTDB.setFloat(
    &fbdo,
    "/SmartPetti/location/latitude",
    latitude
  );

  Firebase.RTDB.setFloat(
    &fbdo,
    "/SmartPetti/location/longitude",
    longitude
  );


  // ================= DEVICE STATUS =================

  Firebase.RTDB.setString(
    &fbdo,
    "/SmartPetti/device/status",
    "online"
  );


  // ================= LAST UPDATE =================

  Firebase.RTDB.setInt(
    &fbdo,
    "/SmartPetti/device/lastSeen",
    millis()
  );


  Serial.println("Firebase Upload Complete");
}


// ====================================================
// READ FIREBASE CONTROLS
// ====================================================

void readControls()
{
  if (!Firebase.ready())
  {
    Serial.println("Firebase Not Ready For Control");
    return;
  }


  // ==================================================
  // FAN CONTROL
  // ==================================================

  if (Firebase.RTDB.getBool(
        &fbdo,
        "/SmartPetti/control/fan"))
  {
    fanState = fbdo.boolData();

    Serial.print("Fan Command: ");
    Serial.println(
      fanState ? "ON" : "OFF"
    );


    // ACTIVE-HIGH RELAY
    //
    // HIGH = Relay ON
    // LOW  = Relay OFF

    if (fanState)
    {
      digitalWrite(RELAY_PIN, HIGH);

      Serial.println("Fan ON");
    }
    else
    {
      digitalWrite(RELAY_PIN, LOW);

      Serial.println("Fan OFF");
    }
  }
  else
  {
    Serial.print("Fan Read Error: ");
    Serial.println(fbdo.errorReason());
  }


  // ==================================================
  // BUZZER CONTROL
  // ==================================================

  if (Firebase.RTDB.getBool(
        &fbdo,
        "/SmartPetti/control/buzzer"))
  {
    buzzerState = fbdo.boolData();

    digitalWrite(
      BUZZER_PIN,
      buzzerState ? HIGH : LOW
    );

    Serial.print("Buzzer: ");

    Serial.println(
      buzzerState ? "ON" : "OFF"
    );
  }
  else
  {
    Serial.print("Buzzer Read Error: ");
    Serial.println(fbdo.errorReason());
  }


  // ==================================================
  // SERVO DOOR CONTROL
  // ==================================================

  if (Firebase.RTDB.getBool(
        &fbdo,
        "/SmartPetti/control/door"))
  {
    doorState = fbdo.boolData();

    Serial.print("Door Command: ");

    Serial.println(
      doorState ? "OPEN" : "CLOSE"
    );


    // ================= OPEN =================

    if (doorState)
    {
      doorServo.write(180);

      delay(500);

      Firebase.RTDB.setString(
        &fbdo,
        "/SmartPetti/sensors/doorStatus",
        "Open"
      );

      Serial.println("Door OPEN");
    }


    // ================= CLOSE =================

    else
    {
      doorServo.write(0);

      delay(500);

      Firebase.RTDB.setString(
        &fbdo,
        "/SmartPetti/sensors/doorStatus",
        "Closed"
      );

      Serial.println("Door CLOSED");
    }
  }
  else
  {
    Serial.print("Door Read Error: ");
    Serial.println(fbdo.errorReason());
  }
}


// ====================================================
// LED STATUS
// ====================================================

void updateLED()
{
  if (WiFi.status() == WL_CONNECTED && Firebase.ready())
  {
    // Built-in LED ON

    digitalWrite(LED_PIN, LOW);
  }
  else
  {
    // Built-in LED OFF

    digitalWrite(LED_PIN, HIGH);
  }
}


// ====================================================
// MAIN LOOP
// ====================================================

void loop()
{
  unsigned long currentMillis = millis();


  // Read sensors and communicate with Firebase
  // every 2 seconds

  if (currentMillis - lastUpdate >= 2000)
  {
    lastUpdate = currentMillis;

    Serial.println();
    Serial.println("==============================");
    Serial.println("SMARTPETTI UPDATE");
    Serial.println("==============================");


    // ================= READ SENSORS =================

    readDHT();

    readMPU();

    readGPS();


    // ================= UPLOAD =================

    uploadSensorData();


    // ================= REMOTE CONTROLS =================

    readControls();


    // ================= LED =================

    updateLED();


    Serial.println("==============================");
  }
}
