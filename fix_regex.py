path = r'f:\Programation\QR & Barcode apk\smartscan_app\lib\utils\security_helper.dart'

with open(path, 'rb') as f:
    content = f.read()

# Find one of the regex lines and show hex
idx = content.find(b"RegExp(r'")
chunk = content[idx:idx+60]
print("Hex dump of first RegExp line:")
print(' '.join(f'{b:02x}' for b in chunk))
print("ASCII:", chunk.decode('utf-8', errors='replace'))

# Check: does the file have \b (5c 62) or \\b (5c 5c 62)?
if b'\\\\b' in content:
    print("\nFile contains \\\\b (double backslash + b) - WRONG")
elif b'\\b' in content:
    print("\nFile contains \\b (single backslash + b) - CORRECT")
