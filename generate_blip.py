import wave
import struct
import math

# Pengaturan audio
sample_rate = 44100.0
duration = 0.05 # durasi 50ms (sangat pendek)
frequency = 600.0 # frekuensi tinggi untuk efek "blip"
volume = 0.3

# Buat file wav
wave_file = wave.open("text_blip.wav", "w")
wave_file.setnchannels(1) # mono
wave_file.setsampwidth(2) # 16-bit
wave_file.setframerate(int(sample_rate))

# Generate data suara (Square wave untuk efek 8-bit)
for i in range(int(sample_rate * duration)):
    t = i / sample_rate
    # Square wave
    value = volume if math.sin(2 * math.pi * frequency * t) > 0 else -volume
    
    # Envelope: Fade out sangat cepat di akhir agar tidak ada suara "pop"
    fade_out_start = int(sample_rate * duration * 0.7)
    if i > fade_out_start:
        fade = 1.0 - (i - fade_out_start) / (sample_rate * duration * 0.3)
        value *= fade

    # Konversi ke 16-bit PCM
    data = struct.pack("<h", int(value * 32767.0))
    wave_file.writeframesraw(data)

wave_file.close()
print("File suara berhasil dibuat: text_blip.wav")
