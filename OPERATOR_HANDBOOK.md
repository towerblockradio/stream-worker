# Tower Block Radio — Operator Handbook

## Pre-Broadcast Checklist

Before going live on Twitch, ensure:

1. **RadioCult stream is online**
   - Verify at the stream URL in Broadcast Settings
   - The stream must be active for the worker to ingest audio

2. **Worker is deployed and healthy**
   - `curl http://WORKER_IP:3100/health` returns `{"status":"ok"}`
   - Worker status shows "Online" in the admin dashboard

3. **Twitch OAuth is connected**
   - Twitch Connection card shows "Connected" with your channel name
   - Token is not expired (if expired, click "Refresh Token")

4. **Compliance gate is approved**
   - The compliance card shows green "Approved" status
   - If not approved, review the compliance statement and confirm

5. **DJ artwork is generated and approved**
   - Check DJ Artwork section — at least one asset should be "approved"
   - Generate artwork for any new DJs before they go live

6. **Schedule is synced**
   - Click "Sync Now" in the Schedule Sync panel
   - Verify no errors in the sync results

## Starting a Broadcast

1. Navigate to `/admin/twitch-broadcast`
2. Verify all checklist items are green
3. Click **Start Broadcast**
4. The worker will:
   - Fetch the Twitch stream key from the control plane
   - Launch FFmpeg with the RadioCult audio stream
   - Begin RTMP output to Twitch
   - Start metadata monitoring
5. The "ON AIR" indicator will appear when streaming

## Stopping a Broadcast

### Normal Stop
1. Click **Stop**
2. Confirm the stop action
3. The worker will gracefully shut down FFmpeg

### Emergency Stop
1. Click **Emergency Stop**
2. Confirm the emergency stop
3. FFmpeg is killed immediately, stream goes offline

Use emergency stop only when:
- Audio is corrupted or wrong
- Visuals are broken
- You need to immediately cut the stream

## Scene Management

### Available Scenes
- `main_live` — Default live broadcast scene
- `starting_soon` — Pre-show holding screen
- `live_show` — Active show with full metadata
- `automated_playlist` — When RadioCult is running automation
- `up_next` — Transition between shows
- `track_unknown` — When track cannot be identified
- `signal_interrupted` — Stream loss fallback
- `emergency` — Critical failure mode
- `station_ident` — Station identifier/bumper
- `offline` — Worker not broadcasting

### Locking a Scene
Use **Lock Scene** to prevent automatic scene changes during:
- Guest DJ sets where you want manual control
- Special broadcasts
- Testing

## Track Corrections

If the metadata recognition is wrong:
1. Click **Correct Track** (available in the broadcast controls)
2. Enter the correct title and artist
3. The correction is logged in the track history audit log

For dubplates and unknown tracks, the system automatically displays "Dubplate / ID Unknown".

## Schedule Synchronisation

The worker automatically syncs the RadioCult schedule to Twitch every 30 minutes.
Manual sync is available via the **Sync Now** button.

### Excluding Shows
If a show should not appear on the Twitch schedule:
1. Find it in the Schedule Mappings
2. Set its status to "excluded"

### Non-Affiliate Accounts
Twitch schedule segments require Affiliate or Partner status.
If your account doesn't have this:
- The sync will show warnings in the event log
- Channel title automation still works
- On-screen schedule display still works

## Monitoring

### Dashboard Overview Cards
- **RadioCult**: Connection status and current show
- **WebSocket**: Real-time metadata connection state
- **Worker**: Worker process status and PID
- **FFmpeg**: Encoding process status and uptime
- **Twitch**: Live status and current title
- **Scene**: Currently active scene
- **Video**: Current bitrate and FPS
- **Audio**: Audio bitrate and format
- **Dropped**: Dropped frame count
- **Reconnects**: FFmpeg restart count
- **Uptime**: Current session duration
- **Compliance**: Gate status

### Event Log
The event log shows all system events in real time:
- Twitch API calls
- RadioCult metadata events
- Track changes
- Scene transitions
- Schedule syncs
- FFmpeg lifecycle
- RTMP disconnections
- Token refreshes
- Admin overrides
- Errors and recoveries

### Track History
Full audit log of every detected track with:
- Title and artist
- Source (recognition, native, manual, correction)
- Recognition score
- Timestamp
- Dubplate/unknown flags

## Broadcast Modes

### Continuous 24/7 (Default)
- Worker stays live continuously
- Stream follows the RadioCult audio
- Automatic scene changes based on schedule
- Requires compliance approval

### Scheduled Show Mode
- Worker starts a configurable number of minutes before approved shows
- Stops after the show ends
- Useful for conserving resources

### Manual Mode
- Worker only starts when an admin clicks "Start"
- Stops when an admin clicks "Stop"
- Full manual control

## Twitch Channel Title Automation

The worker automatically updates the Twitch channel title when the show changes:
- `TOWERBLOCK RADIO — Slimzee`
- `TOWERBLOCK RADIO — N-Type | UK Underground Radio`
- `TOWERBLOCK RADIO — 24/7 Pirate Radio, Grime & Bass Culture`

Titles are truncated to 140 characters (Twitch limit).