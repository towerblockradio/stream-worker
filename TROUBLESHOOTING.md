# Tower Block Radio — Troubleshooting Guide

## Worker Won't Start

### Symptom: Worker shows "Offline" in dashboard

1. **Check if Docker container is running**
   ```bash
   docker ps | grep towerblock-stream-worker
   ```
   If not running:
   ```bash
   cd stream-worker
   docker-compose up -d --build
   ```

2. **Check container logs**
   ```bash
   docker logs towerblock-stream-worker --tail 50
   ```

3. **Verify health endpoint**
   ```bash
   curl http://localhost:3100/health
   ```
   Should return `{"status":"ok","ready":true}`

4. **Check worker base URL in settings**
   - Must be reachable from the Base44 backend
   - Must include the port (default 3100)
   - Must include `http://` or `https://`

5. **Check auth token matches**
   - `WORKER_AUTH_TOKEN` in `.env` must match `worker_auth_token` in BroadcastSettings

### Symptom: Container starts but immediately exits

1. **Check if FFmpeg is installed**
   ```bash
   docker exec towerblock-stream-worker ffmpeg -version
   ```
   The Dockerfile installs FFmpeg, but verify it wasn't corrupted.

2. **Check environment variables**
   ```bash
   docker exec towerblock-stream-worker env | grep -E 'STREAM_URL|RADIOCULT|TWITCH'
   ```

3. **Check logs for errors**
   ```bash
   docker logs towerblock-stream-worker
   ```

## FFmpeg Issues

### Symptom: FFmpeg exits immediately

1. **Verify RadioCult stream is online**
   ```bash
   curl -I https://tower-block-radio-92b23f22.radiocult.fm/stream
   ```
   Should return HTTP 200.

2. **Check stream URL in settings**
   - Must be the full stream URL including `https://`

3. **Check Twitch stream key**
   - The worker fetches the stream key from the control plane
   - Ensure Twitch OAuth is connected and token is not expired
   - Check event log for "stream key" errors

