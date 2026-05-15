# Frontend Website

Static HTML, CSS, and JavaScript frontend for the Tibia Guild Analytics project.

The frontend calls the FastAPI backend and displays guild snapshot analytics in the browser.

## Local Setup

Before running the frontend, make sure the backend API is running.

From the project root:

```bash
source backend/.venv/bin/activate
uvicorn app.main:app --reload --app-dir backend
```

The backend should be available at:

```text
http://127.0.0.1:8000
```

## Run the Frontend

Open a second terminal.

From the project root:

```bash
cd frontend
python3 -m http.server 3000
```

Then open:

```text
http://localhost:3000
```

## API Dependency

The frontend currently expects the API to be running at:

```text
http://127.0.0.1:8000
```

This is configured in:

```text
frontend/app.js
```

```javascript
const API_BASE_URL = "http://127.0.0.1:8000";
```

## Displayed Data

The frontend currently displays:

```text
Summary metrics
Snapshot window
Character level changes
Guild joins
Guild leaves
Rank changes
```

## Notes

This frontend is currently a local static website. In a later phase, it can be served through a frontend container, deployed to a hosting platform, and connected to a custom domain.