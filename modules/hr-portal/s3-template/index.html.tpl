<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>HR Portal</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
</head>
<body>
  <h1>HR Portal (Static)</h1>
  <p>This is a placeholder page served from S3.</p>

  <script>
    
    const apiBase = "http://${apiBase}";
    async function ping() {
      try {
        const res = await fetch(`${apiBase}/api/health`);
        console.log("API status:", await res.text());
      } catch (e) { console.error(e); }
    }
    ping();
  </script>
</body>
</html>
