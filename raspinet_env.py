import json

with open('geoip/localnet.json', 'r') as f:
    config = json.load(f)

with open('env/localnet.env', 'w') as f:
    for key, value in config.items():
        if isinstance(value, dict):
            for subkey, subvalue in value.items():
                f.write(f'{key}_{subkey.upper()}={subvalue}\n')
        else:
            f.write(f'{key.upper()}={value}\n')

with open('geoip/ovpnnet.json', 'r') as f:
    config = json.load(f)

with open('env/ovpnnett.env', 'w') as f:
    for key, value in config.items():
        if isinstance(value, dict):
            for subkey, subvalue in value.items():
                f.write(f'{key}_{subkey.upper()}={subvalue}\n')
        else:
            f.write(f'{key.upper()}={value}\n')

with open('geoip/pianet.json', 'r') as f:
    config = json.load(f)

with open('env/pianet.env', 'w') as f:
    for key, value in config.items():
        if isinstance(value, dict):
            for subkey, subvalue in value.items():
                f.write(f'{key}_{subkey.upper()}={subvalue}\n')
        else:
            f.write(f'{key.upper()}={value}\n')

