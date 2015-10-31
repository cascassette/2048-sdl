#!/usr/bin/env ruby

class Game
	attr_reader :board_size, :board

	USAGE =
"""Usage:
H - Left
C - Up
T - Down
N - Right"""

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
	            "[  2 ]",
					"[  4 ]",
					"[  8 ]",
					"[ 16 ]",
					"[ 32 ]",
					"[ 64 ]",
					"[ 128]",
					"[ 256]",
					"[ 512]",
					"[1024]",
					"[2048]",
					"[4096]",
					"[8192]" ]

	def initialize
		@board_size = 4
		@newlines = 2
		@board = Array.new(@board_size**2) { 0 }
		@tilesize = 3
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

	def print_board
		(1..@board_size).each do |x|
			(1..@board_size).each do |y|
				#print "%#{@tilesize}d " % get_board(x, y)
				print DISPLAY[get_board(x, y)] + " "
			end
			(1..@newlines).each { puts }
		end
	end

	def generate_new
		if not full_range.any? { |i| @board[i] == 0 }
			puts "Game over"
			exit
		end
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
		puts "Input?"
		done = false
		res = 0
		until done
			move = gets
			done = true
			case move.chomp.upcase
			when "H"
				res = :west
			when "C"
				res = :north
			when "T"
				res = :south
			when "N"
				res = :east
			when "STOP"
				puts "Your highest tile was: " + DISPLAY[@board.max]
				exit
			else
				puts "Invalid"
				done = false
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
		puts "you have chosen to shake " + movement.to_s.upcase + "wards"
		orientation = ORIENTATIONS[movement]
		direction   = DIRECTIONS[movement]
		workboard = translate_arrays(orientation, direction)

		@move_made = false
		workboard = workboard.map { |a| shake(a) }

		@board = untranslate_arrays(workboard, orientation, direction)
	end

	def launch
		generate_new
		while true
			print_board
			shake_board get_input
			if @move_made
				generate_new
			end
		end
	end
end

# main
if __FILE__ == $0
	game = Game.new
	puts Game::USAGE
	puts
	game.launch
end
