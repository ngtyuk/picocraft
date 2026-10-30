require 'game'

# A small, asset-free block sandbox. Coordinates are block corners.
module TinyBlocks
  D = Game::Display
  I = Game::Input
  T = Game::ThreeD
  SIZE = 8
  HEIGHT = 8
  OLD_HEIGHT = 4
  # Selectable blocks start at type 2; type 1 is the permanent grass floor.
  COLORS = [
    ['WHITE', 0xffffff], ['GRAY', 0x999fa7], ['BLACK', 0x393e48],
    ['Ruby', 0xe74848], ['ORANGE', 0xf38835], ['YELLOW', 0xf3d34a],
    ['LIME', 0x8acb49], ['GREEN', 0x36a35a], ['CYAN', 0x44c9c7],
    ['BLUE', 0x4385db], ['PURPLE', 0x985dd0], ['PINK', 0xee87b2]
  ]
  VERTICES = [0,0,0, 1,0,0, 1,1,0, 0,1,0,
              0,0,1, 1,0,1, 1,1,1, 0,1,1]
  FACES = [0,2,3, 0,1,2, 4,6,5, 4,7,6,
           0,7,4, 0,3,7, 1,6,2, 1,5,6,
           0,5,1, 0,4,5, 3,6,7, 3,2,6]
  EDGES = [0,1, 1,2, 2,3, 3,0, 4,5, 5,6, 6,7, 7,4,
           0,4, 1,5, 2,6, 3,7]

  # The face order matches FACES: z-, z+, x-, x+, y-, y+.
  FACE_NEIGHBORS = [[0,0,-1], [0,0,1], [-1,0,0], [1,0,0],
                    [0,-1,0], [0,1,0]]

  def self.model(type, mask)
    colors = type == 1 ? [0x82e5, 0x82e5, 0x5a24, 0x5a24, 0x5a24, 0x5d86] :
      [78, 78, 58, 58, 58, 100].map { |brightness| rgb565(COLORS[type - 2][1], brightness) }
    faces = []
    face_colors = []
    6.times do |face|
      next if (mask & (1 << face)) == 0
      6.times { |i| faces << FACES[face * 6 + i] }
      face_colors << colors[face] << colors[face]
    end
    T::Model.new(VERTICES, faces, face_colors)
  end

  def self.rgb565(rgb, brightness)
    r = ((rgb >> 16) & 255) * brightness / 100
    g = ((rgb >> 8) & 255) * brightness / 100
    b = (rgb & 255) * brightness / 100
    ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
  end

  def self.sound(path)
    Game::Audio.play_se(path, 180) if Game::Audio.supported?
  end

  def self.reset
    @blocks = Array.new(SIZE * SIZE * HEIGHT, 0)
    SIZE.times do |z|
      SIZE.times do |x|
        set(x, 0, z, 1)
      end
    end
    [[1,1,3,2], [1,2,3,2], [5,1,4,2], [5,2,4,2],
     [3,1,6,3], [4,1,6,3], [4,2,6,3], [6,1,6,3]].each do |b|
      set(b[0], b[1], b[2], b[3])
    end
    @x = 3.5; @z = 1.5; @yaw = 0.0; @pitch = -0.25
    @feet = 1.0; @vertical_speed = 0.0; @grounded = true
    @selected = 2
    rebuild
  end

  def self.index(x, y, z)
    (y * SIZE + z) * SIZE + x
  end

  def self.inside?(x, y, z)
    x >= 0 && x < SIZE && y >= 0 && y < HEIGHT && z >= 0 && z < SIZE
  end

  def self.get(x, y, z)
    return 0 unless inside?(x, y, z)
    @blocks[index(x, y, z)]
  end

  def self.set(x, y, z, value)
    @blocks[index(x, y, z)] = value if inside?(x, y, z)
  end

  def self.rebuild
    # Four spatial groups keep the visibility check and draw-call overhead low.
    @instances = Array.new(4) { {} }
    previous_models = @models
    current_models = {} if previous_models
    HEIGHT.times do |y|
      SIZE.times do |z|
        SIZE.times do |x|
          type = get(x, y, z)
          next if type == 0
          mask = 0
          FACE_NEIGHBORS.each_with_index do |offset, face|
            mask |= 1 << face if get(x + offset[0], y + offset[1], z + offset[2]) == 0
          end
          next if mask == 0
          key = type * 64 + mask
          if current_models
            current_models[key] ||= previous_models[key] || model(type, mask)
          end
          chunk = (z / 4) * 2 + x / 4
          batches = (@instances[chunk][key] ||= [[]])
          batch = batches[-1]
          if batch.length >= 128 * 9
            batch = []
            batches << batch
          end
          batch.concat([x,y,z, 0,0,0, 1,1,1])
        end
      end
    end
    @models = current_models if previous_models
  end

  # Conservative horizontal frustum test for a 4 x 8 x 4 chunk.
  # 6.1 bounds the sphere projected onto a side plane; 0.71 is wider than tan(35 degrees).
  def self.visible_chunks
    sin_yaw = Math.sin(@yaw); cos_yaw = Math.cos(@yaw)
    sin_pitch = Math.sin(@pitch); cos_pitch = Math.cos(@pitch)
    eye_y = @feet + 0.65
    visible = []
    4.times do |chunk|
      dx = (chunk % 2) * 4 + 2 - @x
      dy = HEIGHT / 2.0 - eye_y
      dz = (chunk / 2) * 4 + 2 - @z
      side = dx * cos_yaw - dz * sin_yaw
      depth = (dx * sin_yaw + dz * cos_yaw) * cos_pitch + dy * sin_pitch
      visible << chunk if side.abs <= depth * 0.71 + 6.1
    end
    visible
  end

  def self.save_world
    return false unless Game::Save.supported?
    Game::Save.write('tiny_blocks', 'TB2|' + @blocks.join(','))
  rescue
    false
  end

  def self.load_world
    return false unless Game::Save.supported?
    data = Game::Save.read('tiny_blocks')
    return false unless data
    parts = data.split('|')
    return false unless parts.length == 2
    saved_height = parts[0] == 'TB1' ? OLD_HEIGHT : (parts[0] == 'TB2' ? HEIGHT : 0)
    return false if saved_height == 0
    values = parts[1].split(',')
    return false unless values.length == SIZE * SIZE * saved_height
    blocks = []
    values.each_with_index do |value, i|
      n = value.to_i
      return false unless value == n.to_s && n >= 0 && n < COLORS.length + 2
      return false if i < SIZE * SIZE && n != 1
      return false if i >= SIZE * SIZE && n == 1
      blocks << n
    end
    while blocks.length < SIZE * SIZE * HEIGHT
      blocks << 0
    end
    @blocks = blocks
    # Spawn above the world so saved blocks can never trap the player.
    @x = 3.5; @z = 1.5; @feet = HEIGHT.to_f
    @vertical_speed = 0.0; @grounded = false
    @yaw = 0.0; @pitch = -0.25; @selected = 2
    rebuild
    true
  rescue
    false
  end

  def self.title_screen(choice, notice)
    D.clear(0x867d)
    D.fill_rect(16, 24, 288, 192, 0x10a4)
    D.draw_text(106, 40, 'PICOCRAFT', 0xffff)
    D.draw_text(48, 80, choice == 0 ? '> NEW WORLD' : '  NEW WORLD', 0xffff)
    D.draw_text(48, 104, choice == 1 ? '> CONTINUE' : '  CONTINUE', 0xffff)
    D.draw_text(32, 160, 'UP/DOWN  A: OK', 0xbdf7)
    D.draw_text(32, 184, notice, 0xffe0) if notice
  end

  def self.menu_screen(cursor, notice)
    D.fill_rect(8, 30, 304, 178, 0x10a4)
    D.draw_text(20, 38, 'BLOCKS', 0xffff)
    COLORS.each_with_index do |color, i|
      x = 20 + (i % 4) * 70
      y = 58 + (i / 4) * 29
      D.fill_rect(x, y, 58, 23, i == cursor ? 0xffff : 0x4208)
      D.fill_rect(x + 2, y + 2, 54, 19, rgb565(color[1], 100))
    end
    name = cursor < 12 ? COLORS[cursor][0] : (cursor == 12 ? 'SAVE' : 'RESUME')
    D.draw_text(20, 148, name, 0xffff)
    D.draw_text(20, 170, cursor == 12 ? '> SAVE' : '  SAVE', 0xffff)
    D.draw_text(164, 170, cursor == 13 ? '> BACK' : '  BACK', 0xffff)
    D.draw_text(20, 192, notice || 'A: OK  SEL: BACK', 0xffe0)
  end

  # The player is 0.9 blocks tall, with a 0.44-block-wide footprint.
  def self.free?(x, z, feet)
    return false if x < 0.22 || x > SIZE - 0.22 || z < 0.22 || z > SIZE - 0.22
    bottom = (feet + 0.001).floor
    top = (feet + 0.9 - 0.001).floor
    [-0.22, 0.22].each do |dx|
      [-0.22, 0.22].each do |dz|
        (bottom..top).each do |y|
          return false if get((x + dx).floor, y, (z + dz).floor) != 0
        end
      end
    end
    true
  end

  def self.update_height(dt)
    old_speed = @vertical_speed
    @vertical_speed -= 18.0 * dt
    next_feet = @feet + (old_speed + @vertical_speed) * 0.5 * dt
    @grounded = false
    [-0.22, 0.22].each do |dx|
      [-0.22, 0.22].each do |dz|
        x = (@x + dx).floor
        z = (@z + dz).floor
        HEIGHT.times do |y|
          next if get(x, y, z) == 0
          if next_feet <= @feet && @feet >= y + 1 && next_feet <= y + 1
            next_feet = y + 1.0
            @grounded = true
          elsif next_feet > @feet && @feet + 0.9 <= y && next_feet + 0.9 >= y
            next_feet = y - 0.9
            @vertical_speed = 0.0
          end
        end
      end
    end
    @vertical_speed = 0.0 if @grounded
    @feet = next_feet
  end

  # Sample the view ray and remember the last empty cell for placement.
  def self.target
    dx = Math.sin(@yaw) * Math.cos(@pitch)
    dy = Math.sin(@pitch)
    dz = Math.cos(@yaw) * Math.cos(@pitch)
    previous = nil
    distance = 0.1
    while distance <= 4.0
      x = (@x + dx * distance).floor
      y = (@feet + 0.65 + dy * distance).floor
      z = (@z + dz * distance).floor
      if inside?(x, y, z)
        return [x, y, z, previous] if get(x, y, z) != 0
        previous = [x, y, z]
      else
        previous = nil
      end
      distance += 0.05
    end
    nil
  end

  def self.run
    Game.init
    unless Game::Runtime.capability?(Game::Capabilities::THREE_D_MODELS)
      D.clear(0x0000); D.draw_text(8, 8, '3D MODEL REQUIRED', 0xffff); D.present
      loop { Game.tick(2) }
    end
    T.set_resolution(160, 120)
    @models = {}
    @outline = T::Model.new(VERTICES, [], [], EDGES, 0xffff, true)
    reset
    state = :title
    title_choice = 0
    cursor = 0
    notice = nil
    loop do
      if state == :title
        if I.just_pressed?(I::UP) || I.just_pressed?(I::DOWN)
          title_choice = 1 - title_choice
          notice = nil
          sound('select.wav')
        end
        if I.just_pressed?(I::A) || I.just_pressed?(I::START)
          if title_choice == 0
            reset
            state = :play
          elsif load_world
            state = :play
          else
            notice = 'NO SAVE DATA'
          end
        end
        title_screen(title_choice, notice) if state == :title
        if state == :title
          D.present
          Game.tick(30)
          next
        end
        notice = nil
        Game.tick(30)
        next
      end
      if state == :menu
        previous_cursor = cursor
        cursor = (cursor + 13) % 14 if I.just_pressed?(I::LEFT)
        cursor = (cursor + 1) % 14 if I.just_pressed?(I::RIGHT)
        cursor = cursor < 4 ? 12 : cursor - 4 if I.just_pressed?(I::UP)
        cursor = cursor >= 10 ? 12 + (cursor % 2) : cursor + 4 if I.just_pressed?(I::DOWN)
        if cursor != previous_cursor
          notice = nil
          sound('select.wav')
        end
        if I.just_pressed?(I::SELECT) || I.just_pressed?(I::B)
          state = :play
        elsif I.just_pressed?(I::A)
          if cursor < 12
            @selected = cursor + 2
            sound('select.wav')
            state = :play
          elsif cursor == 12
            notice = save_world ? 'SAVED!' : 'SAVE FAILED'
          else
            state = :play
          end
        end
        if state == :menu
          menu_screen(cursor, notice)
          D.present
        end
        Game.tick(30)
        next
      end
      if I.just_pressed?(I::SELECT)
        cursor = @selected - 2
        notice = nil
        state = :menu
        menu_screen(cursor, notice)
        D.present
        Game.tick(30)
        next
      end
      dt = Game::Time.delta_ms
      dt = 100 if dt > 100
      dt = dt / 1000.0
      @yaw -= 1.8 * dt if I.pressed?(I::LEFT)
      @yaw += 1.8 * dt if I.pressed?(I::RIGHT)
      @pitch += 1.0 * dt if I.pressed?(I::UP)
      @pitch -= 1.0 * dt if I.pressed?(I::DOWN)
      @pitch = 0.8 if @pitch > 0.8
      @pitch = -1.1 if @pitch < -1.1
      if @grounded && I.just_pressed?(I::START)
        @vertical_speed = 7.4
        @grounded = false
        sound('jump.wav')
      end
      update_height(dt)
      move = (I.pressed?(I::A) ? 1 : 0) - (I.pressed?(I::B) ? 1 : 0)
      nx = @x + Math.sin(@yaw) * move * 2.2 * dt
      nz = @z + Math.cos(@yaw) * move * 2.2 * dt
      @x = nx if free?(nx, @z, @feet)
      @z = nz if free?(@x, nz, @feet)
      hit = target
      world_changed = false
      if hit && I.just_pressed?(I::R) && hit[1] > 0
        set(hit[0], hit[1], hit[2], 0)
        rebuild
        world_changed = true
        sound('break.wav')
      elsif hit && I.just_pressed?(I::L) && hit[3]
        p = hit[3]
        # Don't place a block intersecting the player's body.
        if p[1] > 0 && !(@feet < p[1] + 1 && @feet + 0.9 > p[1] && @x + 0.22 > p[0] && @x - 0.22 < p[0] + 1 &&
                         @z + 0.22 > p[2] && @z - 0.22 < p[2] + 1)
          set(p[0], p[1], p[2], @selected)
          rebuild
          world_changed = true
          sound('place.wav')
        end
      end
      hit = target if world_changed
      D.clear(0x867d)
      T.set_camera(@x, @feet + 0.65, @z, @yaw, @pitch, 70, 0.1, 20)
      T.begin_frame
      visible_chunks.each do |chunk|
        @instances[chunk].each do |key, batches|
          batches.each { |batch| @models[key].draw_instances(batch) }
        end
      end
      @outline.draw_instances([hit[0],hit[1],hit[2], 0,0,0, 1,1,1]) if hit
      D.draw_line(154,120,166,120,1,0xffff)
      D.draw_line(160,114,160,126,1,0xffff)
      D.fill_rect(0, 0, 320, 16, 0x0000)
      D.draw_text(4, 2, 'BLOCK: ' + COLORS[@selected - 2][0], 0xffff)
      COLORS.each_with_index do |color, i|
        x = 4 + i * 18
        D.fill_rect(x, 18, 16, 8, i == @selected - 2 ? 0xffff : 0x0000)
        D.fill_rect(x + 1, 19, 14, 6, rgb565(color[1], 100))
      end
      D.fill_rect(0, 224, 320, 16, 0x0000)
      D.draw_text(4, 226, 'L PLACE R BREAK', 0xffff)
      D.present
      Game.tick(30)
    end
  end
end

TinyBlocks.run
