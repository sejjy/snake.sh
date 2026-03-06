#!/usr/bin/env bash
# shellcheck disable=SC2034
#
# snake.sh: A text-based snake game.
#
# Author:  Jesse Mirabel <sejjymvm@gmail.com>
# Date:    January 3, 2026
# License: MIT

#------------------------------------------------------------------------------#
#   CONSTANTS                                                                  #
#------------------------------------------------------------------------------#

#------------#
#   config   #
#------------#

# seconds between frames
DELAY=0.15

KEY_U='w'
KEY_L='a'
KEY_D='s'
KEY_R='d'

GRID_WIDTH=20
GRID_HEIGHT=20

WALL_H='─'
WALL_V='│'
WALL_TL='┌'
WALL_TR='┐'
WALL_BL='└'
WALL_BR='┘'

CHAR_HEAD='0'
CHAR_BODY='o'
CHAR_TILE='.'
CHAR_APPLE='@'

#-----------#
#   style   #
#-----------#

MD_RESET="\e[0m"
MD_BOLD="\e[1m"
MD_DIM="\e[2m"

FG_RED="\e[31m"
FG_GREEN="\e[32m"
FG_YELLOW="\e[33m"
FG_BLUE="\e[34m"
FG_MAGENTA="\e[35m"
FG_CYAN="\e[36m"
FG_GRAY="\e[90m"

#------------#
#   layout   #
#------------#

CANVAS_WIDTH=$((GRID_WIDTH * 2 + 3))
CANVAS_HEIGHT=$((GRID_HEIGHT + 2))

# get the values of LINES and COLUMNS
shopt -s checkwinsize; (:;:)

OFFSET_X=$(((COLUMNS - CANVAS_WIDTH) / 2))
OFFSET_Y=$(((LINES - CANVAS_HEIGHT + 4) / 2))
CENTER_X=$(((CANVAS_WIDTH - 29) / 2))

#------------------------------------------------------------------------------#
#   FUNCTIONS                                                                  #
#------------------------------------------------------------------------------#

# use escape codes instead of forking out to tput
tput() {
	case $1 in
		smcup) printf "\e[?1049h" ;;
		rmcup) printf "\e[?1049l" ;;
		civis) printf "\e[?25l" ;;
		cnorm) printf "\e[?25h" ;;
		cup)
			# x and y coordinates
			printf "\e[%d;%dH" $(($3 + OFFSET_Y + 1)) \
			                   $(($2 + OFFSET_X + 1))
			;;
	esac
}

draw_char() {
	tput cup $(($1 * 2 + 2)) $(($2 + 1))

	case $3 in
		"$CHAR_HEAD")  printf "%b%s%b" "$MD_BOLD$FG_BLUE" "$3" "$MD_RESET" ;;
		"$CHAR_BODY")  printf "%b%s%b" "$FG_BLUE"         "$3" "$MD_RESET" ;;
		"$CHAR_APPLE") printf "%b%s%b" "$FG_RED"          "$3" "$MD_RESET" ;;
		"$CHAR_TILE")  printf "%b%s%b" "$MD_DIM$FG_GRAY"  "$3" "$MD_RESET" ;;
	esac
}

