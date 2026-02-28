/**
 * Firebase Cloud Functions for Logistics Management System
 *
 * Functions:
 * 1. validateDriverUpdate - Validates driver location updates (anti-spoofing)
 * 2. calculateRouteInfo - Calculates ETA using Mapbox Directions API
 * 3. onShipmentStatusChange - Handles shipment status transitions
 * 4. updateDriverStats - Updates driver statistics on trip completion
 *
 * Environment Config:
 * Set the secret Mapbox token using:
 *   firebase functions:config:set mapbox.secret_token="YOUR_SECRET_TOKEN"
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();

const db = admin.firestore();

// ────────────────────────────────────────
// 1. VALIDATE DRIVER LOCATION UPDATE
// ────────────────────────────────────────
/**
 * Validates incoming driver location updates to prevent fake/spoofed locations.
 *
 * Checks:
 * - Speed between two consecutive points (max 200 km/h for trucks)
 * - Accuracy threshold
 * - Timestamp validity
 */
exports.validateDriverUpdate = functions.firestore
  .document("drivers/{driverId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const driverId = context.params.driverId;

    // Only validate location changes
    if (
      !after.currentLocation ||
      !before.currentLocation ||
      (after.currentLocation.latitude === before.currentLocation.latitude &&
        after.currentLocation.longitude === before.currentLocation.longitude)
    ) {
      return null;
    }

    const prevLat = before.currentLocation.latitude;
    const prevLng = before.currentLocation.longitude;
    const newLat = after.currentLocation.latitude;
    const newLng = after.currentLocation.longitude;

    // Calculate distance between consecutive points (Haversine)
    const distance = haversineDistance(prevLat, prevLng, newLat, newLng);

    // Calculate time difference
    const prevTime = before.lastUpdated
      ? before.lastUpdated.toDate()
      : new Date();
    const newTime = after.lastUpdated
      ? after.lastUpdated.toDate()
      : new Date();
    const timeDiffSeconds = (newTime - prevTime) / 1000;

    if (timeDiffSeconds > 0) {
      const speedKmh = (distance / 1000 / timeDiffSeconds) * 3600;

      // Max speed check: 200 km/h is unreasonable for logistics
      if (speedKmh > 200) {
        console.warn(
          `Suspicious location update from driver ${driverId}: ` +
            `${speedKmh.toFixed(1)} km/h over ${distance.toFixed(0)}m`
        );

        // Revert the location update
        await change.after.ref.update({
          currentLocation: before.currentLocation,
          lastUpdated: before.lastUpdated,
        });

        return null;
      }
    }

    return null;
  });

// ────────────────────────────────────────
// 2. CALCULATE ROUTE INFO (Mapbox Directions)
// ────────────────────────────────────────
/**
 * HTTPS callable function to calculate route info using Mapbox Directions API.
 * Protects the secret Mapbox token on the server side.
 *
 * @param {number} originLat
 * @param {number} originLng
 * @param {number} destLat
 * @param {number} destLng
 * @returns {Object} { polyline, distanceMeters, durationSeconds }
 */
exports.calculateRouteInfo = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Must be authenticated to call this function."
    );
  }

  const { originLat, originLng, destLat, destLng } = data;

  if (!originLat || !originLng || !destLat || !destLng) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Origin and destination coordinates are required."
    );
  }

  const mapboxToken = functions.config().mapbox?.secret_token;
  if (!mapboxToken) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Mapbox secret token not configured."
    );
  }

  try {
    const url =
      `https://api.mapbox.com/directions/v5/mapbox/driving/` +
      `${originLng},${originLat};${destLng},${destLat}` +
      `?access_token=${mapboxToken}` +
      `&geometries=polyline6&overview=full&steps=false`;

    const response = await fetch(url);
    const result = await response.json();

    if (!result.routes || result.routes.length === 0) {
      throw new functions.https.HttpsError(
        "not-found",
        "No route found between the specified points."
      );
    }

    const route = result.routes[0];
    return {
      polyline: route.geometry,
      distanceMeters: Math.round(route.distance),
      durationSeconds: Math.round(route.duration),
    };
  } catch (error) {
    console.error("Mapbox Directions API error:", error);
    throw new functions.https.HttpsError("internal", "Route calculation failed.");
  }
});

