#define RELAY_PIN D8

void setup() {
  Serial.begin(115200);
  pinMode(RELAY_PIN, OUTPUT);
}

void loop() {

  Serial.println("FAN ON");
  digitalWrite(RELAY_PIN, LOW);
  delay(5000);

  Serial.println("FAN OFF");
  digitalWrite(RELAY_PIN, HIGH);
  delay(5000);

}