#!/usr/bin/env ruby

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
	attr_reader :board_size, :board

	ORIENTATIONS = {
		north: :col,
		south: :col,
		east:  :row,
		west:  :row
	}
	DIRECTIONS = {
		north: :pos,
		west:  :pos,
		south: :neg,
		east:  :neg
	}
	DISPLAY = [ "[    ]",
	            "[   2]",
					"[   4]",
					"[   8]",
					"[  16]",
					"[  32]",
					"[  64]",
					"[ 128]",
					"[ 256]",
					"[ 512]",
					"[1024]",
					"[2048]",
					"[4096]",
					"[8192]" ]

	def initialize (options)
		@board_size = options[:board_size] # 4
		@screen = options[:screen] # Rubygame::Screen main
		@blocks = options[:blocks] # Rubygame::Surface array
		@rect = options[:rect] # Rubygame::Rectangle to modify for blitting
		@event_queue = options[:eq]
		@board = Array.new(@board_size**2) { 0 }
		@moves = 0
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

	def full_range
		(0..(@board_size**2-1))
	end

	def show_board
		bs = @board_size
		(1..bs).each do |y|
			(1..bs).each do |x|
				x0, y0 = x-1, y-1
				rct = @rect
				flat = y0*@board_size+x0
				rct.topleft = [ BLKSIZE*(flat % @board_size), BLKSIZE*(flat / @board_size) ]
				@blocks[get_board(y, x)].blit @screen, rct
			end
		end
		@screen.flip
	end

	def generate_new
		done = false
		until done
			place = rand(full_range)
			if @board[place] == 0
				@board[place] = 1
				done = true
			end
		end
	end

	def get_input
		res = nil
		while event = @event_queue.wait
			if event.is_a? Rubygame::Events::KeyPressed
				case event.key
				when :left
					res = :west
					break
				when :up
					res = :north
					break
				when :down
					res = :south
					break
				when :right
					res = :east
					break
				when :escape
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

	def game_over
		puts "Your highest tile was: " + DISPLAY[@board.max]
		puts "Moves: " + @moves.to_s
		score = (@board.inject { |sum, x| sum + ((x>0)?(2**x):0) })
		puts "Your score: " + score.to_s
		if score > $highscore
			puts "Personal record!"
			$highscore = score
			File.open("highscore", "w") { |f| f.puts score.to_s }
		end
	end

	def check_game_over
		res = true
		bs = @board_size
		(1..bs).each do |x|
			(1..bs-1).each do |y|
				if get_board(x,y) == 0 or
					get_board(x,y) == get_board(x,y+1) or
					get_board(y,x) == get_board(y+1,x) then
					res = false
					break
				end
			end
			break if not res
		end
		res
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
				generate_new
				#if check_game_over
					#break
				#end
			end
		end
		game_over
	end
end

# main
if __FILE__ == $0
	File.open("highscore", "r") { |f| $highscore = f.gets.chomp.to_i }

	TTF.setup
	$font = TTF.new "/usr/share/fonts/TTF/Monaco_Linux.ttf", 36

	@screen = Screen.open [400, 400]
	@screen.title = "2048"

	BLKCNT = 15
	BLKSIZE = 100
	@blocks = Array.new(BLKCNT) { Surface.new [BLKSIZE, BLKSIZE] }

	@blocks.each_with_index do |sfc, i|
		#hue = 360.0 - i.to_f / BLKCNT * 360.0
		hue = (i * 67) % 360
		c = Color::HSL.new(hue, (i==0)?10:90, 50+(25.0*(i.to_f/BLKCNT))).to_rgb
		color = [ c.red, c.green, c.blue ]
		sfc.draw_box [10, 10], [90, 90], color

		if i > 0
			txt = $font.render_utf8 (2**i).to_s, true, color
			txtrct = txt.make_rect
			txtrct.topleft = [ (sfc.width - txtrct.width) / 2, (sfc.height - txtrct.height) / 2 ]
			txt.blit sfc, txtrct
		end
	end
	rct = @blocks[0].make_rect

	@event_queue = EventQueue.new
	@event_queue.enable_new_style_events

	game = Game.new board_size: 4, screen: @screen, blocks: @blocks, rect: rct, eq: @event_queue
	puts
	game.launch

	Rubygame.quit
end
