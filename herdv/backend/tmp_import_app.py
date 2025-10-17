import sys, traceback
sys.path.insert(0, r'E:/applications/finalapp/herdv')
try:
    import app
    print('Imported app OK')
except Exception as e:
    traceback.print_exc()
    print('IMPORT ERROR:', e)
