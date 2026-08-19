# Hardware Components

| Component | Qty | Function |
|---|---:|---|
| ESP8266 (NodeMCU) | 1 | Main microcontroller and Wi-Fi connectivity |
| DHT22 | 1 | Temperature and humidity sensing |
| MPU6050 | 1 | Motion / acceleration monitoring |
| GPS receiver | 1 | Live location tracking |
| SG90 micro servo | 1 | Door-lock actuator |
| 1-channel relay | 1 | Cooling-fan switching |
| Active piezo buzzer | 1 | Reserved for future alerting |
| 12V DC cooling fan | 1 | Cargo ventilation |

## GPIO allocation

| Component | ESP8266 GPIO | Interface |
|---|---|---|
| DHT22 data | D4 | Digital input |
| MPU6050 SDA / SCL | D2 / D1 | I2C |
| GPS RX / TX | D7 / D6 | SoftwareSerial UART |
| Servo signal | D5 | PWM |
| Relay (fan) | D8 | Digital output |
| Buzzer | D3 | Digital output |
| Status LED | D0 | Digital output |
