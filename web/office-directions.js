// Uses the same browser key and origin as the Google Maps JavaScript SDK.
window.idireksyonComputeRoute = async function(originLat, originLng, destinationLat, destinationLng) {
  try {
    if (!window.google || !google.maps || !google.maps.importLibrary) {
      return JSON.stringify({error: 'Google Maps is still loading. Reload the page and try again.'});
    }
    const { Route } = await google.maps.importLibrary('routes');
    const result = await Route.computeRoutes({
      origin: {lat: originLat, lng: originLng},
      destination: {lat: destinationLat, lng: destinationLng},
      travelMode: 'DRIVING',
      routingPreference: 'TRAFFIC_UNAWARE',
      language: 'en-US',
      fields: ['path', 'distanceMeters', 'durationMillis', 'legs'],
    });
    const route = result.routes && result.routes[0];
    if (!route || !route.path || route.path.length < 2) {
      return JSON.stringify({error: 'No driving route found to this office.'});
    }
    return JSON.stringify({
      points: route.path.map(point => [
        typeof point.lat === 'function' ? point.lat() : point.lat,
        typeof point.lng === 'function' ? point.lng() : point.lng,
      ]),
      distanceMeters: route.distanceMeters,
      durationMillis: route.durationMillis,
      steps: (route.legs || []).flatMap(leg => (leg.steps || [])
        .map(step => step.instructions).filter(Boolean)),
    });
  } catch (error) {
    const message = String(error.message || error);
    let explanation = 'Directions could not load. Check your connection and try again.';
    if (/billing/i.test(message)) {
      explanation = 'Enable billing for the Google Cloud project to use directions.';
    } else if (/PERMISSION_DENIED|blocked|not authorized|not enabled|SERVICE_DISABLED|REQUEST_DENIED/i.test(message)) {
      explanation = 'Google blocked directions. Enable Routes API and allow Routes API in your browser key API restrictions.';
    } else if (/ZERO_RESULTS|NOT_FOUND/i.test(message)) {
      explanation = 'No driving route found to this office.';
    }
    return JSON.stringify({error: explanation});
  }
};
