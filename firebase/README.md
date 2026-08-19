# Firebase configuration

DELIVERIYA uses Firebase Authentication and Firebase Realtime Database as its cloud layer.

The repository intentionally does **not** contain private server credentials, Wi-Fi passwords, or deployment-specific Firebase configuration files.

## Database structure

The illustrative structure is provided in `database-schema.example.json`.

The main path is:

`boxes/{boxId}/`

with the following logical sections:

- `meta` — box identity and metadata
- `sensors` — latest sensor values
- `control` — door/fan/buzzer commands
- `device` — online status and last-seen timestamp
- `location` — GPS coordinates
- `sender` / `customer` — associated contact information
- `activity` — timestamped security events
- `sensorHistory` — historical sensor snapshots

## Setup

Create your own Firebase project, enable Email/Password Authentication and Realtime Database, then configure the Flutter application and ESP8266 firmware with your own project values.

Never commit Wi-Fi passwords, service-account credentials, private keys, or other secrets.
