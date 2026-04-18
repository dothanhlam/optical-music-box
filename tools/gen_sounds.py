"""
Generate 5 simple pentatonic WAV files (sine waves) for the Optical Music Box.
Notes: C4=261.63, D4=293.66, E4=329.63, G4=392.00, A4=440.00 Hz
"""
import struct
import math
import os

SAMPLE_RATE = 44100
DURATION = 0.5  # seconds
AMPLITUDE = 0.7
OUTPUT_DIR = "assets/sounds"

notes = {
    "note_c4": 261.63,
    "note_d4": 293.66,
    "note_e4": 329.63,
    "note_g4": 392.00,
    "note_a4": 440.00,
}

def make_wav(filename, freq):
    num_samples = int(SAMPLE_RATE * DURATION)
    with open(filename, "wb") as f:
        # WAV header
        data_size = num_samples * 2  # 16-bit mono
        f.write(b"RIFF")
        f.write(struct.pack("<I", 36 + data_size))
        f.write(b"WAVE")
        f.write(b"fmt ")
        f.write(struct.pack("<I", 16))          # chunk size
        f.write(struct.pack("<H", 1))           # PCM
        f.write(struct.pack("<H", 1))           # mono
        f.write(struct.pack("<I", SAMPLE_RATE))
        f.write(struct.pack("<I", SAMPLE_RATE * 2))
        f.write(struct.pack("<H", 2))           # block align
        f.write(struct.pack("<H", 16))          # bits per sample
        f.write(b"data")
        f.write(struct.pack("<I", data_size))
        # Samples with exponential decay envelope
        for i in range(num_samples):
            t = i / SAMPLE_RATE
            envelope = math.exp(-4.0 * t)       # natural decay
            sample = AMPLITUDE * envelope * math.sin(2 * math.pi * freq * t)
            pcm = int(sample * 32767)
            pcm = max(-32768, min(32767, pcm))
            f.write(struct.pack("<h", pcm))

os.makedirs(OUTPUT_DIR, exist_ok=True)
for name, freq in notes.items():
    path = os.path.join(OUTPUT_DIR, f"{name}.wav")
    make_wav(path, freq)
    print(f"  Generated {path}  ({freq:.2f} Hz)")

print("Done!")
