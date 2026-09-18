const express = require("express");
const os = require("os");

const app = express();
const port = Number(process.env.PORT || 8080);
const message = process.env.APP_MESSAGE || "Hello from AKS via ArgoCD";

app.get("/healthz", (_req, res) => {
  res.status(200).json({ status: "ok" });
});

app.get("/", (_req, res) => {
  const hostname = os.hostname();
  const accept = String(_req.headers.accept || "");
  const payload = {
    message,
    hostname,
    timestamp: new Date().toISOString(),
  };

  if (accept.includes("application/json")) {
    res.json(payload);
    return;
  }

  res.type("html").send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>sample-web</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 2rem; background: #0f172a; color: #e2e8f0; }
    code { background: #1e293b; padding: 0.15rem 0.4rem; border-radius: 4px; }
  </style>
</head>
<body>
  <h1>${message}</h1>
  <p>Served by pod <code>${hostname}</code></p>
  <p><small>${payload.timestamp}</small></p>
</body>
</html>`);
});

app.listen(port, () => {
  console.log(`sample-web listening on :${port}`);
});
