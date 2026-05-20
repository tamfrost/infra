const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Test Express App</title>
    </head>
    <body>
      <h1>Hello from Express!</h1>
      <p>This is a simple test application</p>
      <p>Request headers received:</p>
      <pre>${JSON.stringify(req.headers, null, 2)}</pre>
    </body>
    </html>
  `);
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Express app listening on port ${port}`);
});
