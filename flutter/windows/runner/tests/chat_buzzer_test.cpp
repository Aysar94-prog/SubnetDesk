#include "../alert_audio_owner.h"
#include "../chat_buzzer_wave.h"
#include <cstdlib>
#include <iostream>
#include <string>

int main() {
  auto check = [](bool valid, const char* name) {
    if (!valid) { std::cerr << "FAIL: " << name << '\n'; std::exit(1); }
  };
  const auto& wave = ChatBuzzerWave();
  auto number = [&wave](std::size_t offset, int length) {
    std::uint32_t value = 0;
    for (int i = 0; i < length; ++i)
      value |= static_cast<std::uint32_t>(wave[offset + i]) << (8 * i);
    return value;
  };
  check(wave.size() == 19244, "bounded 0.6 seconds");
  check(std::string(wave.begin(), wave.begin() + 4) == "RIFF", "RIFF");
  check(std::string(wave.begin() + 8, wave.begin() + 12) == "WAVE", "WAVE");
  check(number(4, 4) + 8 == wave.size(), "RIFF size");
  check(number(20, 2) == 1 && number(22, 2) == 1, "mono PCM");
  check(number(24, 4) == 16000 && number(28, 4) == 32000, "sample rate");
  check(number(32, 2) == 2 && number(34, 2) == 16, "16 bit alignment");
  check(number(40, 4) + 44 == wave.size(), "data size");
  int peak = 0, first = 0, second = 0;
  for (std::size_t i = 0; i < 9600; ++i) {
    const int sample = static_cast<std::int16_t>(number(44 + i * 2, 2));
    peak = (std::max)(peak, std::abs(sample));
    if (i < 3520 && sample != 0) ++first;
    else if (i >= 4800 && i < 8320 && sample != 0) ++second;
    else check(sample == 0, "silent gaps");
  }
  check(peak > 9000 && peak <= 10000, "non-clipping amplitude");
  check(first > 3300 && second > 3300, "both notes");
  check(&wave == &ChatBuzzerWave(), "stable async storage");

  using Tone = AlertAudioOwner::Tone;
  using Playback = AlertAudioOwner::Playback;
  AlertAudioOwner owner;
  int plays = 0, stops = 0;
  auto play = [&] { ++plays; return true; };
  auto stop = [&] { ++stops; return true; };
  check(owner.StopAll(stop) && stops == 0, "idle destruction does not stop output");
  check(owner.Start(Tone::Buzzer, [] { return false; }) == Playback::Failed, "play error");
  check(owner.StopOwned(Tone::Buzzer, stop) && stops == 0, "failed play owns nothing");
  check(owner.Start(Tone::Buzzer, play) == Playback::Started, "buzzer starts");
  check(owner.Start(Tone::Voice, play) == Playback::Started, "voice preempts buzzer");
  check(owner.Start(Tone::Buzzer, play) == Playback::Suppressed && plays == 2, "voice priority, no queue");
  check(owner.StopOwned(Tone::Buzzer, stop) && stops == 0, "mute/dispose buzzer never stops voice");
  check(!owner.StopOwned(Tone::Voice, [] { return false; }), "stop error");
  check(owner.Start(Tone::Buzzer, play) == Playback::Suppressed, "failed stop retains voice priority");
  check(owner.StopOwned(Tone::Voice, stop) && stops == 1, "voice clears");
  check(plays == 2, "no delayed stale buzzer");
  check(owner.Start(Tone::Buzzer, play) == Playback::Started, "new buzzer after voice");
  check(owner.Start(Tone::Voice, [] { return false; }) == Playback::Failed, "failed preemption");
  check(owner.StopOwned(Tone::Voice, stop) && stops == 1, "failed voice cannot stop buzzer");
  check(owner.StopAll(stop) && stops == 2, "destruction stops owned buzzer");
  std::cout << "Buzzer PCM and audio ownership checks PASS (not an audible device test)\n";
}
