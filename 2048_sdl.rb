#!/usr/bin/env ruby

# normally require 'rubygame' would suffice;
# this is what worked on my arch linux VM
require 'rubygems'
require 'rubygame/main'
require 'rubygame/shared'
require 'rubygame/clock'
require 'rubygame/constants'
require 'rubygame/color'
require 'rubygame/event'
require 'rubygame/events'
require 'rubygame/event_handler'
require 'rubygame/gl'
require 'rubygame/gfx'
#require 'rubygame/imagefont'
require 'rubygame/joystick'
require 'rubygame/named_resource'
require 'rubygame/queue'
require 'rubygame/rect'
require 'rubygame/surface'
require 'rubygame/sprite'
#require 'rubygame/vector2'
require 'rubygame/ttf'
require 'rubygame/screen'
require 'color'

include Rubygame

class Game
	# Size of a block on screen
	BLKSIZE = 100
	# Size of a statistics block on screen
	STATBLKOUTERWIDTH = 25
	# Size of a statistics block on screen
	STATBLKINNERWIDTH = 22

	# ORIENTATIONS hash is used to translate 4
	# swiping directions into symbols :col or :row
	# See +shake_board+, +translate_arrays+, +shake+
	ORIENTATIONS = {
		north: :col,
		south: :col,
		east:  :row,
		west:  :row
	}

	# DIRECTIONS hash is used to translate 4
	# swiping directions into symbols :pos or :neg
	# See shake_board, translate_arrays, shake
	DIRECTIONS = {
		north: :pos,
		west:  :pos,
		south: :neg,
		east:  :neg
	}

	KEY_TRANSLATE = {
		left:  :west,
		right: :east,
		up:    :north,
		down:  :south
	}

	def initialize (options)
		@board_size = options[:board_size] || 4

		@empty_spots = Array.new
		@stat_block = nil
		@board = Array.new(@board_size**2) { 0 }
		@moves = 0
		@stats_sorted = [ [ "   2", [ 1, 1 ] ] ]

		TTF.setup
		$font = TTF.new "/usr/share/fonts/TTF/Monaco_Linux.ttf", 36

		@screen = Screen.open [@board_size*BLKSIZE, @board_size*BLKSIZE+10]
		@screen.title = "2048"

		blkcnt = @board_size**2-1
		@blocks = Array.new(blkcnt) { Surface.new [BLKSIZE, BLKSIZE] }
		@colors = Array.new(blkcnt)
		@empty_surface = Surface.new [@board_size*BLKSIZE, 16]

		@blocks.each_with_index do |sfc, i|
			#hue = 360.0 - i.to_f / blkcnt * 360.0
			hue = (i * 67) % 360
			amt = i.to_f/blkcnt
			c = Color::HSL.new(  hue,							# what color
										(i==0)?10:80+10.0*amt,	# 'amount of color'
										50+(25.0*amt)).to_rgb	# black to white
			color = [ c.red, c.green, c.blue ]
			@colors[i] = color
			sfc.draw_box_s [10, 10], [BLKSIZE-10, BLKSIZE-10], color

			if i > 0
				txt = $font.render_utf8 (2**i).to_s, true, [0, 0, 0]
				txtrct = txt.make_rect
				txtrct.topleft = [ (sfc.width - txtrct.width) / 2, (sfc.height - txtrct.height) / 2 ]
				txt.blit sfc, txtrct
			end
		end
		@rect = @blocks[0].make_rect

		@event_queue = EventQueue.new
		@event_queue.enable_new_style_events
	end

	def set_x_y (x, y, val)
		pos = map_x_y(i)
		if is_in_range? pos
			@board[pos] = val
		end
	end

	def map_x_y (x, y)
		(x-1)*@board_size+y-1
	end

	def map_i (i)
		[(i % @board_size) + 1, (i / @board_size) + 1]
	end

	def get_board (x, y)
		if x >= 1 && y >= 1 && x <= @board_size && y <= @board_size then
			@board[(x-1)*@board_size+y-1] || 0
		else
			nil
		end
	end

	def is_in_range? (i)
		i >= 0 && i < (@board_size**2)
	end

	def show_board
		# draw stats
		@empty_surface.blit @screen, @empty_surface.make_rect
		@stats_sorted.each do |a|
			tileno, amt = a[1][0], a[1][1]
			@stat_block = Surface.new [STATBLKINNERWIDTH, amt*2]
			@stat_block.draw_box_s [0, 0], [STATBLKINNERWIDTH, amt*2], @colors[tileno]
			rect = @stat_block.make_rect
			rect.topleft = [ 2+STATBLKOUTERWIDTH*tileno, 2 ]
			@stat_block.blit @screen, rect
		end

		# draw tiles
		bs = @board_size
		(1..bs).each do |y|
			(1..bs).each do |x|
				x0, y0 = x-1, y-1
				rect = @rect
				flat = y0*@board_size+x0
				rect.topleft = [ BLKSIZE*(flat % @board_size), 10+BLKSIZE*(flat / @board_size) ]
				@blocks[get_board(y, x)].blit @screen, rect
			end
		end

		@screen.flip
	end

	def generate_new
		@empty_spots.clear
		@board.each_with_index { |tile, i| @empty_spots.push(i) if tile == 0 }
		if @empty_spots.length == 0		# game over detection still fails.. need to check if moves can be made
			return false
		else
			place = rand(0..@empty_spots.length-1)
			@board[@empty_spots[place]] = 1
		end
		true
	end

	def get_input
		res = nil
		while event = @event_queue.wait
			if event.is_a? Events::KeyPressed
				if KEY_TRANSLATE.has_key? event.key
					res = KEY_TRANSLATE[event.key]
					break
				elsif event.key == :escape
					res = nil
					break
				end
			end
		end
		res
	end

	def translate_arrays(orientation, direction)
		bs = @board_size
		res = Array.new(bs) { Array.new(bs) {0} }
		max = bs**2-1

		(0..max).each do |i|
			y, x = i / bs, i % bs
			flat = (direction == :pos) ? i : max - i
			ry, rx = flat/bs, flat%bs
			res[y][x] = (orientation == :row) ? @board[ry*bs+rx] : @board[rx*bs+ry]
		end

		res
	end

	def untranslate_arrays(b, orientation, direction)
		bs = @board_size
		res = Array.new (bs**2)
		max = bs**2-1

		(0..max).each do |i|
			y, x = i / bs, i % bs
			flat = (direction == :pos) ? i : max - i
			ry, rx = flat/bs, flat%bs
			res[i] = (orientation == :row) ? b[ry][rx] : b[rx][ry]
		end

		res
	end

	def shake(ary)
		bs = @board_size
		used_in_collision = Array.new(bs) { false }
		(1..bs-1).each do |i|
			if ary[i] != 0
				move_value = ary[i]
				searchleft = i - 1
				while searchleft >= 0
					if ary[searchleft] == 0
						searchleft -= 1
					else
						break
					end
				end
				searchleft = 0 if searchleft == -1
				collide_value = ary[searchleft]
				if move_value == collide_value and not used_in_collision[searchleft]
					ary[searchleft] += 1
					used_in_collision[searchleft] = true
					ary[i] = 0
					@move_made = true
				elsif collide_value != 0 and searchleft+1 != i
					ary[searchleft+1] = ary[i]
					ary[i] = 0
					@move_made = true
				elsif collide_value == 0 and searchleft != i
					ary[searchleft] = ary[i]
					ary[i] = 0
					@move_made = true
				end
			end
		end
		ary
	end

	def shake_board(movement)
		orientation = ORIENTATIONS[movement]
		direction   = DIRECTIONS[movement]
		workboard = translate_arrays(orientation, direction)

		@move_made = false
		workboard = workboard.map { |a| shake(a) }
		if @move_made
			@moves += 1
		end

		@board = untranslate_arrays(workboard, orientation, direction)
	end

	def update_stats
		stats = Hash.new (0)
		@board.each do |tile|
			if tile > 0
				tilename = ("%4d" % (2**tile)).to_sym
				stats.update(tilename => [tile, stats[tilename][1]+1])
			end
		end
		@stats_sorted = stats.sort_by {|k, v| v[0]}
	end

	def game_over
		puts "Your highest tile was: " + (2**@board.max).to_s
		puts "Moves: " + @moves.to_s
		score = (@board.inject { |sum, x| sum + ((x>0)?(2**x):0) })
		print "Your score: " + score.to_s
		if score > $highscore
			puts
			puts "Personal record!"
			$highscore = score
			File.open("highscore", "w") { |f| f.puts score.to_s }
		else
			puts "  (highscore %d)" % $highscore
		end
		puts "Tiles:"
		@stats_sorted.each { |a| puts "%s: %2d" % [a[0], a[1][1]] }
	end

	def launch
		generate_new
		while true
			show_board
			if inp = get_input
				shake_board inp
			else
				break
			end
			if @move_made
				if not generate_new
					break
				end
				update_stats
			end
		end
		game_over
	end
end

# main
if __FILE__ == $0
	File.open("highscore", "r") { |f| $highscore = f.gets.chomp.to_i }


	game = Game.new board_size: 4
	puts
	game.launch

	Rubygame.quit
end
