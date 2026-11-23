import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const webDir = path.join(repoRoot, "frontend-flutter", "build", "web");
const port = Number(process.env.FLUTTER_WEB_PORT || 5175);
const host = process.env.FLUTTER_WEB_HOST || "127.0.0.1";

const MIME_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".mjs": "application/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".wasm": "application/wasm",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".frag": "text/plain; charset=utf-8",
};

if (!fs.existsSync(path.join(webDir, "index.html"))) {
  console.error(
    `[serve-flutter-web] Missing build output at ${webDir}. Run "flutter build web" in frontend-flutter first.`,
  );
  process.exit(1);
}

const server = http.createServer((req, res) => {
  const reqUrl = new URL(req.url || "/", `http://${host}:${port}`);
  let relPath = decodeURIComponent(reqUrl.pathname);
  if (relPath === "/") relPath = "/index.html";

  const candidate = path.normalize(path.join(webDir, relPath));
  let filePath = candidate;
  if (!candidate.startsWith(webDir) || !fs.existsSync(candidate) || fs.statSync(candidate).isDirectory()) {
    filePath = path.join(webDir, "index.html");
  }

  const ext = path.extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || "application/octet-stream";

  res.writeHead(200, {
    "Content-Type": contentType,
    "Cache-Control": ext === ".html" ? "no-cache" : "public, max-age=300",
  });
  fs.createReadStream(filePath).pipe(res);
});

server.listen(port, host, () => {
  console.log(`[serve-flutter-web] Serving ${webDir} at http://${host}:${port}/`);
});
