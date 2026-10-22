# claude_su.rb - shared SketchUp helpers for scripts made by the pdf-to-sketchup skill.
# Loaded at the top of each generated script:
#   load 'C:/Users/User/.claude/skills/pdf-to-sketchup/helpers/claude_su.rb'
# All lengths in metres. Tested target: SketchUp 2022.

module CSU
  module_function

  def model
    Sketchup.active_model
  end

  def m(v)
    v.to_f.m
  end

  def pt(x, y, z = 0)
    Geom::Point3d.new(m(x), m(y), m(z))
  end

  def setup_metric(precision = 3)
    uo = model.options['UnitsOptions']
    uo['LengthFormat'] = 0     # decimal
    uo['LengthUnit'] = 4       # metres
    uo['LengthPrecision'] = precision
  end

  # Runs the block as one undo step; aborts cleanly and prints the error on failure.
  def build(name)
    model.start_operation(name, true)
    result = yield
    model.commit_operation
    model.active_view.zoom_extents
    result
  rescue StandardError => e
    model.abort_operation
    puts "BUILD FAILED: #{e.class}: #{e.message}"
    puts e.backtrace.first(5)
    nil
  end

  def tag(name)
    model.layers[name] || model.layers.add(name)
  end

  def mat(name, rgb, alpha = nil)
    mt = model.materials[name] || model.materials.add(name)
    mt.color = Sketchup::Color.new(*rgb)
    mt.alpha = alpha if alpha
    mt
  end

  def comp(name, desc = nil)
    d = model.definitions.add(name)
    d.description = desc if desc
    d
  end

  def paint(ents, material)
    return unless material
    ents.grep(Sketchup::Face).each { |f| f.material = material }
  end

  # Closed polygon [[x,y],...] at z0, extruded by height (negative = downwards). Returns a group.
  def prism(ents, pts2d, height, z0: 0, material: nil, name: nil)
    g = ents.add_group
    face = g.entities.add_face(pts2d.map { |x, y| pt(x, y, z0) })
    face.reverse! if (face.normal.z > 0) != (height > 0)
    face.pushpull(m(height.abs))
    paint(g.entities, material)
    g.name = name if name
    g
  end

  # Axis-aligned box from corner (x,y,z), size w (X) d (Y) h (Z).
  def box(ents, x, y, z, w, d, h, material: nil, name: nil)
    prism(ents, [[x, y], [x + w, y], [x + w, y + d], [x, y + d]], h, z0: z, material: material, name: name)
  end

  # Vertical cylinder. down: true hangs from z_top downwards; false grows upwards.
  def cylinder(ents, dia, len, center: [0, 0], z_top: 0, segs: 24, material: nil, down: true, name: nil)
    g = ents.add_group
    c = g.entities.add_circle(pt(center[0], center[1], z_top), Z_AXIS, m(dia / 2.0), segs)
    f = g.entities.add_face(c)
    f.reverse! if (f.normal.z > 0) == down
    f.pushpull(m(len))
    paint(g.entities, material)
    g.name = name if name
    g
  end

  # Softens/smooths edges between faces meeting at less than max_deg (curved surfaces).
  def soften(ents, max_deg = 30)
    ents.grep(Sketchup::Edge).each do |e|
      next unless e.faces.size == 2
      next if e.faces[0].normal.angle_between(e.faces[1].normal) > max_deg.degrees
      e.soft = true
      e.smooth = true
    end
  end

  # Tapered round solid standing on z0 (d_bot at bottom, d_top at top).
  def frustum(ents, d_bot, d_top, h, center: [0, 0], z0: 0, segs: 32, material: nil, name: nil)
    g = ents.add_group
    cx, cy = center
    ring_pts = lambda do |d, z|
      (0...segs).map { |i| a = 2 * Math::PI * i / segs; pt(cx + d / 2.0 * Math.cos(a), cy + d / 2.0 * Math.sin(a), z) }
    end
    b = ring_pts.call(d_bot, z0)
    t = ring_pts.call(d_top, z0 + h)
    g.entities.add_face(b)
    g.entities.add_face(t)
    segs.times { |i| j = (i + 1) % segs; g.entities.add_face(b[i], b[j], t[j], t[i]) }
    soften(g.entities)
    paint(g.entities, material)
    g.name = name if name
    g
  end

  # Round solid between two 3D points [x,y,z] (any direction).
  def tube(ents, p0, p1, dia, segs: 16, material: nil, name: nil)
    g = ents.add_group
    a = pt(*p0)
    v = a.vector_to(pt(*p1))
    f = g.entities.add_face(g.entities.add_circle(a, v, m(dia / 2.0), segs))
    f.reverse! if f.normal.dot(v) < 0
    f.pushpull(v.length)
    paint(g.entities, material)
    g.name = name if name
    g
  end

  # Annular solid (ring) standing on z0, optional gap of gap_deg centred on direction gap_dir (deg, 90 = +Y).
  def ring(ents, d_out, d_in, h, center: [0, 0], z0: 0, gap_deg: 0, gap_dir: 90, segs: 48, material: nil, name: nil)
    cx, cy = center
    if gap_deg <= 0
      g = ents.add_group
      outer = g.entities.add_face(g.entities.add_circle(pt(cx, cy, z0), Z_AXIS, m(d_out / 2.0), segs))
      inner = g.entities.add_face(g.entities.add_circle(pt(cx, cy, z0), Z_AXIS, m(d_in / 2.0), segs))
      inner.erase! if inner && inner.valid?
      outer.reverse! if outer.normal.z < 0
      outer.pushpull(m(h))
    else
      a0 = (gap_dir + gap_deg / 2.0).degrees
      span = (360 - gap_deg).degrees
      arc = ->(r) { (0..segs).map { |i| a = a0 + span * i / segs; [cx + r * Math.cos(a), cy + r * Math.sin(a)] } }
      g = prism(ents, arc.call(d_out / 2.0) + arc.call(d_in / 2.0).reverse, h, z0: z0)
    end
    soften(g.entities)
    paint(g.entities, material)
    g.name = name if name
    g
  end

  # 1 m vertical rod hanging down from its origin; give each instance sz: length.
  def unit_rod(name, dia, segs: 8, material: nil)
    d = comp(name, '1 m unit, scaled in Z per instance.')
    cylinder(d.entities, dia, 1.0, segs: segs, material: material).explode
    d
  end

  # Wall along a->b ([x,y]), centred on the line. openings: [[offset, width, sill, head], ...]
  # measured from a along the wall (sill 0 = door).
  def wall(ents, a, b, thick, height, openings: [], z0: 0, material: nil, name: nil)
    ax, ay = a
    bx, by = b
    len = Math.hypot(bx - ax, by - ay)
    ux = (bx - ax) / len
    uy = (by - ay) / len
    nx = -uy * thick / 2.0
    ny = ux * thick / 2.0
    pieces = []
    s = 0.0
    openings.sort_by(&:first).each do |o, w, sill, head|
      pieces << [s, o, 0, height] if o > s
      pieces << [o, o + w, 0, sill] if sill > 0
      pieces << [o, o + w, head, height] if head < height
      s = o + w
    end
    pieces << [s, len, 0, height] if s < len
    g = ents.add_group
    g.name = name if name
    pieces.each do |s0, s1, zb, zt|
      p0 = [ax + ux * s0, ay + uy * s0]
      p1 = [ax + ux * s1, ay + uy * s1]
      pts = [[p0[0] + nx, p0[1] + ny], [p1[0] + nx, p1[1] + ny], [p1[0] - nx, p1[1] - ny], [p0[0] - nx, p0[1] - ny]]
      prism(g.entities, pts, zt - zb, z0: z0 + zb, material: material)
    end
    g
  end

  # Vertical wall a->b ([x,y]) centred on the line, shaped by a profile and cut with rectangular holes.
  # shape: height (rectangle) or [[s,z],..] polygon (s along the wall from a, z up from z0) e.g. a gable.
  # openings: [[offset, width, sill, head]] - holes must sit inside the profile (or touch its edge).
  # offset: shifts the wall off the a-b line along its left normal (cladding / panels on a wall face).
  def profile_wall(ents, a, b, thick, shape, openings: [], z0: 0, offset: 0, material: nil, name: nil)
    ax, ay = a
    bx, by = b
    len = Math.hypot(bx - ax, by - ay)
    ux = (bx - ax) / len
    uy = (by - ay) / len
    nx = -uy
    ny = ux
    prof = shape.is_a?(Numeric) ? [[0, 0], [len, 0], [len, shape], [0, shape]] : shape
    to3 = ->(s, z) { pt(ax + ux * s + nx * (offset - thick / 2.0), ay + uy * s + ny * (offset - thick / 2.0), z0 + z) }
    g = ents.add_group
    g.entities.add_face(prof.map { |s, z| to3.call(s, z) })
    openings.each do |o, w, sill, head|
      f = g.entities.add_face([[o, sill], [o + w, sill], [o + w, head], [o, head]].map { |s, z| to3.call(s, z) })
      f.erase! if f && f.valid?
    end
    nvec = Geom::Vector3d.new(nx, ny, 0)
    g.entities.grep(Sketchup::Face).each do |f|
      f.reverse! if f.normal.dot(nvec) < 0
      f.pushpull(m(thick))
    end
    paint(g.entities, material)
    g.name = name if name
    g
  end

  # Flat plate from any planar 3D polygon [[x,y,z],..], thickened by thick towards dir (roofs, ramps, glazing).
  def panel(ents, pts3d, thick, dir: [0, 0, -1], material: nil, name: nil)
    g = ents.add_group
    f = g.entities.add_face(pts3d.map { |p| pt(*p) })
    f.reverse! if f.normal.dot(Geom::Vector3d.new(*dir)) < 0
    f.pushpull(m(thick))
    paint(g.entities, material)
    g.name = name if name
    g
  end

  # Door / window component. Local: width +X from 0, sill z = 0, centred on Y (place rot 0 on X-walls, 90 on Y-walls).
  #   leaves: 0 = window/glazing, 1 = single door, 2 = double / folding door
  #   style (doors): :flush, :panel (panel_rows inset panels per leaf), :slats (horizontal rails), :glass
  #   leaf_h: transom height with glass fanlight above;  handle: :lever, :pull (long bar at the meeting/lock stile)
  #   mullions / transoms: frame bars for glazing (x / z positions)
  def opening(name, w, h, leaves: 0, style: :flush, panel_rows: 2, leaf_h: nil, handle: :lever, mullions: [],
              transoms: [], frame: nil, leaf: nil, glass: nil, fr: 0.05, fd: 0.07)
    frame ||= mat('Aluminium frame', [60, 60, 62])
    leaf ||= mat('Hardwood door', [128, 86, 52])
    glass ||= mat('Glass', [170, 205, 225], 0.35)
    metal = mat('Door hardware', [45, 45, 48])
    d = comp(name, "#{(w * 1000).round} x #{(h * 1000).round}")
    e = d.entities
    fdd = leaves > 0 ? 0.1 : fd
    box(e, 0, -fdd / 2, h - fr, w, fdd, fr, material: frame)                               # head
    box(e, 0, -fdd / 2, 0, fr, fdd, h - fr, material: frame)                               # jambs
    box(e, w - fr, -fdd / 2, 0, fr, fdd, h - fr, material: frame)
    box(e, fr, -fdd / 2, 0, w - 2 * fr, fdd, fr, material: frame) if leaves.zero?        # window sill
    top = leaf_h || h - fr                                                                # top of leaves / main glass
    if leaf_h
      box(e, fr, -fdd / 2, leaf_h, w - 2 * fr, fdd, fr, material: frame)                  # transom
      box(e, fr, -0.005, leaf_h + fr, w - 2 * fr, 0.01, h - leaf_h - 2 * fr, material: glass) # fanlight
    end
    if leaves.zero?
      mullions.each { |x| box(e, x - fr / 2, -fd / 2, fr, fr, fd, top - fr, material: frame) }
      transoms.each { |z| box(e, fr, -fd / 2, z - fr / 2, w - 2 * fr, fd, fr, material: frame) }
      box(e, fr, -0.005, fr, w - 2 * fr, 0.01, top - fr, material: glass)
      return d
    end
    gap = 0.004
    lw = (w - 2 * fr - gap * (leaves - 1)) / leaves
    lh = top - 0.005
    leaves.times do |i|
      x0 = fr + i * (lw + gap)
      box(e, x0, -0.02, 0.005, lw, 0.04, lh - 0.005, material: leaf, name: 'Leaf')
      [-1, 1].each do |sd|                                                                # both faces
        yf = sd > 0 ? 0.02 : -0.028
        case style
        when :panel, :glass
          st = 0.12
          rail = 0.12
          ph = (lh - 2 * rail - rail * (panel_rows - 1)) / panel_rows
          panel_rows.times do |r|
            z = 0.005 + rail + r * (ph + rail)
            m = style == :glass ? glass : leaf
            box(e, x0 + st, yf, z, lw - 2 * st, 0.008, ph, material: m)
          end
        when :slats
          z = 0.15
          while z < lh - 0.15
            box(e, x0 + 0.08, yf, z, lw - 0.16, 0.008, 0.06, material: leaf)
            z += 0.12
          end
        end
        # handle on the lock side: meeting stile for doubles, far stile for singles
        hx = leaves == 2 ? (i.zero? ? x0 + lw - 0.07 : x0 + 0.07) : x0 + lw - 0.07
        yo = sd > 0 ? 0.028 : -0.058
        if handle == :pull
          box(e, hx - 0.012, yo, 0.55, 0.024, 0.03, 0.9, material: metal)
        else
          box(e, hx - 0.012, yo, 0.98, 0.024, 0.03, 0.06, material: metal)                 # rose
          lx = hx > x0 + lw / 2 ? hx - 0.12 : hx                                           # lever points to leaf centre
          box(e, lx, yo, 1.0, 0.12, 0.03, 0.02, material: metal)
        end
      end
    end
    d
  end

  # Instance of defn at (x,y,z) with optional Z rotation and scale. layer: tag name or Layer.
  def place(ents, defn, x, y, z = 0, sx: 1, sy: 1, sz: 1, rot_deg: 0, name: nil, layer: nil)
    t = Geom::Transformation.translation(Geom::Vector3d.new(m(x), m(y), m(z)))
    t *= Geom::Transformation.rotation(ORIGIN, Z_AXIS, rot_deg.degrees) if rot_deg != 0
    t *= Geom::Transformation.scaling(sx, sy, sz) if [sx, sy, sz] != [1, 1, 1]
    i = ents.add_instance(defn, t)
    i.name = name if name
    i.layer = (layer.is_a?(String) ? tag(layer) : layer) if layer
    i
  end

  # Instance with its local axes set: local X along xdir, local Y towards ydir (made square), Z = X x Y.
  # origin [x,y,z] in metres. Use for anything sloped (rafters, tiles, sheets).
  def place_frame(ents, defn, origin, xdir, ydir, sx: 1, sy: 1, sz: 1, name: nil, layer: nil)
    x = Geom::Vector3d.new(*xdir).normalize
    z = (x * Geom::Vector3d.new(*ydir)).normalize
    y = (z * x).normalize
    t = Geom::Transformation.axes(pt(*origin), x, y, z)
    t *= Geom::Transformation.scaling(sx, sy, sz) if [sx, sy, sz] != [1, 1, 1]
    i = ents.add_instance(defn, t)
    i.name = name if name
    i.layer = (layer.is_a?(String) ? tag(layer) : layer) if layer
    i
  end

  # Stretches a 1 m component (built along local +X) from p0 to p1 ([x,y,z]); local Z leans towards up.
  def place_along(ents, defn, p0, p1, up: [0, 0, 1], **kw)
    v = [p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]]
    len = Math.sqrt(v.sum { |c| c * c })
    side = Geom::Vector3d.new(*up) * Geom::Vector3d.new(*v)
    place_frame(ents, defn, p0, v, side.to_a, sx: len, **kw)
  end

  # Solid from a [[y,z],..] section extruded len metres along +X (fascia, gutters, caps, sheet profiles).
  def section_x(ents, pts_yz, len = 1.0, material: nil, name: nil)
    g = ents.add_group
    f = g.entities.add_face(pts_yz.map { |y, z| pt(0, y, z) })
    f.reverse! if f.normal.x < 0
    f.pushpull(m(len))
    paint(g.entities, material)
    g.name = name if name
    g
  end

  # Parts of the 2D line p0->p1 where the block is true, as [[t0,t1],..] (0..1), edges refined by bisection.
  def segments(p0, p1, step: 0.05, &test)
    at = ->(t) { [p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t] }
    ok = ->(t) { test.call(*at.call(t)) }
    edge = lambda do |a, b|                     # ok(a) != ok(b)
      fa = ok.call(a)
      12.times { mid = (a + b) / 2.0; ok.call(mid) == fa ? a = mid : b = mid }
      (a + b) / 2.0
    end
    len = Math.hypot(p1[0] - p0[0], p1[1] - p0[1])
    n = [(len / step).ceil, 1].max
    out = []
    start = nil
    prev_t = 0.0
    prev_ok = false
    (0..n).each do |i|
      t = i.to_f / n
      cur = ok.call(t)
      start = (i.zero? ? 0.0 : edge.call(prev_t, t)) if cur && !prev_ok
      if !cur && prev_ok
        out << [start, edge.call(prev_t, t)]
        start = nil
      end
      prev_t = t
      prev_ok = cur
    end
    out << [start, 1.0] if start
    out
  end

  # Yields |col, row, x, y| (1-based) over a grid. centered: points sit mid-cell.
  # dirx/diry = -1 runs the grid in the negative direction from (x0, y0).
  def grid(cols, rows, dx, dy, x0: 0, y0: 0, dirx: 1, diry: 1, centered: true)
    off = centered ? 0.5 : 0.0
    (1..rows).each do |r|
      y = y0 + diry * (off + r - 1) * dy
      (1..cols).each do |c|
        x = x0 + dirx * (off + c - 1) * dx
        yield c, r, x, y
      end
    end
  end

  # Same definition in 4 quadrants about the origin: (+,+) (-,+) (-,-) (+,-).
  def mirror4(ents, defn, names = %w[Q1 Q2 Q3 Q4])
    [[1, 1], [-1, 1], [-1, -1], [1, -1]].zip(names).map do |(sx, sy), n|
      place(ents, defn, 0, 0, 0, sx: sx, sy: sy, name: n)
    end
  end

  # Edges-only reference outline (closed polyline) in its own group.
  def outline(ents, pts2d, z: 0, layer: nil, name: nil)
    g = ents.add_group
    g.entities.add_edges((pts2d + [pts2d.first]).map { |x, y| pt(x, y, z) })
    g.name = name if name
    g.layer = (layer.is_a?(String) ? tag(layer) : layer) if layer
    g
  end

  # Prints instance counts per component (nesting included) for checking.
  def report
    model.definitions.each do |d|
      next if d.group? || d.image?
      puts "#{d.name}: #{d.count_used_instances}"
    end
  end
end
