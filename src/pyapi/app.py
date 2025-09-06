from flask import Flask, jsonify, request
import socket
import datetime
import os
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST, CollectorRegistry, Counter, Histogram

VERSION = '1.0.0'
app = Flask(__name__)

# Metrics setup
registry = CollectorRegistry()
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP Requests', ['method', 'endpoint', 'status'], registry=registry)
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'HTTP request latency', ['method', 'endpoint'], registry=registry)

@app.route('/metrics')
def metrics():
    return generate_latest(registry), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/health')
def health():
    with REQUEST_LATENCY.labels('GET', '/health').time():
        REQUEST_COUNT.labels('GET', '/health', '200').inc()
        return jsonify({
            'status': 'OK',
            'version': VERSION,
            'timestamp': datetime.datetime.utcnow().isoformat() + 'Z',
            'service': 'pyapi-Python',
            'containerId': socket.gethostname(),
            'node': os.getenv('NODE_NAME', 'unknown-node'),
            'clientIP': request.remote_addr,
            'method': request.method,
            'url': request.url
        })

@app.route('/api/data')
def get_data():
    with REQUEST_LATENCY.labels('GET', '/api/data').time():
        REQUEST_COUNT.labels('GET', '/api/data', '200').inc()
        return jsonify({
            'message': 'Benvenuto in pyapi Python!',
            'data': {
                'id': 1,
                'name': 'pyapi Python Service',
                'version': VERSION,
                'timestamp': datetime.datetime.utcnow().isoformat() + 'Z'
            }
        })

@app.route('/api/data/<int:id>')
def get_data_by_id(id):
    with REQUEST_LATENCY.labels('GET', f'/api/data/{id}').time():
        REQUEST_COUNT.labels('GET', f'/api/data/{id}', '200').inc()
        return jsonify({
            'message': f'Dettagli per ID: {id}',
            'data': {
                'id': id,
                'name': f'Item {id}',
                'description': 'Questo è un elemento di esempio Python'
            }
        })

@app.route('/api/data', methods=['POST'])
def create_data():
    with REQUEST_LATENCY.labels('POST', '/api/data').time():
        data = request.get_json()
        
        if not data or 'name' not in data:
            REQUEST_COUNT.labels('POST', '/api/data', '400').inc()
            return jsonify({'error': 'Name è obbligatorio'}), 400
        
        REQUEST_COUNT.labels('POST', '/api/data', '201').inc()
        return jsonify({
            'message': 'Dato creato con successo',
            'data': {
                'id': os.urandom(4).hex(),
                'name': data['name'],
                'description': data.get('description', 'Nessuna descrizione'),
                'createdAt': datetime.datetime.utcnow().isoformat() + 'Z'
            }
        }), 201

@app.errorhandler(404)
def not_found(error):
    REQUEST_COUNT.labels(request.method, request.path, '404').inc()
    return jsonify({'error': 'Endpoint non trovato'}), 404

@app.errorhandler(500)
def internal_error(error):
    REQUEST_COUNT.labels(request.method, request.path, '500').inc()
    return jsonify({'error': 'Errore interno del server'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=4000, debug=False)