#include "../voice_ring_wave.h"
#include <iostream>
#include <cstdlib>

int main() {
  const auto& wave = VoiceRingWave();
  auto check = [](bool valid, const char* name) {
    if (!valid) { std::cerr << "FAIL: " << name << '\n'; std::exit(1); }
  };
  auto number = [&wave](std::size_t offset, int length) {
    std::uint32_t value = 0;
    for (int i = 0; i < length; ++i) value |= wave[offset + i] << (8 * i);
    return value;
  };
  check(wave.size() == 38444, "bounded 1.2 second buffer");
  check(std::string(wave.begin(), wave.begin() + 4) == "RIFF", "RIFF");
  check(std::string(wave.begin() + 8, wave.begin() + 12) == "WAVE", "WAVE");
  check(number(4, 4) + 8 == wave.size(), "RIFF size");
  check(number(20, 2) == 1 && number(22, 2) == 1, "mono PCM");
  check(number(24, 4) == 16000 && number(28, 4) == 32000, "sample rate");
  check(number(32, 2) == 2 && number(34, 2) == 16, "16-bit alignment");
  check(number(40, 4) + 44 == wave.size(), "data size");
  int peak = 0;
  int first = 0, second = 0;
  for (std::size_t i = 0; i < 19200; ++i) {
    const int sample = static_cast<std::int16_t>(number(44 + i * 2, 2));
    peak = (std::max)(peak, std::abs(sample));
    if (i < 6400 && sample != 0) ++first;
    else if (i >= 9600 && i < 16000 && sample != 0) ++second;
    else check(sample == 0, "silent intervals");
  }
  check(peak > 5000 && peak <= 11000, "audible non-clipping amplitude");
  check(first > 6000 && second > 6000, "both bursts present");
  check(&wave == &VoiceRingWave(), "stable asynchronous lifetime");
  std::cout << "Voice ringtone WAV checks PASS (not an audible device test)\n";
}
