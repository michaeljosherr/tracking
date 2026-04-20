# Flutter Tracker App Architecture Analysis

## 1. Current Data Model Structure

### Tracker Model
**File**: [lib/models/mock_data.dart](lib/models/mock_data.dart)

The `Tracker` class represents a registered tracker device with the following structure:

```dart
class Tracker {
  final String id;                    // Unique app-wide ID (UUID)
  final String deviceId;              // BLE device identifier (e.g., "A1B3")
  final String name;                  // User-friendly name (e.g., "John")
  final TrackerStatus status;         // connected | disconnected | outOfRange
  final int signalStrength;           // 0-100
  final DateTime lastSeen;            // Last BLE signal timestamp
  final int? batteryLevel;            // 0-100 (optional)
  
  // BLE-specific fields
  final int? rssi;                    // Raw RSSI in dBm
  final double? rssiFiltered;         // Kalman-filtered RSSI
  final double? distance;             // Estimated distance in meters
  final String? serialNumber;         // Extracted from device name
  final String? bleAddress;           // **HUB MAC ADDRESS** (critical field)
  final double? tagCompassBearingDeg; // Magnetic bearing to tag (0=N, CW)
}

enum TrackerStatus { connected, disconnected, outOfRange }
```

**Key Points**:
- `bleAddress` field stores the **hub's BLE MAC address**, not the tracker's
- This is how trackers are associated with hubs: `tracker.bleAddress == hubBleId`
- Each tracker is serialized to JSON for persistent storage in SharedPreferences
- Bearings are auto-calculated when tracker is very close (< 1.2m) or has strong RSSI (≥ -58 dBm)

