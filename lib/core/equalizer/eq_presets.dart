/// EQ band centre-frequency labels (displayed in UI).
const List<String> kEqBandLabels = ['60 Hz', '230 Hz', '910 Hz', '3.6 kHz', '14 kHz'];

/// Named EQ presets — each value is a list of 5 dB gains corresponding to
/// [60 Hz, 230 Hz, 910 Hz, 3.6 kHz, 14 kHz].
/// Range: −12.0 dB to +12.0 dB per band.
const Map<String, List<double>> kEqPresets = {
  'normal':    [ 0.0,  0.0,  0.0,  0.0,  0.0],
  'bassBoost': [ 7.0,  5.0,  0.0, -1.0, -1.0],
  'classical': [ 5.0,  3.0, -2.0,  3.0,  4.0],
  'pop':       [-1.0,  3.0,  5.0,  3.0, -1.0],
  'rock':      [ 5.0,  3.0, -1.0,  3.0,  5.0],
  'jazz':      [ 4.0,  2.0, -1.0,  2.0,  4.0],
};

/// Human-readable labels for each preset key.
const Map<String, String> kEqPresetLabels = {
  'normal':    'Normal',
  'bassBoost': 'Bass Boosted',
  'classical': 'Classical',
  'pop':       'Pop',
  'rock':      'Rock',
  'jazz':      'Jazz',
};

/// Ordered list of preset keys for display.
const List<String> kEqPresetOrder = [
  'normal',
  'bassBoost',
  'classical',
  'pop',
  'rock',
  'jazz',
];
