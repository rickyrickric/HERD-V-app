import requests

url='http://127.0.0.1:8000/schema/validate'
origin='http://localhost:64324'
print('OPTIONS preflight...')
opt = requests.options(url, headers={'Origin': origin,'Access-Control-Request-Method':'POST'})
print(opt.status_code, opt.headers.get('access-control-allow-origin'))
print('\nPOSTing sample.csv...')
with open(r'e:\applications\cattleapp\sample.csv','rb') as f:
    r = requests.post(url, files={'file':('sample.csv',f,'text/csv')}, headers={'Origin': origin})
    print(r.status_code)
    try:
        print(r.json())
    except Exception as e:
        print('non-json response', r.text[:200])
