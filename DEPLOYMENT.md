# Tower Block Radio — Stream Worker

Persistent broadcast worker that converts the Tower Block Radio audio stream into a professional, animated Twitch broadcast.

## Architecture

This worker runs on persistent Linux compute (dedicated VPS, container host, or long-running VM). It **cannot** run inside Base44 serverless functions — FFmpeg and RTMP require a continuous process.

```
┌──────────────────────────────────────────────────────────────┐
│  Base44 Control Plane (towerblock.radio)                     │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │ twitchOAuth │  │  twitchApi   │  │ radiocultBroadcast │  │
│  └─────────────┘  └──────────────┘  └────────────────────┘  │
│  ┌──────────────────┐  ┌─────────────────────────────────┐  │
│  │ broadcastControl │  │      generateDjArtwork          │  │
│  └──────────────────┘  └─────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ syncTwitchSchedule                                    │   │
│  └──────────────────────────────────────────────────────┘   │
└───────────────────────────┬──────────────────────────────────┘
                            │ HTTP (Bearer token auth)
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  Stream Worker (Docker on VPS)                               │
│  ┌──────────────┐  ┌─────────────┐  ┌────────────────────┐  │
│  │ Orchestrator │──│ FFmpeg Mgr  │  │  Metadata Client   │  │
│  └──────────────┘  └─────────────┘  └────────────────────┘  │
│  ┌──────────────┐  ┌─────────────┐  ┌────────────────────┐  │
│  │  Watchdog    │  │ Scene Mgr   │  │ Health Server      │  │
│  └──────────────┘  └─────────────┘  └────────────────────┘  │
│  ┌──────────────┐  ┌─────────────────────────────────────┐ │
│  │ TrackDebouncer│  │ Control Plane Client                │ │
│  └──────────────┘  └─────────────────────────────────────┘ │
│                                                               │
│  FFmpeg: RadioCult audio → 1080p H.264 + AAC → Twitch RTMP  │
└──────────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Prerequisites

- Linux VPS (Ubuntu 22.04+ recommended, minimum 2 vCPU / 4GB RAM)
- Docker and Docker Compose installed
- The stream worker files from `/stream-worker/` in your app

### 2. Configure Environment

```bash
cd stream-worker
cp .env.example .env
```

Edit `.env` and set:
- `WORKER_AUTH_TOKEN` — a secure random string (must match `worker_auth_token` in BroadcastSettings)
- `CONTROL_PLANE_URL` — your Base44 app URL (e.g. `https://towerblock.radio`)
- `RADIOCULT_STATION_ID` — your RadioCult station ID
- `RADIOCULT_SECRET_API_KEY` — your RadioCult secret API key
- Other values can use defaults

### 3. Configure Control Plane

In the admin dashboard at `/admin/twitch-broadcast`:
1. Set **Worker Base URL** to `http://YOUR_VPS_IP:3100`
2. Set **Worker Auth Token** to match the `WORKER_AUTH_TOKEN` in `.env`
3. Save settings

### 4. Deploy

```bash
docker-compose up -d --build
```

### 5. Verify

```bash
# Check health
curl http://localhost:3100/health

# Check status (requires auth token)
curl -H "Authorization: Bearer $WORKER_AUTH_TOKEN" http://localhost:3100/status
```

### 6. Start Broadcasting

From the admin dashboard:
1. Connect Twitch OAuth
2. Confirm compliance gate
3. Click "Start Broadcast"

## Health Endpoints

| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /health` | None | Basic liveness check |
| `GET /live` | None | Process alive check |
| `GET /ready` | None | Readiness check (returns 503 if not ready) |
| `GET /status` | Bearer token | Full worker status |
| `POST /control/start` | Bearer token | Start broadcast |
| `POST /control/stop` | Bearer token | Stop broadcast |
| `POST /control/restart` | Bearer token | Restart worker |
| `POST /control/emergency-stop` | Bearer token | Emergency stop |
| `POST /control/scene` | Bearer token | Change scene |
| `POST /control/correct-track` | Bearer token | Manual track correction |

## Testing

```bash
npm test
```

Tests cover:
- Track change debouncing (two consistent results required)
- Recognition threshold enforcement
- Duplicate track filtering
- Scene management and locking
- FFmpeg drawtext sanitization

## Logs

Logs are stored in `/app/logs/` (persisted via Docker volume):
- `worker.log` — all logs
- `error.log` — errors only

Logs are rotated at 50MB with 5 files retained.

## Recovery

The worker is designed for unattended operation:
- **Stream loss**: Detects RadioCult stream disconnects, switches to "Signal Interrupted" scene, retries with exponential backoff
- **FFmpeg crash**: Automatically restarts the FFmpeg process
- **Container failure**: Docker restart policy is `unless-stopped`
- **Metadata WebSocket disconnect**: Falls back to 15-second REST polling
- **Control plane unreachable**: Worker continues with last known scene and metadata

## File Structure

```
stream-worker/
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── package.json
├── DEPLOYMENT.md          ← this file
├── src/
│   ├── orchestrator.js    ← main entry point
│   ├── metadataClient.js  ← RadioCult Socket.IO + polling
│   ├── trackDebouncer.js  ← track change confirmation logic
│   ├── sceneManager.js    ← scene state and overlay generation
│   ├── ffmpeg.js          ← FFmpeg process management
│   ├── watchdog.js        ← stream health monitoring
│   ├── healthServer.js    ← HTTP health and control endpoints
│   ├── controlPlaneClient.js ← Base44 backend communication
│   ├── logger.js          ← structured JSON logging
│   └── test/
│       ├── trackDebouncer.test.js
│       └── sceneManager.test.js
└── assets/                ← generated at runtime (Docker volume)
    ├── cache/             ← overlay text files for FFmpeg
    ├── dj/                ← cached DJ artwork
    └── scenes/            ← pre-rendered scene backgrounds
``