### PendingTracker Model
**File**: [lib/models/mock_data.dart](lib/models/mock_data.dart#L157)

Represents a tracker discovered but not yet registered:

```dart
class PendingTracker {
  final String deviceId;              // From BLE advertisement
  final int signalStrength;           // 0-100
  final DateTime discovered;          // When found during scan
  final String? serialNumber;         // Parsed from device name
  final String? bleAddress;           // MAC address (hub's address)
  final int? rssi;                    // Raw RSSI
  final double? rssiFiltered;         // Kalman-filtered RSSI
  final double? distance;             // Calculated from RSSI
  final List<double>? rssiHistory;    // Historical RSSI values
}
```

### DiscoveredHub Model
**File**: [lib/core/ble_service.dart](lib/core/ble_service.dart#L89)

Represents a discovered hub during BLE scan:

```dart
class DiscoveredHub {
  final String remoteId;              // Hub BLE MAC address
  final String displayName;           // Hub advertising name (e.g., "ESP32_TRACKER_HUB")
  final int rssi;                     // Signal strength in dBm
}
```

---

## 2. TrackerProvider State Management

**File**: [lib/core/tracker_provider.dart](lib/core/tracker_provider.dart)

The `TrackerProvider` is a `ChangeNotifier` that manages:

### Core State
```dart
final List<Tracker> _trackers = [];                    // All registered trackers (persisted)
final List<Alert> _alerts = [];                        // Alerts (persisted)
final Set<String> _savedHubBleIds = {};                // Hubs user has opened (persisted)
bool _isScanningHubs = false;                          // Currently scanning for hubs
List<DiscoveredHub> _discoveredHubs = [];              // Results from last hub scan
bool _isBackgroundScanning = false;                    // Continuous background scanning active
```

### Key Relationships
- **Tracker ↔ Hub**: Linked via `tracker.bleAddress == hubBleId`
- **Hub Tracking**: Hubs with trackers are stored in `_savedHubBleIds` (persisted in SharedPreferences)
- **Serial Number Uniqueness**: A serial number can only be registered to ONE hub (app-wide)

### Important Public Getters
```dart
List<Tracker> get trackers                             // All registered trackers
List<DiscoveredHub> get discoveredHubs                 // Hubs found in last scan
List<String> get savedHubBleIds                        // Hubs in user's setup
int get connectedCount                                 // Trackers currently connected
int get outOfRangeCount                                // Trackers out of range
int get disconnectedCount                              // Trackers offline (>20s)
List<Alert> get activeAlerts                           // Unacknowledged alerts
```

### Distance Smoothing
- Each tracker's distance is smoothed using **EMA (Exponential Moving Average)** with alpha=0.22
- Max step per update: 14.0 meters (prevents huge jumps from bad RSSI samples)
- Distances clamped to [0.05, 500.0] meters
- Stored in `_distanceEmaBySerial` map by serial number

### Auto Bearing
- When a tracker is very close (< 1.2m) OR has strong RSSI (≥ -58 dBm) for 6 consecutive scans
- Auto-sets `tagCompassBearingDeg` to phone's magnetic heading
- Reduces manual calibration burden for tracking in real time

---

## 3. Current Screen Architecture

### Dashboard Screen (`/`)
**File**: [lib/screens/dashboard_screen.dart](lib/screens/dashboard_screen.dart)

**Purpose**: Main app view showing all registered trackers across all hubs

**Lifecycle**:
- `initState()`: Starts background scanning if trackers exist
- `dispose()`: **STOPS background scanning** (important for battery)
- Displays tracker stats: total, connected, out-of-range, disconnected
- Supports list/grid view, search, filtering by status
- Users can tap trackers to see detail view or navigate to radar

**State Tracking**:
- Stops background scanning when leaving dashboard (other tabs or modal routes)
- Resumes when returning

### Hub Select Screen (`/hubs/select`)
**File**: [lib/screens/hub_select_screen.dart](lib/screens/hub_select_screen.dart)

**Purpose**: BLE scan for available hubs; user selects one to add trackers

**Lifecycle**:
- `initState()`: Immediately calls `scanForHubs()` with **zero debounce** (fixed in Phase 2)
- `didPopNext()`: When returning from hub_trackers_screen, immediately rescans (zero debounce) after 100ms cleanup
- `dispose()`: Calls `startBackgroundScanning()` to resume monitoring existing trackers

**Behavior**:
- Shows spinning indicator while scanning (6-second BLE scan)
- Lists discovered hubs with RSSI and MAC address
- User taps hub to navigate to `/hubs/trackers?hubId={encoded_mac}`

### Hub Trackers Screen (`/hubs/trackers?hubId=...`)
**File**: [lib/screens/hub_trackers_screen.dart](lib/screens/hub_trackers_screen.dart)

**Purpose**: Add trackers to a specific hub; manage trackers on that hub

**Lifecycle**:
- `initState()`: Starts dedicated hub BLE session (connects to hub, starts telemetry stream)
- `dispose()`: Stops dedicated session and resumes background scanning

**Key Logic**:
```dart
List<PendingTracker> _live = [];                       // Trackers currently advertising from hub
List<Tracker> registered = trackers
    .where((t) => t.bleAddress == widget.hubBleId)   // Trackers tied to this hub
    .toList();
```

**Flow**:
1. Displays live trackers discovered from hub (telemetry stream from hub hardware)
2. Shows already-registered trackers for this hub
3. User can register new trackers (calls `registerDeviceOnHub()`)
4. User can unregister trackers (calls `unregisterTracker()`)
5. User can remove the entire hub (calls `removeHubConnection()`)

---

## 4. Navigation Flow

**File**: [lib/core/router.dart](lib/core/router.dart)

### Route Structure
```
/ (DashboardScreen)
  ├─ /alerts (AlertsScreen)
  ├─ /settings (SettingsScreen)
  └─ [Modal Routes]
      ├─ /hubs/select (HubSelectScreen)
      ├─ /hubs/trackers?hubId={encoded_mac} (HubTrackersScreen)
      ├─ /radar (AllTrackersRadarScreen)
      └─ /tracker/:id (TrackerDetailScreen)
```

### Navigation Patterns

**Adding Trackers (Multi-Hub Scenario)**:
```
Dashboard (background scanning active)
  → Click "Add trackers" or settings link
  → /hubs/select (stops background scan, starts hub scan)
    → Select hub from list
    → /hubs/trackers?hubId=XX:XX:XX (dedicated session to hub)
      → Register trackers (each saves to _trackers with bleAddress=hubId)
      → Remove hub (deletes all trackers tied to hubId)
    → [Pop]
    → /hubs/select again (rescan immediately for hub that may have reset)
  → [Pop]
  → Dashboard (resume background scanning)
```

**Tab Navigation**:
- Dashboard/Alerts/Settings use `StatefulShellRoute` (preserves state)
- Modal routes overlay on top and don't affect tab state

### Key Redirects
- `/profile` → `/settings`
- `/pairing` → `/hubs/select`
- Onboarding redirect if not completed

---

## 5. Hub/Tracker Relationship Maintenance

### How Trackers Are Associated with Hubs

**At Registration** ([TrackerProvider.registerDeviceOnHub](lib/core/tracker_provider.dart#L673)):
```dart
final newTracker = Tracker(
  // ... other fields ...
  bleAddress: expectedHubBleId,  // ← Link to hub
  serialNumber: pendingTracker.serialNumber,
);
_trackers.add(newTracker);
await rememberHubConnection(expectedHubBleId);  // Save hub in _savedHubBleIds
```

**Serial Number Uniqueness Enforcement**:
```dart
final existing = _trackerBySerial(serial);
if (existing != null) {
  if (existing.bleAddress == expectedHubBleId) {
    return SerialRegistrationOutcome.duplicateOnThisHub;
  }
  return SerialRegistrationOutcome.blockedOtherHub;  // ← Can't register same serial on different hub
}
```

### Data Persistence
**SharedPreferences Keys**:
- `_trackersStorageKey = 'registered_trackers'` - JSON array of all trackers
- `_hubIdsStorageKey = 'saved_hub_ble_ids'` - List of hubs (from both explicit user opens + trackers' bleAddress fields)

**Load at App Start** ([TrackerProvider.initialize](lib/core/tracker_provider.dart#L105)):
```dart
await _loadTrackers();    // Deserialize each tracker from JSON
await _loadHubIds();      // Load saved hub BLE IDs + add all unique bleAddress values from trackers
```

### Background Scanning for Multiple Hubs
**File**: [TrackerProvider.startBackgroundScanning](lib/core/tracker_provider.dart#L413)

Continuous rotation scanning across all hubs:
```dart
List<String> _distinctHubBleIdsForBackground() {
  final s = <String>{..._savedHubBleIds};
  for (final t in _trackers) {
    if (t.bleAddress != null) s.add(t.bleAddress!);  // Include all hubs with trackers
  }
  return s.toList();
}

await _ble.startContinuousScanning(
  hubBleIds: _distinctHubBleIdsForBackground(),  // Scan all hubs with trackers
  onTrackerUpdate: _onContinuousScanUpdate,
);
```

### Hub Removal
**File**: [TrackerProvider.removeHubConnection](lib/core/tracker_provider.dart#L383)

```dart
_trackers.removeWhere((t) => t.bleAddress == hubBleId);  // Delete all trackers on hub
_savedHubBleIds.remove(hubBleId);                        // Remove hub from saved list
await _saveTrackers();
await _saveHubIds();
```

---

## 6. Multi-Hub Support Readiness Assessment

### ✅ Already Designed for Multi-Hub
1. **Serial Number Isolation**: Each hub can have a different set of trackers
2. **BLE Rotation Scanning**: Background scanning naturally handles multiple hubs
3. **Hub Selection Flow**: `/hubs/select` → pick hub → `/hubs/trackers?hubId=...`
4. **Persistent Hub IDs**: `_savedHubBleIds` tracks all active hubs

### ⚠️ Current Limitations

1. **UI Only Shows One Hub at a Time**
   - Hub Select screen shows available hubs
   - Hub Trackers screen manages one hub at a time
   - Dashboard shows all trackers but doesn't filter/group by hub
   - **Need**: Hub summary view showing trackers per hub

2. **No Dashboard Hub Grouping**
   - Dashboard displays all trackers in one list
   - No visual indication which trackers belong to which hub
   - **Need**: Cards/sections per hub or hub badges on trackers

3. **No Hub Management Screen**
   - To manage hubs (remove, rename), must go to `/hubs/trackers?hubId=...`
   - No central hub list in Settings
   - **Need**: Hub management view (list of all connected hubs + actions)

4. **Single Dedicated Hub Session**
   - Only one hub can have dedicated telemetry stream at a time
   - `_dedicatedHubActive` boolean prevents simultaneous connections
   - **OK for current use case**: But prevents multi-hub real-time monitoring

5. **No Hub Rename/Alias**
   - Hubs are identified by MAC address only
   - UI shows hub's BLE advertisement name (e.g., "ESP32_TRACKER_HUB")
   - **Could add**: User-friendly hub nicknames (persisted separately)

### Recommended Next Steps

#### Phase 3: Hub Summary View
- Add "Connections" or "Hubs" tab showing all saved hubs
- Display hub name, last connected, # of trackers
- Show hub actions: Open (go to `/hubs/trackers?hubId=...`), Remove, Rename

#### Phase 4: Dashboard Improvements
- Add hub grouping/filtering on dashboard
- Show hub badge on each tracker card
- Add "Add to Hub" action directly from dashboard
- Visual hub status (online/offline based on any tracker connection)

---

## 7. Key Implementation Details

### Offset Calculations & Triangulation
**File**: [lib/widgets/all_trackers_radar.dart](lib/widgets/all_trackers_radar.dart)

- **Triangulation**: Uses bearing + distance to calculate Cartesian positions
- **Collision Detection**: Detects overlapping blips (radius = blipR + 4.0 px)
- **Resolution**: Applies iterative repulsive forces (3 iterations max)
- **Bearing Offsets**: Clamped to ±0.35 radians to prevent extreme spreads

### Bearing Sources
1. **Auto-calculated** (when close or strong RSSI): Phone's magnetic heading
2. **Manual override**: User can set bearing directly
3. **Cleared**: User can clear bearing to auto-mode

### Offline Detection
- Tracker marked disconnected if > 20 seconds since last BLE signal
- Background scanning periodically polls (every 2 seconds)
- Stops background scanning if all trackers disconnect or app closes

---

## 8. Current Bug Fixes Applied (Phase 2)

### Hub Scanning Fixes
1. **Auto-scan on page load**: Removed 160ms debounce → immediate scan
2. **Return from hub trackers**: Zero-debounce rescan to catch hub reset advertising
3. **`_scheduleScan()` method**: Added optional debounce parameter (default 160ms for backward compat)

### Radar Triangulation Fix
1. **Triangulation System**: Calculate accurate 2D positions from bearing + distance
2. **Collision Detection**: Check all tracker pairs for overlaps
3. **Iterative Resolution**: Apply repulsive forces to spread overlapping trackers
4. **Result**: All trackers visible (no hiding), smart spacing based on bearing relationships

---

## Summary: What Needs to Change for Full Multi-Hub Support

### Current State
- ✅ Data model supports multi-hub (bleAddress per tracker)
- ✅ Background scanning rotates across hubs
- ✅ UI flow allows picking different hubs sequentially
- ❌ UI doesn't show multi-hub perspective
- ❌ No way to manage multiple hubs from one place

### For Full Multi-Hub Support
1. **Hub Management UI** - Central location to see all hubs, add, remove, rename
2. **Dashboard Hub Grouping** - Show trackers organized by hub
3. **Hub Status Indicators** - Visual indication of hub connectivity
4. **Quick Hub Switching** - Easy way to jump between hubs without full flow
5. **Hub Analytics** - Hub-level metrics (connection health, battery across hubs)
