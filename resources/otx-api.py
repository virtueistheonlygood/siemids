from flask import Flask, request, jsonify
from OTXv2 import OTXv2, IndicatorTypes

app = Flask(__name__)
API_KEY = '4daa2a9e13deb6172bb8c79e6768ca3ebb6ed1b7bf986bb594e5e0287cfbad4a'
otx = OTXv2(API_KEY)

@app.route('/threat_intel', methods=['GET'])
def threat_intel():
    ip = request.args.get('ip')
    if not ip:
        return jsonify({'error': 'No IP provided'}), 400
    result = otx.get_indicator_details_by_section(IndicatorTypes.IPv4, ip, 'general')
    return jsonify(result)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

