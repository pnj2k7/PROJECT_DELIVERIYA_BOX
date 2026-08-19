# System Architecture

```mermaid
flowchart TD
    A[ESP8266 Smart Cargo Box] --> B[Firebase Realtime Database]
    B --> C[Flutter Sender App]
    B --> D[Flutter Customer App]

    A1[DHT22] --> A
    A2[MPU6050] --> A
    A3[GPS Receiver] --> A
    A4[Servo Door Lock] <-- A
    A5[Relay + Cooling Fan] <-- A

    C -->|Control / Monitoring| B
    D -->|Control / Monitoring| B
```

## Three-tier design

1. **Embedded tier** — ESP8266 reads sensors, controls actuators, sends telemetry and reads cloud commands.
2. **Cloud tier** — Firebase Authentication and Realtime Database provide identity, data storage and synchronization.
3. **Client tier** — Flutter provides role-specific Sender and Customer experiences.

The physical device and clients do not communicate directly; Firebase acts as the mediation layer.
