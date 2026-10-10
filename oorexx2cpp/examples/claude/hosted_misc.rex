d = .DateTime~new(2024, 2, 29)
say d~year
say d~month
say d~day
say d~isoDate
say d~weekday
say 'date:' d~isoDate || '/' || d~weekday
e = .DateTime~fromIsoDate('2000-01-01T00:00:00.000000')
say e~isoDate e~weekday
signal on syntax name oops
x = .DateTime~new(2021, 13, 45)
say 'not reached'
exit
oops:
say 'trapped'
exit 3