4. **Check RTMP ingest server**
   - Default: `rtmp://live.twitch.tv/app/`
   - For auto-selection, see [Twitch ingest testers](https://twitchinsights.net/ingests)

### Symptom: High dropped frames

1. **Reduce video bitrate**
   - Lower in Broadcast Settings (e.g. from 6000 to 4500)
   - The worker applies changes on next FFmpeg restart

2. **Check VPS network**
   ```bash
   # Test bandwidth to Twitch
   ffmpeg -f lavfi -i testsrc2=size=1920x1080:rate=30 -f lavfi -i sine -c:v libx264 -b:v 6000k -f flv rtmp://live.twitch.tv/app/TEST_KEY
   ```

3. **Use Twitch test mode**
   - Click "Enter Test Mode" in the dashboard
   - This uses Twitch's test ingest without going live publicly

### Symptom: No audio in stream

1. **Verify RadioCult stream has audio**
   - Listen to the stream URL directly in a browser

2. **Check audio bitrate setting**
   - Must be > 0 (default 160 kbps)

3. **Check FFmpeg audio mapping**
   - The worker maps `0:a` (audio from input 0 = RadioCult stream)

## Metadata Issues

### Symptom: Track shows "Track ID Pending" constantly

This is expected behaviour when:
- RadioCult music recognition is not available
- The track is a dubplate or unreleased
- The recognition score is below the threshold (default 78)

**To resolve:**
1. Check if RadioCult recognition is enabled in your station settings
2. Lower the recognition threshold in Broadcast Settings (not recommended below 70)
3. Use "Correct Track" to manually enter the track info

### Symptom: Track changes too rapidly (flickering)

The track debouncer requires two consistent recognition results before switching.
If flickering persists:
1. Increase `track_confirmation_seconds` in settings (default 12, max 15)
2. Increase `recognition_threshold` (default 78)

### Symptom: WebSocket shows "Polling"

The worker falls back to 15-second REST polling when the Socket.IO connection fails.
This is normal during:
- RadioCult API maintenance
- Network issues between worker and RadioCult

The worker will automatically reconnect to WebSocket when available.

## Twitch API Issues

### Symptom: "Twitch schedule API unavailable"

Twitch schedule segments require Affiliate or Partner status.
If your account doesn't have this:
- Schedule sync will show warnings in the event log
- Channel title automation still works
- On-screen schedule display still works

### Symptom: Token expired

1. Click "Refresh Token" in the Twitch Connection card
2. If refresh fails, disconnect and reconnect:
   - Click "Disconnect"
   - Click "Connect Twitch"
   - Authorize again on Twitch

### Symptom: "Failed to get stream key"

The stream key requires the `channel:read:stream_key` scope.
1. Disconnect Twitch
2. Reconnect with full scopes
3. The OAuth flow requests all required scopes

## Artwork Generation

### Symptom: Artwork generation fails

1. **Check source portrait URL**
   - Must be a valid image URL
   - Must be accessible from the Base44 backend

2. **Check rights confirmation**
   - The DJ profile must have `rights_confirmed` set to true
   - Artwork cannot be generated without rights confirmation

3. **Check no-AI option**
   - If `no_ai_option` is true, the system uses `official_artwork_url` instead
   - Ensure `official_artwork_url` is set

### Symptom: Artwork not appearing on stream

Artwork must be **approved** before use:
1. Go to DJ Artwork section
2. Click "Approve" on pending assets
3. The worker fetches approved assets on next state refresh

## Recovery Procedures

### Stream Loss Recovery

The worker automatically:
1. Detects stream loss within 10 seconds
2. Switches to "Signal Interrupted" scene
3. Retries connection with exponential backoff (2s, 4s, 8s, 16s, 32s, 60s)
4. Returns to normal scene when stream recovers
5. Logs all events

If the stream does not recover after 10 attempts, the worker enters emergency mode.

### FFmpeg Restart

The worker automatically restarts FFmpeg if:
- The process exits unexpectedly
- The watchdog detects no output
- A manual restart is triggered

Restart logic:
1. Wait 5 seconds
2. Re-fetch stream key (in case it rotated)
3. Restart FFmpeg with same settings
4. Log the restart

### Worker Container Restart

Docker restart policy is `unless-stopped`:
- Container restarts on failure
- Container does NOT restart if explicitly stopped

To manually restart:
```bash
docker restart towerblock-stream-worker
```

## Stream Key Rotation

To rotate the Twitch stream key:
1. Go to [Twitch Dashboard → Settings → Stream](https://dashboard.twitch.tv/settings/stream)
2. Click "Reset" next to the stream key
3. The worker will automatically fetch the new key on next broadcast start
4. If currently broadcasting, restart the worker:
   - Click "Restart Worker" in the dashboard
   - Or: `docker restart towerblock-stream-worker`

## Log Analysis

### Where to find logs

**Worker logs (on VPS):**
```bash
docker logs towerblock-stream-worker
# Or specific file:
docker exec towerblock-stream-worker cat /app/logs/worker.log | tail 100
```

**Control plane logs (in dashboard):**
- Event Log panel shows all events logged by the worker
- Track History shows all detected tracks

### Common log patterns

| Pattern | Meaning | Action |
|---------|---------|--------|
| `FFmpeg exited` | Process crashed or stopped | Check if auto-restart succeeded |
| `Stream loss detected` | RadioCult stream unavailable | Check RadioCult status |
| `Stream recovered` | Stream back online | No action needed |
| `Token refresh` | Twitch OAuth token refreshed | No action needed |
| `Token refresh failed` | Cannot refresh Twitch token | Reconnect Twitch OAuth |
| `Track confirmed` | New track recognised and displayed | No action needed |
| `Track rejected - below threshold` | Recognition score too low | Manually correct if needed |
| `Schedule sync complete` | RadioCult → Twitch sync done | No action needed |
| `Emergency mode` | Critical failure | Restart worker immediately |

## Getting Help

If issues persist:
1. Collect the worker logs: `docker logs towerblock-stream-worker > worker-debug.log`
2. Note the timestamp of the issue
3. Check the Event Log in the dashboard for corresponding entries
4. Contact Base44 support with the logs and timestamps