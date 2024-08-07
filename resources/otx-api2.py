from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/threat_intel', methods=['GET'])
def threat_intel():
    ip = request.args.get('ip')
    if ip:
        # Mock response for testing
        return jsonify({
            'ip': ip,
            'threat_level': 'high',
            'description': 'This IP is known for malicious activities.'
        })
    else:
        return jsonify({'error': 'No IP provided'}), 400

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

