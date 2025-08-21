import io
import json
import os

import requests
from flask import Flask, request, send_file, send_from_directory

STATIC_DIR = os.path.join(os.path.dirname(__file__), 'deploy', 'github-app')

app = Flask(
    __name__,
    static_folder=STATIC_DIR,
    static_url_path=''
)

GITHUB_API = 'https://api.github.com'


@app.route('/', methods=['GET'])
def register_page():
    return send_from_directory(STATIC_DIR, 'register.html')


@app.route('/app-manifest.json', methods=['GET'])
def manifest():
    return send_from_directory(STATIC_DIR, 'app-manifest.json', mimetype='application/json')


@app.route('/oauth/callback', methods=['GET'])
def oauth_callback():
    code = request.args.get('code')
    if not code:
        return "Missing 'code' parameter", 400

    url = f'{GITHUB_API}/app-manifests/{code}/conversions'
    headers = {'Accept': 'application/vnd.github.v3+json'}
    resp = requests.post(url, headers=headers)

    if resp.status_code != 201:
        return f'Error converting manifest: {resp.status_code} {resp.text}', 500

    data = resp.json()

    json_bytes = io.BytesIO(json.dumps(data, indent=2).encode('utf-8'))

    return send_file(
        json_bytes,
        mimetype='application/json',
        as_attachment=True,
        download_name='forge-github-app.json'
    )


if __name__ == '__main__':
    host = os.environ.get('HOST', '0.0.0.0')
    port = int(os.environ.get('PORT', 5000))
    app.run(host=host, port=port)
