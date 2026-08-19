#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

Adafruit_MPU6050 mpu;

void setup() {
  Serial.begin(115200);
  Wire.begin(D2, D1);

  if (!mpu.begin()) {
    Serial.println("MPU6050 not found!");
    while (1);
  }

  Serial.println("MPU6050 Connected");
}

void loop() {
  sensors_event_t a, g, temp;

  mpu.getEvent(&a, &g, &temp);

  Serial.print("Accel X: ");
  Serial.print(a.acceleration.x);
  Serial.print("  Y: ");
  Serial.print(a.acceleration.y);
  Serial.print("  Z: ");
  Serial.println(a.acceleration.z);

  Serial.print("Gyro X: ");
  Serial.print(g.gyro.x);
  Serial.print("  Y: ");
  Serial.print(g.gyro.y);
  Serial.print("  Z: ");
  Serial.println(g.gyro.z);

  Serial.println("------------------------");

  delay(1000);
}