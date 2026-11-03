#ifndef SUBNETDESK_VOICE_RING_WAVE_H_
#define SUBNETDESK_VOICE_RING_WAVE_H_

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <vector>

// App-owned mono PCM: two gently ramped telephone-tone bursts, then silence.
// Static lifetime is required while PlaySound's asynchronous reader uses it.
inline const std::vector<std::uint8_t>& VoiceRingWave() {
  static const auto wave = [] {
    constexpr std::uint32_t rate = 16000;
    constexpr std::uint32_t samples = rate * 6 / 5;
    std::vector<std::uint8_t> bytes;
    bytes.reserve(44 + samples * 2);
    auto text = [&bytes](const char* value) {
      for (int i = 0; i < 4; ++i) bytes.push_back(value[i]);
    };
    auto number = [&bytes](std::uint32_t value, int length) {
      for (int i = 0; i < length; ++i) {
        bytes.push_back(static_cast<std::uint8_t>(value >> (8 * i)));
      }
    };
    text("RIFF"); number(36 + samples * 2, 4); text("WAVE");
    text("fmt "); number(16, 4); number(1, 2); number(1, 2);
    number(rate, 4); number(rate * 2, 4); number(2, 2); number(16, 2);
    text("data"); number(samples * 2, 4);
    constexpr double pi = 3.14159265358979323846;
    for (std::uint32_t i = 0; i < samples; ++i) {
      const double t = static_cast<double>(i) / rate;
      const double burst = t < 0.6 ? t : t - 0.6;
      double gain = 0;
      if (burst < 0.4) {
        gain = (std::min)(1.0, (std::min)(burst / 0.01, (0.4 - burst) / 0.01));
      }
      const auto sample = static_cast<std::int16_t>(gain * 5500 *
          (std::sin(2 * pi * 440 * t) + std::sin(2 * pi * 480 * t)));
      number(static_cast<std::uint16_t>(sample), 2);
    }
    return bytes;
  }();
  return wave;
}

#endif