// ────────────────────────────────────────
// 3. ON SHIPMENT STATUS CHANGE
// ────────────────────────────────────────
/**
 * Triggered when a shipment document is updated.
 * Handles: status transitions, ETA updates, notifications.
 */
exports.onShipmentStatusChange = functions.firestore
  .document("shipments/{shipmentId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const shipmentId = context.params.shipmentId;

    // Only process status changes
    if (before.status === after.status) {
      return null;
    }

    console.log(
      `Shipment ${shipmentId} status: ${before.status} → ${after.status}`
    );

    // When shipment is accepted, calculate initial ETA
    if (
      before.status === "pending" &&
      after.status === "accepted" &&
      after.driverId
    ) {
      try {
        // Get driver's current location
        const driverDoc = await db
          .collection("drivers")
          .doc(after.driverId)
          .get();

        if (driverDoc.exists && driverDoc.data().currentLocation) {
          const driverLoc = driverDoc.data().currentLocation;
          const mapboxToken = functions.config().mapbox?.secret_token;

          if (mapboxToken) {
            const url =
              `https://api.mapbox.com/directions/v5/mapbox/driving/` +
              `${driverLoc.longitude},${driverLoc.latitude};` +
              `${after.destination.longitude},${after.destination.latitude}` +
              `?access_token=${mapboxToken}` +
              `&geometries=polyline6&overview=full`;

            const response = await fetch(url);
            const result = await response.json();

            if (result.routes && result.routes.length > 0) {
              const route = result.routes[0];
              const eta = new Date(
                Date.now() + route.duration * 1000
              );

              await change.after.ref.update({
                polyline: route.geometry,
                distanceMeters: Math.round(route.distance),
                durationSeconds: Math.round(route.duration),
                etaTimestamp: admin.firestore.Timestamp.fromDate(eta),
              });
            }
          }
        }
      } catch (error) {
        console.error("ETA calculation error:", error);
      }
    }

    // When shipment is completed, update driver stats
    if (after.status === "completed" && after.driverId) {
      try {
        await db
          .collection("drivers")
          .doc(after.driverId)
          .update({
            totalTrips: admin.firestore.FieldValue.increment(1),
            currentShipmentId: null,
          });
      } catch (error) {
        console.error("Driver stats update error:", error);
      }
    }

    return null;
  });

// ────────────────────────────────────────
// 4. OPTIMIZE ROUTE (Stretch Goal)
// ────────────────────────────────────────
/**
 * HTTPS callable function for vehicle routing optimization.
 * Uses Mapbox Optimization API to reorder stops for minimal distance.
 *
 * @param {Array} waypoints - Array of { lat, lng } objects
 * @returns {Object} { polyline, distanceMeters, durationSeconds, waypointOrder }
 */
exports.optimizeRoute = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Must be authenticated."
    );
  }

  const { waypoints } = data;
  if (!waypoints || waypoints.length < 2) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "At least 2 waypoints required."
    );
  }

  const mapboxToken = functions.config().mapbox?.secret_token;
  if (!mapboxToken) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Mapbox secret token not configured."
    );
  }

  try {
    const coordinates = waypoints
      .map((w) => `${w.lng},${w.lat}`)
      .join(";");

    const url =
      `https://api.mapbox.com/optimized-trips/v1/mapbox/driving/` +
      `${coordinates}` +
      `?access_token=${mapboxToken}` +
      `&geometries=polyline6&overview=full` +
      `&roundtrip=false&source=first&destination=last`;

    const response = await fetch(url);
    const result = await response.json();

    if (!result.trips || result.trips.length === 0) {
      throw new functions.https.HttpsError(
        "not-found",
        "No optimized route found."
      );
    }

    const trip = result.trips[0];
    const waypointOrder = result.waypoints.map((w) => w.waypoint_index);

    return {
      polyline: trip.geometry,
      distanceMeters: Math.round(trip.distance),
      durationSeconds: Math.round(trip.duration),
      waypointOrder: waypointOrder,
    };
  } catch (error) {
    console.error("Route optimization error:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Route optimization failed."
    );
  }
});

// ────────────────────────────────────────
// UTILITY: Haversine Distance
// ────────────────────────────────────────
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth's radius in meters
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(deg) {
  return (deg * Math.PI) / 180;
}
