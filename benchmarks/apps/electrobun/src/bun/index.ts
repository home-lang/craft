import Electrobun from "electrobun/bun";

const isBenchmark = process.env.BENCHMARK === "1";

const win = new Electrobun.BrowserWindow({
  title: "Hello World",
  url: `data:text/html,${encodeURIComponent(`<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Hello World</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
      background: #1a1a2e;
      color: #e0e0e0;
    }
    h1 { font-size: 2rem; font-weight: 600; }
  </style>
</head>
<body>
  <h1>Hello World</h1>
</body>
</html>`)}`,
  frame: { width: 400, height: 300, x: 100, y: 100 },
});

if (isBenchmark) {
  setTimeout(() => {
    process.stdout.write("ready\n");
    Electrobun.Utils.quit();
  }, 50);
}
