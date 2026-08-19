# DELIVERIYA — Project Overview

## Purpose

DELIVERIYA is an IoT-based smart cargo consignment monitoring and access-control system with real-time mobile application integration.

## Core idea

A physical ESP8266-based smart box collects environmental, motion and location data and communicates with Firebase Realtime Database. Sender and Customer users interact with the same consignment through a Flutter application. Firebase mediates the communication between the physical device and clients.

## Main capabilities

- Temperature and humidity monitoring
- Motion / shock monitoring
- GPS location tracking
- Remote door lock control
- Cooling-fan control
- Automatic fan activation at 35°C
- Sender and Customer role separation
- Timestamped activity history
- Emergency sender access
- Customer delivery confirmation
- Cross-platform Flutter client

## Current limitations

- No dedicated tamper-detection hardware
- No battery telemetry
- Wi-Fi dependency for the ESP8266
- No background push notifications while the app is fully closed
- Multi-device support is designed in software but was not validated using multiple physical units