display_art() {
	printf "%b" "$FG_GREEN"

	local art=(
		"█▀▀ █▀█ █▀█ █ █ █▀▀   █▀▀ █ █"
		"▀▀█ █ █ █▀█ █▀▄ █▀▀   ▀▀█ █▀█"
		"▀▀▀ ▀ ▀ ▀ ▀ ▀ ▀ ▀▀▀ ▀ ▀▀▀ ▀ ▀"
	)

	local i
	for ((i = 0; i < ${#art[@]}; i++)); do
		tput cup $CENTER_X $((-5 + i))

		if ((i == ${#art[@]} - 1)); then
			printf "%b" "$MD_DIM"
		fi
		printf "%s" "${art[$i]}"
	done

	printf "%b" "$MD_RESET"
}

display_score() {
	tput cup $CENTER_X -1

	printf "%bscore:%b %03d     %bhighscore:%b %03d" \
	       "$MD_DIM" "$MD_RESET" $SCORE              \
	       "$MD_DIM" "$MD_RESET" $HIGHSCORE
}

draw_walls() {
	local line
	printf -v line "%$((CANVAS_WIDTH - 2))s" ''

	local top="$WALL_TL${line// /$WALL_H}$WALL_TR"
	local mid="$WALL_V$line$WALL_V"
	local bot="$WALL_BL${line// /$WALL_H}$WALL_BR"

	tput cup 0 0
	printf "%b" "$MD_DIM$FG_GREEN"
	printf "%s" "$top"

	local y
	for ((y = 1; y < CANVAS_HEIGHT - 1; y++)); do
		tput cup 0 $y
		printf "%s" "$mid"
	done

	tput cup 0 $((CANVAS_HEIGHT - 1))
	printf "%s" "$bot"
	printf "%b" "$MD_RESET"
}

draw_tiles() {
	local tiles
	printf -v tiles "%$((GRID_WIDTH))s" ''
	tiles=${tiles// /$CHAR_TILE }

	printf "%b" "$MD_DIM$FG_GRAY"

	local y
	for ((y = 0; y < GRID_HEIGHT; y++)); do
		tput cup 2 $((y + 1))
		printf "%s" "$tiles"
	done

	printf "%b" "$MD_RESET"
}

display_controls() {
	tput cup $CENTER_X $CANVAS_HEIGHT

	printf "%s%b: move%b       esc%b: exit%b" \
	       "$KEY_U $KEY_L $KEY_D $KEY_R"      \
	       "$MD_DIM" "$MD_RESET"              \
	       "$MD_DIM" "$MD_RESET"
}

update_apple_pos() {
	# make sure the apple spawns in an empty tile
	while true; do
		apple_x=$((RANDOM % GRID_WIDTH))
		apple_y=$((RANDOM % GRID_HEIGHT))

		# avoid the head
		if ((apple_x == head_x && apple_y == head_y)); then
			continue
		fi

		local is_empty=true

		# avoid the body
		local i
		for ((i = 0; i < ${#body_x[@]}; i++)); do
			if ((apple_x == body_x[i] && apple_y == body_y[i])); then
				is_empty=false
				break
			fi
		done

		$is_empty && break
	done

	draw_char $apple_x $apple_y "$CHAR_APPLE"
}

validate_move() {
	# check wall collision
	if ((head_x < 0 || head_x >= GRID_WIDTH)) ||
		((head_y < 0 || head_y >= GRID_HEIGHT)); then
		return 1
	fi

	# check self collision
	local i
	for ((i = 0; i < ${#body_x[@]}; i++)); do
		if ((head_x == body_x[i] && head_y == body_y[i])); then
			return 1
		fi
	done

	is_eaten=false

	# check if the apple is eaten
	if ((head_x == apple_x && head_y == apple_y)); then
		is_eaten=true

		body_x+=("${body_x[-1]}")
		body_y+=("${body_y[-1]}")

		SCORE=$((SCORE + 1))
		display_score
		update_apple_pos
	fi
}

update_snake_pos() {
	prev_tail_x=${body_x[-1]}
	prev_tail_y=${body_y[-1]}

	local i
	for ((i = ${#body_x[@]} - 1; i > 0; i--)); do
		body_x[i]=${body_x[i - 1]}
		body_y[i]=${body_y[i - 1]}
	done
	body_x[0]=$prev_head_x
	body_y[0]=$prev_head_y

	# do not draw if the apple is at the previous tail position
	if ! $is_eaten && ((prev_tail_x != apple_x || prev_tail_y != apple_y)); then
		draw_char "$prev_tail_x" "$prev_tail_y" "$CHAR_TILE"
	fi
	draw_char $prev_head_x $prev_head_y "$CHAR_BODY"
	draw_char $head_x $head_y "$CHAR_HEAD"
}

handle_input() {
	# accept arrow keys as input
	if [[ $REPLY == $'\e' ]]; then
		local reply
		read -rsn 2 -t 0.001 reply
		REPLY+=$reply
	fi

	case $REPLY in
		$'\e[A' | "$KEY_U") ((dir_y !=  1)) && { dir_x=0  dir_y=-1; } ;;
		$'\e[B' | "$KEY_D") ((dir_y != -1)) && { dir_x=0  dir_y=1; } ;;
		$'\e[C' | "$KEY_R") ((dir_x != -1)) && { dir_x=1  dir_y=0; } ;;
		$'\e[D' | "$KEY_L") ((dir_x !=  1)) && { dir_x=-1 dir_y=0; } ;;
		$'\e') exit 0 ;;
	esac
}

init_game() {
	if ((SCORE > HIGHSCORE)); then
		HIGHSCORE=$SCORE
	fi
	SCORE=0
	display_score

	# set spawn points
	apple_x=$((GRID_WIDTH / 2))
	apple_y=$((GRID_HEIGHT / 2))
	head_x=$((GRID_WIDTH / 4))
	head_y=$((GRID_HEIGHT / 2))
	body_x=($((head_x - 1)) $((head_x - 2)))
	body_y=($((head_y)) $((head_y)))

	dir_x=0
	dir_y=0

	# draw initial canvas
	draw_tiles
	local i
	for ((i = 0; i < ${#body_x[@]}; i++)); do
		draw_char "${body_x[$i]}" "${body_y[$i]}" "$CHAR_BODY"
	done
	draw_char $head_x $head_y "$CHAR_HEAD"
	draw_char $apple_x $apple_y "$CHAR_APPLE"
}

game_over() {
	tput rmcup # disable the alternative buffer
	tput cnorm # make cursor visible
	stty echo  # turn on echoing

	printf "%bGAME OVER%b\n" "$FG_RED" "$MD_RESET"
	printf "%bscore%b:     %d\n" "$MD_DIM" "$MD_RESET" $SCORE
	printf "%bhighscore%b: %d\n" "$MD_DIM" "$MD_RESET" $HIGHSCORE
}

main() {
	trap game_over EXIT

	tput smcup # enable the alternative buffer
	tput civis # make cursor invisible
	stty -echo # turn off echoing

	display_art
	draw_walls
	display_controls

	SCORE=0
	HIGHSCORE=0
	init_game

	# game loop
	while true; do
		if read -rsn 1 -t $DELAY; then
			handle_input
		fi

		# wait for input before starting
		if ((dir_x == 0 && dir_y == 0)); then
			continue
		fi

		# move the head
		prev_head_x=$head_x
		prev_head_y=$head_y
		head_x=$((head_x + dir_x))
		head_y=$((head_y + dir_y))

		# validate new head position
		if ! validate_move; then
			read -rsn 1
			init_game
			handle_input
			continue
		fi

		# move the body
		update_snake_pos
	done
}

main
