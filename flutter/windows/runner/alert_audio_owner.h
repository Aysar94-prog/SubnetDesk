#ifndef SUBNETDESK_ALERT_AUDIO_OWNER_H_
#define SUBNETDESK_ALERT_AUDIO_OWNER_H_

// PlaySound has one output slot. Keep a pending voice alert's priority, including
// its silent gaps, until Dart explicitly clears it. Never queue a stale buzzer.
class AlertAudioOwner {
 public:
  enum class Tone { None, Buzzer, Voice };
  enum class Playback { Started, Suppressed, Failed };

  template <typename Play>
  Playback Start(Tone tone, Play play) {
    if (tone == Tone::Buzzer && owner_ == Tone::Voice) return Playback::Suppressed;
    if (!play()) return Playback::Failed;
    owner_ = tone;
    return Playback::Started;
  }

  template <typename Stop>
  bool StopOwned(Tone tone, Stop stop) {
    if (owner_ == Tone::None || owner_ != tone) return true;
    if (!stop()) return false;
    owner_ = Tone::None;
    return true;
  }

  template <typename Stop>
  bool StopAll(Stop stop) { return StopOwned(owner_, stop); }

 private:
  Tone owner_ = Tone::None;
};

#endif
