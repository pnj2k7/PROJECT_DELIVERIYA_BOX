#include <SoftwareSerial.h>
#include <TinyGPS++.h>

TinyGPSPlus gps;

// GPS connection
// ESP8266 D7 = RX (receives GPS TX)
// ESP8266 D6 = TX (sends to GPS RX)
SoftwareSerial gpsSerial(D7, D6);

void setup() {

  Serial.begin(115200);
  gpsSerial.begin(9600);

  Serial.println();
  Serial.println("NEO-6M GPS TEST STARTED");

}

void loop() {

  while (gpsSerial.available()) {
    gps.encode(gpsSerial.read());
  }


  // Print GPS status every 2 seconds
  static unsigned long lastPrint = 0;

  if (millis() - lastPrint > 2000) {

    lastPrint = millis();

    Serial.println("----------------------");

    Serial.print("Satellites: ");
    Serial.println(gps.satellites.value());

    Serial.print("GPS Fix: ");

    if (gps.location.isValid()) {
      Serial.println("YES");
      
      Serial.print("Latitude: ");
      Serial.println(gps.location.lat(), 6);

      Serial.print("Longitude: ");
      Serial.println(gps.location.lng(), 6);

      Serial.print("Altitude: ");
      Serial.print(gps.altitude.meters());
      Serial.println(" m");

    } 
    else {
      Serial.println("NO - Searching...");
    }

  }

}