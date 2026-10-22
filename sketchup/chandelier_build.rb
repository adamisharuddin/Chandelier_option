# Ajdan Cityscape 2026 - Chandelier, Options 1 and 2 (4,800 pendants over 33.00 x 8.00 m)
# Plan grid + ceiling from: CEILING AND CHANDELIER PLAN DETAILS_AJDAN CITYSCAPE 2026 2.pdf
#   + "TAPE IRON 30X60" ceiling detail. Light fitting from: Chandelier one point.skp (this folder).
#
#   Option 1 - Smooth Wave  : long profile traced from the client's sketch, pockets alternating across the width
#   Option 2 - Nine Pockets : nine pockets alternating across the width, four of them steep
#
# Run in SketchUp 2022: Window > Ruby Console, in a NEW empty model:
#   load 'C:/path/to/repo/sketchup/chandelier_build.rb'
# Builds both options over one ceiling, each on its own tag - show one tag at a time.
# Both share the LIGHT PIECE and CABLE components from the one-point file: edit LIGHT PIECE once, all update.
# Writes a drop schedule CSV per option next to this file. One option only: set ENV['CHANDELIER_OPT'] = '1' or '2'.
load File.join(__dir__, 'lib', 'claude_su.rb')

module Chandelier
  # --- DATA (from drawing) ---
  COLS, ROWS = 150, 32          # 4 x (75 x 16) = 4,800 points
  DX, DY     = 0.22, 0.25       # point spacing (m)
  HX, HY     = 16.5, 4.0        # half of 33.00 x 8.00
  BAY        = 2.20             # tape iron bays along X (15 bays)
  PANEL_W, PANEL_D = 1.06, 0.96 # cladding panel; 2 per bay along X, 8 rows along Y
  PITCH_X, PITCH_Y = 1.10, 1.00 # panel pitch -> 5 x 4 = 20 points per panel

  # --- DATA (from client) ---
  ROD_MIN   = 0.05              # shortest rod from hanging base to top of fitting (m)
  DROP_MAX  = 1.65              # longest drop, hanging base to bottom of fitting (m)
  FIT_FILE  = File.join(__dir__, 'Chandelier one point.skp')
  ROUND_TO  = 0.005             # drop lengths rounded to 5 mm for fabrication

  # --- ASSUMED ---
  PANEL_T   = 0.018             # cladding thickness; underside = hanging base, z = 0
  IRON_W, IRON_H = 0.030, 0.060 # tape iron 30x60 on top of the panels
  OPTIONS   = ENV['CHANDELIER_OPT'] ? [ENV['CHANDELIER_OPT']] : %w[1 2]

  NAMES = { '1' => 'Smooth Wave', '2' => 'Nine Pockets' }.freeze

  # ---------------- OPTION 1 - Smooth Wave ----------------
  # Long-elevation profile traced from the client's sketch (docs/option1_client_sketch.png,
  # tools/trace_to_profile.rb) and smoothed (sigma 0.55 m). 150 values, left -> right; 0 shallow, 1 deep.
  PROFILE_1 = [
    0.007, 0.014, 0.024, 0.038, 0.054, 0.073, 0.094, 0.117, 0.141, 0.164, 0.187, 0.209, 0.229, 0.248, 0.266,
    0.284, 0.304, 0.329, 0.361, 0.400, 0.445, 0.495, 0.547, 0.600, 0.655, 0.709, 0.762, 0.812, 0.859, 0.900,
    0.934, 0.961, 0.981, 0.993, 0.999, 1.000, 0.996, 0.989, 0.979, 0.964, 0.945, 0.920, 0.889, 0.851, 0.807,
    0.758, 0.707, 0.656, 0.609, 0.567, 0.532, 0.505, 0.485, 0.473, 0.466, 0.465, 0.467, 0.472, 0.482, 0.494,
    0.510, 0.529, 0.551, 0.574, 0.601, 0.630, 0.661, 0.691, 0.720, 0.744, 0.763, 0.776, 0.784, 0.788, 0.786,
    0.780, 0.769, 0.753, 0.731, 0.704, 0.672, 0.638, 0.604, 0.571, 0.543, 0.521, 0.508, 0.503, 0.506, 0.520,
    0.542, 0.572, 0.608, 0.649, 0.690, 0.730, 0.766, 0.796, 0.818, 0.832, 0.836, 0.831, 0.816, 0.792, 0.762,
    0.729, 0.697, 0.671, 0.653, 0.646, 0.650, 0.662, 0.680, 0.699, 0.714, 0.721, 0.716, 0.699, 0.670, 0.631,
    0.586, 0.538, 0.493, 0.453, 0.421, 0.399, 0.389, 0.391, 0.405, 0.427, 0.454, 0.481, 0.504, 0.521, 0.527,
    0.523, 0.505, 0.474, 0.430, 0.377, 0.318, 0.257, 0.199, 0.146, 0.100, 0.063, 0.035, 0.017, 0.006, 0.000
  ].freeze
  O1_WIDTH  = 0.74   # cross-section softness (fraction of half-width); bigger = pockets spread wider across 8 m
  O1_BELL   = 2.0    # cross-section shape: 2 = round bell, higher = fuller bottom with steeper sides
  O1_DRAMA  = 0.25   # 0 = profile as drawn; higher = ridges pulled up, pockets pushed to full depth
  O1_SMOOTH = 4.5    # final smoothing along 33 m (columns, sigma) - keeps pocket walls gentle
  # Where the deepest line sits across the 8 m: [x along 33 m, v] with v -1 = front edge, +1 = back edge.
  O1_CENTRE = [[0.0, 0.0], [7.6, -0.28], [12.0, 0.05], [16.2, 0.42], [22.1, -0.22], [25.4, -0.12],
               [29.6, 0.45], [33.0, 0.30]].freeze

  # Smooth (Catmull-Rom) line through O1_CENTRE
  def self.o1_centre(x)
    k = O1_CENTRE
    i = (k.index { |px, _| px > x } || k.size - 1).clamp(1, k.size - 1) - 1
    p0, p1, p2, p3 = k[[i - 1, 0].max], k[i], k[i + 1], k[[i + 2, k.size - 1].min]
    t = ((x - p1[0]) / (p2[0] - p1[0])).clamp(0.0, 1.0)
    a, b, c, d = p0[1], p1[1], p2[1], p3[1]
    0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t**3)
  end

  # Profile after the contrast curve, smoothed again so pocket walls rise gently (no stepped edge).
  def self.o1_profile
    @o1_profile ||= begin
      t = PROFILE_1.map { |p| s = ((p - O1_DRAMA) / (1 - O1_DRAMA)).clamp(0.0, 1.0); s * s * (3 - 2 * s) }
      n = t.size
      sm = (0...n).map do |i|
        w = (-10..10).map { |k| g = Math.exp(-(k * k) / (2 * O1_SMOOTH**2)); [t[(i + k).clamp(0, n - 1)] * g, g] }
        w.sum(&:first) / w.sum(&:last)
      end
      hi = sm.max
      sm.map { |v| v / hi }
    end
  end

  def self.o1_profile_at(u)
    pr = o1_profile
    f = ((u + 1) * HX / DX - 0.5).clamp(0.0, 149.0)
    i = f.floor.clamp(0, 148)
    pr[i] + (pr[i + 1] - pr[i]) * (f - i)
  end

  # ---------------- OPTION 2 - Nine Pockets ----------------
  # [x (m along 33), y (m across 8, 0 = centre), depth 0..1, radius along, radius across, angle deg, wall]
  # wall 2 = soft bowl; 3-4 = steep sides with a full bottom (P2, P4, P5, P7).
  POCKETS_2 = [
    [3.6,   1.0, 0.50, 2.0, 1.8,  20, 2.0],
    [7.6,  -0.9, 1.00, 2.6, 2.1, -25, 3.6],
    [11.6,  1.7, 0.70, 2.0, 1.7,  30, 2.0],
    [14.9, -1.1, 0.85, 1.7, 1.6, -15, 3.4],
    [18.4,  1.0, 1.00, 2.4, 2.0,  25, 3.6],
    [21.9, -1.8, 0.55, 1.9, 1.6, -30, 2.0],
    [25.1,  0.3, 0.95, 2.5, 2.3, -20, 3.4],
    [28.7, -1.4, 0.65, 1.8, 1.7,  25, 2.0],
    [31.3,  1.8, 0.42, 1.3, 1.3,   0, 2.0]
  ].freeze

  def self.o2_raw(x, y)
    keep = POCKETS_2.reduce(1.0) do |acc, (px, py, dep, ra, rc, ang, wall)|
      a = ang * Math::PI / 180
      dx = x - px
      dy = y - py
      s = (dx * Math.cos(a) + dy * Math.sin(a)) / ra
      t = (-dx * Math.sin(a) + dy * Math.cos(a)) / rc
      acc * (1 - dep * Math.exp(-((s * s + t * t)**(wall / 2.0))))
    end
    (1 - keep) * (1 - ((x - HX) / HX).abs**6) * (1 - (y / HY).abs**4) # smooth union, edges back to the ceiling
  end

  # ---------------- shared ----------------
  # Raw depth (bigger = lower) at u in [-1,1] along 33 m, v in [-1,1] across 8 m.
  def self.raw(opt, u, v)
    case opt
    when '1'
      m = o1_centre((u + 1) * HX)
      o1_profile_at(u) * Math.exp(-((v - m).abs / O1_WIDTH)**O1_BELL)
    when '2'
      o2_raw((u + 1) * HX, v * HY)
    else
      raise ArgumentError, "unknown option #{opt.inspect} (use '1' or '2')"
    end
  end

  # Point centres; c = 1..150 from -X, r = 1..32 from -Y. Origin = centre of chandelier on hanging base.
  def self.points
    (1..ROWS).flat_map do |r|
      (1..COLS).map { |c| [c, r, -HX + DX * (c - 0.5), -HY + DY * (r - 0.5)] }
    end
  end

  # Drop (hanging base -> bottom of fitting) for every point, scaled into [drop_min, drop_max].
  def self.drops(opt, drop_min, drop_max)
    pts = points
    raw = pts.map { |_, _, x, y| raw(opt, x / HX, y / HY) }
    lo, hi = raw.minmax
    pts.zip(raw).map do |(c, r, x, y), d|
      l = drop_min + (d - lo) / (hi - lo) * (drop_max - drop_min)
      [c, r, x, y, [(l / ROUND_TO).round * ROUND_TO, drop_min].max.round(3)]
    end
  end

  def self.load_fitting
    defs = CSU.model.definitions
    before = defs.map(&:name)
    wrapper = defs.load(FIT_FILE)
    added = defs.reject { |d| before.include?(d.name) }
    piece = added.find { |d| d.name =~ /\ALIGHT PIECE/ }
    cable = added.find { |d| d.name =~ /\ACABLE/ }
    raise "LIGHT PIECE / CABLE components not found in #{FIT_FILE}" unless piece && cable
    defs.remove(wrapper) if defs.respond_to?(:remove)
    [piece, cable]
  end

  def self.ceiling(ents)
    panel = CSU.comp('CLADDING PANEL 1.06x0.96', 'Ceiling cladding; underside = hanging base (z = 0).')
    CSU.box(panel.entities, -PANEL_W / 2, -PANEL_D / 2, 0, PANEL_W, PANEL_D, PANEL_T,
            material: CSU.mat('Ceiling Cladding', [70, 66, 62]))
    g = ents.add_group
    g.name = 'CEILING 33.00 x 8.00'
    (0...(2 * HX / PITCH_X).round).each do |i|
      (0...(2 * HY / PITCH_Y).round).each do |j|
        CSU.place(g.entities, panel, -HX + PITCH_X * (i + 0.5), -HY + PITCH_Y * (j + 0.5),
                  layer: 'CEILING - CLADDING')
      end
    end
    iron = CSU.mat('Tape Iron', [45, 45, 48])
    t = CSU.tag('CEILING - TAPE IRON 30x60')
    z = PANEL_T
    (0..(2 * HX / BAY).round).each do |k| # along Y at every bay line
      x = -HX + BAY * k - IRON_W / 2
      CSU.box(g.entities, x, -HY, z, IRON_W, 2 * HY, IRON_H, material: iron, name: "Tape iron X#{k}").layer = t
    end
    [-HY, 0.0, HY].each_with_index do |y, k| # along X: edges + centre line
      CSU.box(g.entities, -HX, y - IRON_W / 2, z, 2 * HX, IRON_W, IRON_H, material: iron, name: "Tape iron Y#{k}").layer = t
    end
    g
  end

  def self.build
    CSU.build('Ajdan Chandelier') do
      CSU.setup_metric
      piece, cable = load_fitting
      pb = piece.bounds
      fit_h = pb.depth.to_m
      fit_top = pb.max.z.to_m
      cab_l = cable.bounds.depth.to_m
      drop_min = ROD_MIN + fit_h
      puts format('LIGHT PIECE height %.3f m (top at z %.3f), CABLE unit %.3f m -> drops %.3f..%.3f m',
                  fit_h, fit_top, cab_l, drop_min, DROP_MAX)

      ceiling(CSU.model.entities)

      OPTIONS.each do |opt|
        g = CSU.model.entities.add_group
        g.name = "CHANDELIER OPTION #{opt} - #{NAMES[opt]}"
        g.layer = CSU.tag("OPTION #{opt} - #{NAMES[opt]}")
        rows = drops(opt, drop_min, DROP_MAX)
        csv = ["point,column,row,bay,panel_col,panel_row,x_m,y_m,drop_total_m,rod_m"]
        rows.each do |c, r, x, y, l|
          rod = (l - fit_h).round(3)
          id = format('C%03d-R%02d', c, r)
          CSU.place(g.entities, cable, x, y, sz: rod / cab_l, name: id, layer: 'CHANDELIER - CABLES')
          CSU.place(g.entities, piece, x, y, -rod - fit_top, name: "#{id} L=#{format('%.3f', l)}",
                    layer: 'CHANDELIER - LIGHT PIECES')
          csv << [id, c, r, ((c - 1) / 10) + 1, ((c - 1) / 5) + 1, ((r - 1) / 4) + 1,
                  x.round(3), y.round(3), format('%.3f', l), format('%.3f', rod)].join(',')
        end
        File.write(File.join(__dir__, "Option#{opt}_#{NAMES[opt].delete(' ')}_drop_schedule.csv"), csv.join("\n") + "\n")
        ls = rows.map(&:last)
        puts format('Option %s %s: %d points, drop %.3f..%.3f m, mean %.3f m',
                    opt, NAMES[opt], rows.size, ls.min, ls.max, ls.sum / ls.size)
      end
      CSU.report # expect LIGHT PIECE / CABLE = 4,800 per option, CLADDING PANEL = 240
    end
  end
end

Chandelier.build unless defined?(CHANDELIER_NO_BUILD)
