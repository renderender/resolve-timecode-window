"""Package the generated PNG icon sizes into a macOS ICNS container."""
import struct
from pathlib import Path

entries = [("icp4", "16x16"), ("icp5", "32x32"), ("icp6", "32x32@2x"),
           ("ic07", "128x128"), ("ic08", "256x256"),
           ("ic09", "512x512"), ("ic10", "512x512@2x")]
chunks = []
for kind, name in entries:
    data = Path(f"build/AppIcon.iconset/icon_{name}.png").read_bytes()
    chunks.append(kind.encode("ascii") + struct.pack(">I", len(data) + 8) + data)
payload = b"".join(chunks)
Path("dist/Resolve Timecode Window.app/Contents/Resources/AppIcon.icns").write_bytes(
    b"icns" + struct.pack(">I", len(payload) + 8) + payload
)
