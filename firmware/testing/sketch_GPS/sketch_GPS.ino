#include <ESP8266WiFi.h>

#include <SoftwareSerial.h>

#include <TinyGPS++.h>

const char* ssid = "SLT-Fiber-2.4G";

const char* password = "8013Nilu";

// GPS Pins

static const int RXPin = D7;   // GPS TX -> D7

static const int TXPin = D6;   // GPS RX -> D8

static const uint32_t GPSBaud = 9600;

SoftwareSerial gpsSerial(RXPin, TXPin);

TinyGPSPlus gps;

double lastLat = 0.0;

double lastLng = 0.0;

double totalDistance = 0.0;

bool firstFix = true;

void setup() {

  Serial.begin(115200);

  gpsSerial.begin(GPSBaud);

  Serial.println();

  Serial.println("Connecting to WiFi...");

  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {

    delay(500);

    Serial.print(".");

  }

  Serial.println();

  Serial.println("================================");

  Serial.println("WiFi Connected!");

  Serial.print("IP Address: ");

  Serial.println(WiFi.localIP());

  Serial.println("Waiting for GPS Fix...");

  Serial.println("================================");

}

void loop() {

  while (gpsSerial.available()) {

    gps.encode(gpsSerial.read());

  }

  if (gps.location.isUpdated()) {

    double lat = gps.location.lat();

    double lng = gps.location.lng();

    if (firstFix) {

      lastLat = lat;

      lastLng = lng;

      firstFix = false;

    } else {

      totalDistance += TinyGPSPlus::distanceBetween(

        lastLat, lastLng,

        lat, lng

      );

      lastLat = lat;

      lastLng = lng;

    }

    Serial.println("--------------------------------");

    Serial.print("Latitude : ");

    Serial.println(lat, 6);

    Serial.print("Longitude: ");

    Serial.println(lng, 6);

    Serial.print("Speed    : ");

    Serial.print(gps.speed.kmph());

    Serial.println(" km/h");

    Serial.print("Distance : ");

    Serial.print(totalDistance, 2);

    Serial.println(" meters");

    Serial.print("Google Maps: ");

    Serial.print("https://maps.google.com/?q=");

    Serial.print(lat, 6);

    Serial.print(",");

    Serial.println(lng, 6);

    Serial.println("--------------------------------");

    Serial.println();

  }

  if (millis() > 10000 && gps.charsProcessed() < 10) {

    Serial.println("No GPS data received!");

    Serial.println("Move the GPS outdoors and check wiring.");

    delay(5000);

  }

}