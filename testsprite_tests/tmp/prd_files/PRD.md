# Product Requirements Document (PRD)
## Edita Logistics App

### 1. Document Overview
**Product Name:** Edita Logistics
**Platform:** Flutter (Android / iOS / Web)
**Core Value Proposition:** A comprehensive, real-time logistics management solution bridging the gap between corporate clients (factories), drivers, and administrative managers for efficient tracking, routing, and delivery of shipments.
**Main Technologies:** Flutter, Riverpod (State Management), Firebase (Auth & Firestore), Mapbox (Routing, Directions, ETAs, Live Navigation), Freezed (Data models), Clean Architecture.

---

### 2. Product Goals & Objectives
1. **Real-Time Visibility:** Allow clients to track shipments, drivers, and ETAs in real-time.
2. **Optimized Driver Experience:** Create a driver interface capable of executing a live, in-app GPS navigation assistant mimicking native apps like Google Maps.
3. **Automated Status Pipelines:** Automate trip phases (e.g., Driver -> Factory [Pickup] -> Client [Delivery]).
4. **Resilience & Scalability:** Guarantee tracking functionality even in offline scenarios (Dead-zones) using local data caching via Hive before syncing to the cloud.
5. **Robust Error Handling:** Ensure the application remains entirely crash-free and structurally sound against Unmounted Widget Exceptions, State Errors, and overlapping asynchronous updates.

---

### 3. User Personas

#### 3.1. Client (Stakeholder/Factory Manager)
- **Role:** Creates shipment requests and monitors active logistics.
- **Key Needs:** Wants to input factory locations, destinations, and get accurate price, distance, and duration estimations. Needs to visually track the driver across both pickup and delivery legs.
- **Pain Points:** Lack of transparency in driver location and delays in ETA.

#### 3.2. Driver
- **Role:** Accepts shipments and physically delivers them.
- **Key Needs:** Requires clear routing instructions, phase indicators (Pickup vs. Delivery), and an advanced turn-by-turn or live GPS map assistant.
- **Pain Points:** Poor internet connectivity causing app crashes or lost location points, switching between apps for navigation.

---

### 4. Technical Architecture & State Management
- **Architecture:** Clean Architecture (`domain`, `data`, `presentation` layers).
- **State Management:** Riverpod (`ConsumerWidget`, `StateNotifierProvider`, `FutureProvider`).
- **Data Persistence:** Cloud Firestore (Real-time syncing). Hive (Local caching for offline location tracking).
- **Mapping & Routing:** Mapbox API (`directions/v5`, `optimized-trips/v1`, Mapbox Streets v12 style) coupled with Mapbox Maps Flutter.
- **Navigation:** GoRouter with `RouterNotifier` dynamically driven by authentication state (`authNotifierProvider`, `currentUserProvider`, `splashCompleteProvider`) mathematically avoiding widget unmounting.

---

### 5. Core Features & Capabilities

#### 5.1. Authentication System
- **Methods:** Firebase Email/Password authentication.
- **Logic:** Automated redirection based on user roles (`client`, `driver`, `admin`).
- **Security:** Global error catching (`FlutterError.onError`, `PlatformDispatcher.onError`) preventing navigation race conditions.

#### 5.2. Client Dashboard & Shipment Tracking
- **Create Shipment:** Dynamic UI utilizing `Mapbox` to select origin (Factory) and destination. Automatically fetches duration, distance, and generates precise polylines.
- **Live Shipment Tracker (`ShipmentTrackingScreen`):**
  - **Dynamic Leg Chips:** Split view of **Factory Leg** (color: `AppColors.info` [Blue]) and **Delivery Leg** (color: `AppColors.accent` [Orange]). Chips scale responsively on all screens using `FittedBox`.
  - **Live Progress:** Renders driver icon moving in real-time across the polyline, dynamically updating the current ETA.

#### 5.3. Driver GPS Assistant & Trip Management
- **Driver Dashboard:** Lists pending/available shipments.
- **Active Trip Mode (`DriverTripScreen`):**
  - **Live Navigation Assistant:** Automatically applies a 3D Pitch (45-degree angle), high zoom level (17.5), and bearing adjustments tracking the live `heading` to emulate a fully native GPS navigation system within the app.
  - **Phase Awareness:** Segments trips into `pickup` (Driver to Factory) and `delivery` (Factory to Client). Adapts route lines and chips automatically.
  - **Dead-Zone Handling:** If the network disconnects, GPS points are stored locally via `location_service.dart`. Once back online, the backlog is synced chronologically to Firestore.

#### 5.4. Theme & Responsiveness
- **Design System:** Locked text scaling factors (`0.85` to `1.1`) to strictly prevent system-wide font overwrites.
- **Responsive Utilities (`ResponsiveUtil`):** Ensures elements scale proportionally across devices, relying on `Expanded` and `FittedBox` for strict layout enforcement (e.g., bottom cards, map overlays).

---

### 6. Logic Workflows

#### 6.1. Splash Screen & Initialization
1. Caches dependencies synchronously (`locationServiceProvider`, `splashCompleteProvider`).
2. Fires an asynchronous 2-second branding timeout and safely requests GPS permissions.
3. Signals GoRouter to route to Auth or Dashboard using strict Context/State guarding (`if (!mounted) return;`).

#### 6.2. Driver Trip Lifecycle
1. **Accept Shipment:** Driver claims shipment. Map fetches 2 distinct routes (Leg 1: Driver -> Factory, Leg 2: Factory -> Destination).
2. **Start Trip:** Native GPS Navigation Camera activates. Location Listener is booted.
3. **In Transit:** Every update (filtered by 8 seconds / 40 meters) pulses position, speed, accuracy, and heading. Syncs to Firestore immediately or caches to Hive.
4. **Phase Switch:** Driver clicks "Confirm Pickup", transition to Leg 2 (UI shifts to Orange delivery mode).
5. **Complete Trip:** Driver completes delivery, tracking terminates, cache flushed.

---

### 7. Known Solutions (Guarantees implemented in codebase)
- **Widget Unmounted Exceptions (GoRouter):** Fixed by initializing the GoRouter instance as a singleton and using a `RouterNotifier` linked to Riverpod state, executing strictly silent listener updates instead of dropping the app's widget tree.
- **StateError (ref.read after dispose):** Handled across the asynchronous map functions (like `_updateETA`) by synchronously instantiating providers into local variables before making remote RPC calls (`await firestore...`), completely bypassing context drops.
- **Row Overflows (UI):** Fixed globally for dynamic cards using Flex attributes (`Expanded`, `FittedBox.scaleDown`).

---

### 8. Future Roadmap / Enhancements
- Geofencing integration to automatically switch trip phases once a driver crosses a factory's radius.
- Admin portal for bulk analytics and data aggregation based on historical Firestore trip datasets.
- Implement Push Notifications (FCM) to actively ping clients when Leg 2 (Delivery) officially triggers.
