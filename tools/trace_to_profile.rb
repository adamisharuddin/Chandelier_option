# Turn the traced blue line (image px) into a 150-column depth profile t in [0,1] along 33 m.
#   ruby tools/trace_to_profile.rb data/option1_sketch_trace_px.txt
# Input: "x,y;x,y;..." pixel centres of the sketched line (docs/option1_client_sketch.png).
# Output: the PROFILE_1 array used in sketchup/chandelier_build.rb. X0/X1 = chandelier ends in that image.
pts = File.read(ARGV[0]).strip.split(';').map { |s| s.split(',').map(&:to_f) }.sort_by(&:first)
X0, X1 = 135.0, 1655.0                 # chandelier ends in the image (long view)
ytop = pts.map(&:last).min             # shallowest point of the drawn line
ybot = pts.map(&:last).max             # deepest point
to_m = ->(px) { (px - X0) / (X1 - X0) * 33.0 }
data = pts.map { |px, y| [to_m.(px), (y - ytop) / (ybot - ytop)] }
xa, xb = data.first[0], data.last[0]
interp = lambda do |x|
  i = data.bsearch_index { |d| d[0] >= x } || data.size - 1
  i = 1 if i < 1
  a, b = data[i - 1], data[i]
  b[0] == a[0] ? a[1] : a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])
end
ss = ->(t) { t = [[t, 0.0].max, 1.0].min; t * t * (3 - 2 * t) }
raw = (1..150).map do |c|
  x = 0.22 * (c - 0.5)
  if x < xa then interp.(xa) * ss.(x / xa)                      # undrawn left end: ease up to the ceiling
  elsif x > xb then interp.(xb) * ss.((33.0 - x) / (33.0 - xb)) # right end
  else interp.(x)
  end
end
# Gaussian smoothing (sigma 2.5 columns = 0.55 m) removes hand-drawing jitter, keeps every wave
sig = 2.5
sm = raw.each_index.map do |i|
  w = (-8..8).map { |k| j = (i + k).clamp(0, 149); g = Math.exp(-(k * k) / (2 * sig * sig)); [raw[j] * g, g] }
  w.sum(&:first) / w.sum(&:last)
end
lo, hi = sm.minmax
sm = sm.map { |v| ((v - lo) / (hi - lo)).round(3) }
puts "PROFILE (#{sm.size}) min #{sm.min} max #{sm.max}"
puts sm.each_slice(15).map { |s| '    ' + s.map { |v| format('%.3f', v) }.join(', ') }.join(",\n")
