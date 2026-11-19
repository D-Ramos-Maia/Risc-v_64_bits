import sys, struct
data = open(sys.argv[1], 'rb').read()
data += b'\0' * (-len(data) % 8)
with open('prog32.hex', 'w') as f:
    for i in range(0, len(data), 4):
        f.write('%08x\n' % struct.unpack('<I', data[i:i+4])[0])
with open('prog64.hex', 'w') as f:
    for i in range(0, len(data), 8):
        f.write('%016x\n' % struct.unpack('<Q', data[i:i+8])[0])