const VERSION = '1.0.0';
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const os = require('os');
const client = require('prom-client');

// OpenTelemetry
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { diag, DiagConsoleLogger, DiagLogLevel, trace } = require('@opentelemetry/api');

// OTEL diagnostics logs
diag.setLogger(new DiagConsoleLogger(), DiagLogLevel.INFO);

// Trace exporter configuration
const traceExporter = new OTLPTraceExporter({
  url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector.observability:4318/v1/traces'
});

// Initialize OpenTelemetry asynchronously
(async () => {
  try {
    const sdk = new NodeSDK({
      traceExporter,
      instrumentations: [getNodeAutoInstrumentations()],
    });
    await sdk.start();
    console.log("✅ OpenTelemetry SDK started");
  } catch (err) {
    console.error("❌ OTEL SDK error, continuing without tracing", err);
  }
})();

// Express app
const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Prometheus metrics
client.collectDefaultMetrics({ timeout: 5000 });
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
    service: 'NJ API',
    containerId: os.hostname(),
    node: process.env.NODE_NAME || 'unknown-node',
    clientIP: req.ip,
    method: req.method,
    url: req.url,
  });
});

// Main API endpoints
app.get('/api/data', (req, res) => {
  res.json({
    message: 'Welcome to NJ API!',
    data: {
      id: 1,
      name: 'NJ API Service',
      version: VERSION,
      timestamp: new Date().toISOString(),
    },
  });
});

app.get('/api/data/:id', (req, res) => {
  const { id } = req.params;
  res.json({
    message: `Details for ID: ${id}`,
    data: {
      id: parseInt(id),
      name: `Item ${id}`,
      description: 'This is a sample item',
    },
  });
});

app.post('/api/data', (req, res) => {
  const { name, description } = req.body;
  if (!name) return res.status(400).json({ error: 'Name is required' });

  res.status(201).json({
    message: 'Data created successfully',
    data: {
      id: Math.floor(Math.random() * 1000),
      name,
      description: description || 'No description',
      createdAt: new Date().toISOString(),
    },
  });
});

// OTEL test endpoint (simulate trace)
app.get('/api/test-otel', async (req, res) => {
  const tracer = trace.getTracer('njapi-tracer');
  tracer.startActiveSpan('test-span', async (span) => {
    try {
      await new Promise(resolve => setTimeout(resolve, 200));
      span.setAttribute('test-attribute', 'ok');
      span.addEvent('Test event');

      res.json({ message: '✅ OTEL trace simulated!' });
    } catch (err) {
      span.recordException(err);
      res.status(500).json({ error: '❌ Trace simulation failed' });
    } finally {
      span.end();
    }
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Start server
app.listen(PORT, () => {
  console.log(`NJ API server listening on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});

module.exports = app;