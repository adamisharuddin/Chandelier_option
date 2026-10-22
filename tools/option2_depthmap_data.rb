# Writes the data file for tools/depthmap_template.html (Option 2 top-view depth map with pocket labels).
#   ruby tools/option2_depthmap_data.rb tools/depthmap_data.js
# Then replace /*DATA*/ in depthmap_template.html with the file's contents and open it in a browser.
require 'json'
ROOT = File.expand_path('..', __dir__)
CHANDELIER_NO_BUILD = true
src = File.read(File.join(ROOT, 'sketchup', 'chandelier_build.rb')).sub(/^load .*claude_su\.rb'\)\n/, '')
eval(src, binding, 'chandelier_build.rb') # rubocop:disable Security/Eval
rows = Chandelier.drops('2', 0.45, 1.65)
grid = rows.map { |c, r, _x, _y, l| [c, r, l] }
pockets = Chandelier::POCKETS_2.each_with_index.map do |(px, py, _d, _ra, _rc, _a, wall), i|
  near = rows.select { |_c, _r, x, y, _l| (x + 16.5 - px).abs < 1.2 && (y - py).abs < 1.2 }
  { n: i + 1, x: px, y: py, drop: near.map(&:last).max, steep: wall > 2.5 }
end
File.write(ARGV[0] || 'depthmap_data.js', 'window.DATA={"A":' + JSON.generate(grid) + '};window.POCKETS=' + JSON.generate(pockets) + ';')
pockets.each { |p| puts format('P%d at %.1f m / %+.1f m: deepest %.2f m%s', p[:n], p[:x], p[:y], p[:drop], p[:steep] ? ' (steep)' : '') }
