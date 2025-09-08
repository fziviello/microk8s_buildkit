import os
import socket
import datetime
import time
from flask import Flask, jsonify, request
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST, CollectorRegistry, Counter, Histogram

# OpenTelemetry
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.trace import Status, StatusCode

# Environment variables
VERSION = os.getenv("APP_VERSION", "1.0.0")
SERVICE_NAME = os.getenv("SERVICE_NAME", "pyapi-python")
OTEL_COLLECTOR_ENDPOINT = os.getenv("OTEL_COLLECTOR", "http://otel-collector:4318/v1/traces")
APP_PORT = int(os.getenv("APP_PORT", "4000"))

# Flask app
app = Flask(__name__)

# OpenTelemetry setup with resiliency
tracer = None
try:
    resource = Resource.create({
        "service.name": SERVICE_NAME,
        "service.version": VERSION,
        "host.name": socket.gethostname(),
    })

    trace.set_tracer_provider(TracerProvider(resource=resource))
    tracer = trace.get_tracer(__name__)

    otlp_exporter = OTLPSpanExporter(endpoint=OTEL_COLLECTOR_ENDPOINT)
    span_processor = BatchSpanProcessor(otlp_exporter)
    trace.get_tracer_provider().add_span_processor(span_processor)

    FlaskInstrumentor().instrument_app(app)
    RequestsInstrumentor().instrument()

    print("✅ OpenTelemetry SDK started successfully")

except Exception as err:
    tracer = None
    print(f"❌ OTEL SDK error, continuing without tracing: {err}")

# Prometheus metrics
registry = CollectorRegistry()
REQUEST_COUNT = Counter(
    "http_requests_total", "Total HTTP Requests", ["method", "endpoint", "status"], registry=registry
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds", "HTTP request latency", ["method", "endpoint"], registry=registry
)

# Metrics endpoint
@app.route("/metrics")
def metrics():
    return generate_latest(registry), 200, {"Content-Type": CONTENT_TYPE_LATEST}

# Health check
@app.route("/health")
def health():
    with REQUEST_LATENCY.labels("GET", "/health").time():
        REQUEST_COUNT.labels("GET", "/health", "200").inc()
        return jsonify({
            "status": "OK",
            "version": VERSION,
            "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
            "service": SERVICE_NAME,
            "containerId": socket.gethostname(),
            "node": os.getenv("NODE_NAME", "unknown-node"),
            "clientIP": request.remote_addr,
            "method": request.method,
            "url": request.url,
        })

# Get all data
@app.route("/api/data")
def get_data():
    with REQUEST_LATENCY.labels("GET", "/api/data").time():
        REQUEST_COUNT.labels("GET", "/api/data", "200").inc()
        return jsonify({
            "message": "Welcome pyapi!",
            "data": {
                "id": 1,
                "name": SERVICE_NAME,
                "version": VERSION,
                "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
            },
        })

# Get data by ID
@app.route("/api/data/<int:item_id>")
def get_data_by_id(item_id):
    with REQUEST_LATENCY.labels("GET", f"/api/data/{item_id}").time():
        REQUEST_COUNT.labels("GET", f"/api/data/{item_id}", "200").inc()
        return jsonify({
            "message": f"Details for ID: {item_id}",
            "data": {
                "id": item_id,
                "name": f"Item {item_id}",
                "description": "This is a sample Python item",
            },
        })

# Create new data
@app.route("/api/data", methods=["POST"])
def create_data():
    with REQUEST_LATENCY.labels("POST", "/api/data").time():
        data = request.get_json()

        if not data or "name" not in data:
            REQUEST_COUNT.labels("POST", "/api/data", "400").inc()
            return jsonify({"error": "Name is required"}), 400

        REQUEST_COUNT.labels("POST", "/api/data", "201").inc()
        return jsonify({
            "message": "Data created successfully",
            "data": {
                "id": os.urandom(4).hex(),
                "name": data["name"],
                "description": data.get("description", "No description"),
                "createdAt": datetime.datetime.utcnow().isoformat() + "Z",
            },
        }), 201

# OTEL test endpoint (simulate trace)
@app.route("/api/test-otel")
def test_otel():
    if tracer is None:
        return jsonify({"error": "OTEL tracer not available"}), 503

    with tracer.start_as_current_span("test-span") as span:
        try:
            time.sleep(0.2)  # simulate some work
            span.set_attribute("test-attribute", "ok")
            span.add_event("Test event")
            return jsonify({"message": "✅ OTEL trace simulated!"})
        except Exception as e:
            span.record_exception(e)
            span.set_status(Status(StatusCode.ERROR, str(e)))
            return jsonify({"error": "❌ Trace simulation failed"}), 500

# Error handlers
@app.errorhandler(404)
def not_found(error):
    REQUEST_COUNT.labels(request.method, request.path, "404").inc()
    return jsonify({"error": "Endpoint not found"}), 404

@app.errorhandler(500)
def internal_error(error):
    REQUEST_COUNT.labels(request.method, request.path, "500").inc()
    return jsonify({
        "error": "Internal server error",
        "details": str(error)
    }), 500

# Entry point
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=APP_PORT, debug=False)
