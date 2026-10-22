# Rebuilds viewer/dist/Ajdan_Chandelier_Options_viewer.html from the template + the drop data
# computed by sketchup/chandelier_build.rb (same numbers SketchUp builds).
#   ruby viewer/src/build_viewer.rb
require 'json'
ROOT = File.expand_path('../..', __dir__)
CHANDELIER_NO_BUILD = true
src = File.read(File.join(ROOT, 'sketchup', 'chandelier_build.rb')).sub(/^load .*claude_su\.rb'\)\n/, '')
eval(src, binding, 'chandelier_build.rb') # rubocop:disable Security/Eval

data = %w[1 2].to_h { |k| [k, Chandelier.drops(k, 0.45, 1.65).map { |c, r, _x, _y, l| [c, r, l] }] }
tpl = File.read(File.join(__dir__, 'viewer_template.html'))
html = tpl.sub('/*DATA*/') { 'window.DATA=' + JSON.generate(data) + ';' }
out = File.join(ROOT, 'viewer', 'dist', 'Ajdan_Chandelier_Options_viewer.html')
File.write(out, html)
data.each { |k, v| ls = v.map(&:last); puts format('Option %s: %d points, %.2f..%.2f m', k, v.size, ls.min, ls.max) }
puts "wrote #{out}"
