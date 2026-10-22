const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('web/office-directions.js', 'utf8');
function bridge(compute) {
  const google = {maps: {importLibrary: async name => {
    assert.equal(name, 'routes');
    return {Route: {computeRoutes: compute}};
  }}};
  const context = {google, window: {google}};
  vm.runInNewContext(source, context);
  return async () => JSON.parse(await context.window.idireksyonComputeRoute(14.8, 120.8, 14.9, 120.9));
}
test('uses browser SDK and normalizes road geometry, time and instructions', async () => {
  const compute = bridge(async request => {
    assert.equal(request.travelMode, 'DRIVING');
    assert.equal(request.routingPreference, 'TRAFFIC_UNAWARE');
    assert.deepEqual(JSON.parse(JSON.stringify(request.origin)), {lat: 14.8, lng: 120.8});
    return {routes: [{path: [{lat: 14.8, lng: 120.8}, {lat: 14.9, lng: 120.9}], distanceMeters: 2400, durationMillis: 480000, legs: [{steps: [{instructions: 'Turn right'}, {}]}]}]};
  });
  assert.deepEqual(await compute(), {points: [[14.8, 120.8], [14.9, 120.9]], distanceMeters: 2400, durationMillis: 480000, steps: ['Turn right']});
});
test('blocked API gives an actionable Cloud configuration error', async () => {
  const compute = bridge(async () => {throw Error('PERMISSION_DENIED: Requests to this API are blocked.');});
  assert.match((await compute()).error, /Enable Routes API.*API restrictions/);
});
test('no route and billing failures stay recoverable', async () => {
  assert.match((await bridge(async () => ({routes: []}))()).error, /No driving route/);
  assert.match((await bridge(async () => {throw Error('Billing disabled');})()).error, /Enable billing/);
});
test('SDK still loading returns an explanation instead of a JS exception', async () => {
  const context = {window: {}};
  vm.runInNewContext(source, context);
  const result = JSON.parse(await context.window.idireksyonComputeRoute(14.8, 120.8, 14.9, 120.9));
  assert.match(result.error, /still loading/);
});

test('also accepts callable coordinates from legacy LatLng objects', async () => {
  const result = await bridge(async () => ({routes: [{
    path: [{lat: () => 14.8, lng: () => 120.8}, {lat: () => 14.9, lng: () => 120.9}],
    distanceMeters: 2400, durationMillis: 480000, legs: [],
  }]}))();
  assert.deepEqual(result.points, [[14.8, 120.8], [14.9, 120.9]]);
});
