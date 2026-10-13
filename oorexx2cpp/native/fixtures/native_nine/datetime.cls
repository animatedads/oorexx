::class NativeNineProbe public
::method run
  d = .datetime~new(2020,2,29)
  a = d~year d~month d~day d~isleapyear d~isodate
  return a '|' d~year d~month d~day d~isodate
