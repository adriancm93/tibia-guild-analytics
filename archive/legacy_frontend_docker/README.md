# Legacy Frontend Dockerfile

This folder contains the earlier Dockerfile used to serve the static frontend in a container.

It is no longer part of the current production deployment.

Current production frontend hosting runs through:

```text
Cloudflare Pages
        ↓
Static HTML/CSS/JavaScript from frontend/
```

The active `frontend/` folder is still the production website source.

This Dockerfile is archived for historical reference only and should not be used as the current production frontend deployment path.
