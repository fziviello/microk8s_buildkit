const VERSION = '1.0.0';
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const os = require('os');
const client = require('prom-client');

// Metrics setup
const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics({ timeout: 5000 });

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'OK',
    version: VERSION,
    timestamp: new Date().toISOString(),
    service: 'NJ Api',
    containerId: os.hostname(),
    node: process.env.NODE_NAME || 'unknown-node',
    clientIP: req.ip,
    method: req.method,
    url: req.url,
  });
});

// Main API endpoint
app.get('/api/data', (req, res) => {
  res.json({
    message: 'Benvenuto in NJApi!',
    data: {
      id: 1,
      name: 'NJApi Service',
      version: VERSION,
      timestamp: new Date().toISOString()
    }
  });
});

// Get with parameter
app.get('/api/data/:id', (req, res) => {
  const { id } = req.params;
  res.json({
    message: `Dettagli per ID: ${id}`,
    data: {
      id: parseInt(id),
      name: `Item ${id}`,
      description: 'Questo è un elemento di esempio'
    }
  });
});

// Post endpoint
app.post('/api/data', (req, res) => {
  const { name, description } = req.body;
  
  if (!name) {
    return res.status(400).json({ error: 'Name è obbligatorio' });
  }

  res.status(201).json({
    message: 'Dato creato con successo',
    data: {
      id: Math.floor(Math.random() * 1000),
      name,
      description: description || 'Nessuna descrizione',
      createdAt: new Date().toISOString()
    }
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Errore interno del server' });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Endpoint non trovato' });
});

app.listen(PORT, () => {
  console.log(`NJ Api server in ascolto sulla porta ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});

module.exports = app;