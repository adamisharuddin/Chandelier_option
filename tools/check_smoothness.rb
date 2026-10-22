# Steepness check: biggest drop change between neighbouring pendants (along X and along Y).
# Keep under ~0.09 m for walls that read smooth from every angle (steep pockets in Option 2 go to ~0.20 m).
#   ruby tools/check_smoothness.rb 1      (or 2)
ROOT = File.expand_path('..', __dir__)
CHANDELIER_NO_BUILD = true
src = File.read(File.join(ROOT, 'sketchup', 'chandelier_build.rb')).sub(/^load .*claude_su\.rb'\)\n/, '')
eval(src, binding, 'chandelier_build.rb') # rubocop:disable Security/Eval
rows = Chandelier.drops(ARGV[0] || '1', 0.45, 1.65)
g = {}
rows.each { |c, r, _x, _y, l| g[[c, r]] = l }
dx = []
dy = []
g.each do |(c, r), l|
  dx << [(g[[c + 1, r]] - l).abs, c, r] if g[[c + 1, r]]
  dy << [(g[[c, r + 1]] - l).abs, c, r] if g[[c, r + 1]]
end
p95 = ->(a) { s = a.map(&:first).sort; s[(s.size * 0.95).floor] }
mx = dx.max_by(&:first)
my = dy.max_by(&:first)
puts format('along 33 m: max %.3f m per 0.22 m step at C%03d-R%02d (x %.1f m), 95%% under %.3f', mx[0], mx[1], mx[2], 0.22 * (mx[1] - 0.5), p95.(dx))
puts format('across 8 m: max %.3f m per 0.25 m step at C%03d-R%02d, 95%% under %.3f', my[0], my[1], my[2], p95.(dy))
ls = rows.map(&:last)
puts format('drop %.2f..%.2f, mean %.3f, >=1.40: %d', ls.min, ls.max, ls.sum / ls.size, ls.count { |v| v >= 1.4 })
