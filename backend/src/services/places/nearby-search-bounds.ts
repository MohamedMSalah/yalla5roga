export const EARTH_RADIUS_KM = 6371;

type Range = readonly [min: number, max: number];

/** Indexed candidate bounds for a spherical search. Exact distance is checked in SQL. */
export function nearbySearchBounds(lat: number, lng: number, radiusKm: number) {
  const angularRadius = radiusKm / EARTH_RADIUS_KM;
  const latitudeDelta = (angularRadius * 180) / Math.PI;
  const latitude: Range = [
    Math.max(-90, lat - latitudeDelta),
    Math.min(90, lat + latitudeDelta),
  ];

  // At a pole the circle can contain places at any longitude.
  if (latitude[0] === -90 || latitude[1] === 90) {
    return { latitude, longitudes: [] as Range[] };
  }

  const latitudeRadians = (lat * Math.PI) / 180;
  const longitudeDelta =
    (Math.asin(Math.min(1, Math.sin(angularRadius) / Math.cos(latitudeRadians))) *
      180) /
    Math.PI;
  const west = lng - longitudeDelta;
  const east = lng + longitudeDelta;
  let longitudes: Range[];
  if (west < -180) {
    longitudes = [[west + 360, 180], [-180, east]];
  } else if (east > 180) {
    longitudes = [[west, 180], [-180, east - 360]];
  } else {
    longitudes = [[west, east]];
  }
  return { latitude, longitudes };
}
