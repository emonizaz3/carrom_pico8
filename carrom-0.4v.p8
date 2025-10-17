pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- carrom game
function _init()
	game_state = "menu"
	menu_selection = 3 -- 1: p1, 2: p2, 3: play
	p1_type = "human"
    p2_type = "computer"
	stars = {}
	for i=1,9 do
		stars[i] = {
			x = rnd(138) - 10,
			y = rnd(138) - 10,
			speed = rnd(0.5) + 0.6,
			sprite = flr(rnd(2)) * 16
		}
	end
	dither_bg_transition = make_dither_transition_instance()
    dither_rect_transition = make_dither_transition_instance()
end

function _update60()
	if game_state == "menu" then
		menu_update()
	elseif game_state == "game" then
		game_update()
	elseif game_state == "paused" then
		pause_update()
	elseif game_state == "game_over" then
		if btnp(🅾️) or btnp(❎) then
			game_state = "menu"
		end
	end
end

function _draw()
	if game_state == "menu" then
		menu_draw()
	elseif game_state == "game" then
		game_draw()
	elseif game_state == "paused" then
		pause_draw()
	elseif game_state == "game_over" then
		game_over_draw()
	end
end

function game_init()
	stri = {sx=48,sy=32,x=64,y=115,dx=0,dy= 0,r=5, c=7,speed=0.5,accel=0.3,friction=0.015,state="initializing",ani=false,ani_x=0,ani_y=0,inhole=false}
	--stri.state = "positioning" or "aiming" or "simulating" or "initializing"
	p_red = {sx=32,sy=32,x=64,y=64,r=5,c=8,dx=0,dy=0,friction=0.02,inhole=false,value=3}
	p_white = {}
	p_black = {}
	p_white_pocketed = {}
	p_black_pocketed = {}
	holes ={
		{x=5,y=5,r=6,c=7,effect_f=0},
		{x=5,y=122,r=6,c=7,effect_f=0},
		{x=122,y=5,r=6,c=7,effect_f=0},
		{x=122,y=122,r=6,c=7,effect_f=0}
	}
	ani_timer = 0
	local start_angle = 30 
	local start_rotation = start_angle / 360
	local center_x, center_y = 64, 64
	local radius = 10
	local piece_delay = 0
	for j=1,2 do
		if j==2 then
			 radius=21
		end
		for i=1,3*j do
			local angle = (i-1) * 60
			local ang_rad = (angle/360)*(2/j) + start_rotation
			piece_delay += 10
			add(p_white,{name='white',sx=0,sy=32,
			ani_x=flr(center_x+radius*cos(ang_rad)+0.5),
			ani_y=flr(center_y+radius*sin(ang_rad)+0.5),
			r=5,c=7,dx=0,dy=0,friction=0.02,
			ani=false,
			ani_progress=0,
			ani_delay=piece_delay,
			x=flr(rnd(140 - (-20) + 1)) + (-20),
			y=-10 - rnd(15)})
			--------------------------------------------
			angle = (i-1) * 60 + 30
			ang_rad = (angle/360)*(2/j) + start_rotation
			piece_delay += 1
			add(p_black,{name='black',sx=16,sy=32,
			ani_x=flr(center_x+radius*cos(ang_rad)+0.5),
			ani_y=flr(center_y+radius*sin(ang_rad)+0.5),
			r=5,c=0,dx=0,dy=0,friction=0.02,
			ani=false,
			ani_progress=0,
			ani_delay=piece_delay,
			x=flr(rnd(140 - (-20) + 1)) + (-20),
			y=-10 - rnd(15)})
		end
	end
	aim={r=20.5,c=8,ang=90,speed=0,accel=0.3,friction=0.1}
	arrow_pause=3
	p1 = {name="Player 1",score=0,piece='white',is_ai=false}
	p2 = {name="Player 2",score=0,piece='black',is_ai=false}
	if p1_type == "computer" then p1.is_ai = true end
	if p2_type == "computer" then p2.is_ai = true end
	p_turn = p1
	pieces_pocketed_this_turn = 0
	pocketed_in_turn = {}
	red_pocketed_by = nil
	red_needs_confirmation = false
	red_pocketed_this_turn = false
	
	ai_state = "positioning" -- or "aiming" or "shooting" or "waiting"
	ai_target_pos = {}
	ai_target_angle = 0
	ai_shot_power = 0
	ai_timer = 0
end

function game_update()
    if stri.state == "initializing" then
        update_piece_animations()
        if ani_timer > 150 and all_ani_stopped() then
            stri.state = "positioning"
            if p_turn.is_ai then
                ai_state = "positioning"
            end
        end
    elseif not all_ani_stopped() then
        run_active_animations()
    elseif stri.state == "positioning" then
		if btnp(❎) then
            game_state = "paused"
            pause_selection = 1
            sfx(5)
            return
        end
        if p_turn.is_ai then
            ai_opponent_turn()
        else
            move_con()
        end
    elseif stri.state == "aiming" then
        if p_turn.is_ai then
            ai_opponent_turn()
        else
            aim_con()
            shoot_con()
        end
    elseif stri.state == "simulating" then
        local is_finished = universal_physics()
        if is_finished then
            aim.speed = 0
            aim.r = 20.5
            stri.start_x = stri.x
            stri.start_y = stri.y
            stri.ani_progress = 0
            stri.ani = true
            stri.inhole = false
            switch_player()
        end
    end
end

function game_draw()
	cls(13)
	map(0,0,0,0,16,16)
	for h in all(holes) do draw_hole(h) end
	for h in all(holes) do hole_fall_effect(h,h.c) end
	if stri.state == "aiming" and (not p_turn.is_ai or ai_state == "aiming") then
		draw_aimline(stri.x,stri.y,aim.r+8,aim.ang,aim.c)
	end
	for p in all(p_white) do 
		if p.ani then draw_piece(p, 2) else draw_piece(p) end
	end
	for p in all(p_black) do 
		if p.ani then draw_piece(p, 2) else draw_piece(p) end
	end
	if not p_red.inhole then
		draw_piece(p_red)
	end
	
	if stri.ani then
		draw_piece(stri, 2)
	elseif not stri.inhole then
		if stri.state == "positioning" and not p_turn.is_ai then
			draw_piece(stri, 1)
			if time()>arrow_pause then
				draw_movement_arrows()
			end
		else
			draw_piece(stri)
		end
	end
end

-->8
--game menu functions
function menu_update()
	if btnp(⬆️) then
		menu_selection -= 1
		if menu_selection < 1 then menu_selection = 3 end
		sfx(5)
	elseif btnp(⬇️) then
		menu_selection += 1
		if menu_selection > 3 then menu_selection = 1 end
		sfx(5)
	end
	if btnp(⬅️) or btnp(➡️) then
		if menu_selection == 1 then
			p1_type = (p1_type == "human") and "computer" or "human"
			sfx(5)
		elseif menu_selection == 2 then
			p2_type = (p2_type == "human") and "computer" or "human"
		end
	end

	if btnp(🅾️) then
		if menu_selection == 3 then
			game_init() -- Reset board
			game_state = "game"
			sfx(1) -- start sound
		end
	end

	for star in all(stars) do
		star.y += star.speed
		if star.y > 128 then
			star.y = -10
			star.x = rnd(138)-10
			star.speed = rnd(0.5) + 0.4
		end
	end
end

function menu_draw()
	cls(1) -- Dark blue background
	dither_bg_transition(0,0,128,128,"diag", 10,10)
	for star in all(stars) do
		sspr(star.sprite, 32, 11, 11, star.x, star.y)
	end

	local title = "carrom"
	local x = 64 - (#title*4)/2
	print(title, x, 30, 7)
	palt(0,false)
	palt(1,true)
	-- sspr(0,108,57,20,64-57,9,114,40)
	sspr(0,114,37,13,64-57,21,74,26)
	sspr(36,108,10,13,79,11 + sin((time() * 0.22)) * 4,20,26) --animate logo here
	sspr(45,114,12,13,97,21,24,26)
	draw_aimline(34,14,43,360,8)
	sspr(0,95,28,10,10,10)
	palt(0,true)
	palt(1,false)


	rect(24,51,104,103,7)
	dither_rect_transition(25,52,40,51,"ltr", 40,20)
	dither_rect_transition(64,52,40,51,"rtl", 40,20)
	rectfill(28,54,100,100,7)
	rectfill(29,55,99,99,6)
	

	--menu options
	local c1, c2 , c3= 7, 7,7
	local cursor_y = 0

	if menu_selection == 1 then c1 = 7; cursor_y = 60
	elseif menu_selection == 2 then c2 = 7; cursor_y = 75
	else c3 = 7; cursor_y = 90 end

	--i want a retangle bar behind the text to highlight the selection using cursor_y
	rectfill(45+2,cursor_y-5+2,99-2,cursor_y+9-2, 13)
	local offset = 9
	local txt1 = p1_type
	text_outline(txt1, 64 - (#txt1*2) + offset, 60, c1,1)
	sspr(0,32,11,11,34, 57,11,11)

	local txt2 = p2_type
	text_outline(txt2, 64 - (#txt2*2) + offset, 75, c2,1)
	sspr(16,32,11,11,34,72,11,11)

	local txt3 = "play"
	text_outline(txt3, 64 - (#txt3*2) + offset, 90, 7,1)

	if menu_selection == 3 then
	else
		print("<", 50 + sin((time() * 0.65)) * 1, cursor_y , 7)
		print(">", 93 - sin((time() * 0.65)) * 1, cursor_y , 7)
	end
end
function pause_draw()
	
	game_draw()
	
	rectfill(30, 30, 97, 97, 0)

	local title = "- PAUSED -"
	print(title, 64 - (#title * 2), 40, 7)

	local c1, c2 = 6, 6
	if pause_selection == 1 then c1 = 10 else c2 = 10 end

	local txt1 = "RESUME"
	print(txt1, 64 - (#txt1 * 2), 60, c1)
	
	local txt2 = "QUIT TO MENU"
	print(txt2, 64 - (#txt2 * 2), 75, c2)
	
	-- Draw the selector arrow
	if pause_selection == 1 then
		print(">", 45, 60, 7)
	else
		print(">", 32, 75, 7)
	end
end
function pause_update()
	if btnp(⬆️) or btnp(⬇️) then
		if pause_selection == 1 then pause_selection = 2 else pause_selection = 1 end
		sfx(5)
	end

	-- Player presses the action button
	if btnp(🅾️) then
		if pause_selection == 1 then -- Resume
			game_state = "game"
		elseif pause_selection == 2 then -- Quit to Menu
			game_state = "menu"
		end
		sfx(1)
	end

    -- Also allow resuming with the back button
    if btnp(❎) then
        game_state = "game"
        sfx(1)
    end
end

function game_over_draw()
	cls(0)
	local winner = ""
	if #p_white_pocketed >= 9 then winner = p1.name
	else winner = p2.name end
	
	local txt = "game over"
	print(txt, 64-(#txt*2), 50, 7)
	
	txt = winner.." wins!"
	print(txt, 64-(#txt*2), 65, 10)
	
	txt = "press ❎ or 🅾️"
	print(txt, 64-(#txt*2), 90, 6)
end
function make_dither_transition_instance()
    -- Each instance will have its own 'state' table,
    -- which is "closed over" by the returned function.
    local instance_state = {
        old_col = flr(rnd(16)),
        new_col = flr(rnd(16)),
        old_pat = flr(rnd(0xffff)),
        new_pat = flr(rnd(0xffff)),
        t = 0,
        phase = "transition", -- "transition" or "pause"
        timer = 10,
    }

    -- This is the actual function that will draw the transition,
    -- but it uses its own instance_state.
    return function(x, y, w, h, dir, speed, pause_time)
        local dt = 1/30 -- PICO-8 runs at 30fps

        if instance_state.phase == "transition" then
            instance_state.t += speed * dt
            if instance_state.t > w then
                instance_state.t = w
                instance_state.phase = "pause"
                instance_state.timer = 0
            end
        elseif instance_state.phase == "pause" then
            instance_state.timer += dt
            if instance_state.timer >= pause_time then
                -- reset for next transition
                instance_state.t = 0
                instance_state.phase = "transition"
                instance_state.old_col = instance_state.new_col
                instance_state.old_pat = instance_state.new_pat
                instance_state.new_col = flr(rnd(16))
                instance_state.new_pat = flr(rnd(0xffff))
            end
        end
        local cols = flr(instance_state.t)
        -- draw old pattern/color
        fillp(instance_state.old_pat)
        rectfill(x, y, x + w - 1, y + h - 1, instance_state.old_col)
        -- draw new pattern/color sliding
        fillp(instance_state.new_pat)
        if dir == "rtl" then
            rectfill(x + w - cols, y, x + w - 1, y + h - 1, instance_state.new_col)
        elseif dir == "ltr" then
            rectfill(x, y, x + cols - 1, y + h - 1, instance_state.new_col)
        elseif dir == "ttb" then
            rectfill(x, y + h - cols, x + w - 1, y + h - 1, instance_state.new_col)
        elseif dir == "btt" then
            rectfill(x, y, x + w - 1, y + cols - 1, instance_state.new_col)
        elseif dir == "diag" then
            for i=0,cols do
                line(x+i,y,x,y+i,instance_state.new_col)
                line(x+w-i,y+h,x+w,y+h-i,instance_state.new_col)
                line(x+w-i,y,x+w,y+i,instance_state.new_col)
                line(x+i,y+h,x,y+h-i,instance_state.new_col)
            end
        end
        fillp() -- reset fillp
    end
end
function text_outline(txt, x, y, col, outline_col)
	outline_col = outline_col or 0
	-- Draw outline
	print(txt, x - 1, y, outline_col)
	print(txt, x + 1, y, outline_col)
	print(txt, x, y - 1, outline_col)
	print(txt, x, y + 1, outline_col)
	print(txt, x - 1, y - 1, outline_col)
	print(txt, x + 1, y - 1, outline_col)
	print(txt, x - 1, y + 1, outline_col)
	print(txt, x + 1, y + 1, outline_col)
	-- Draw main text
	print(txt, x, y, col)
end
-->8
--physics functions
function universal_physics()
	local all_pieces = {}
	if not stri.inhole then
		add(all_pieces, stri)
	end
	if not p_red.inhole then
		add(all_pieces, p_red)
	end
	for p in all(p_white) do add(all_pieces, p) end
	for p in all(p_black) do add(all_pieces, p) end
	for h in all(holes) do
		for i=#all_pieces,1,-1 do
			local p = all_pieces[i]
			if check_hole_collision(p, h) then
				h.effect_f=30
				if p == stri then
					stri.dx = 0
					stri.dy = 0
					stri.inhole=true
					h.c = 12
					pieces_pocketed_this_turn = -999
				elseif p == p_red then
					del(all_pieces, p)
					p.inhole=true
					h.c = 8
					if not red_needs_confirmation then
						p_turn.score += p_red.value
						pieces_pocketed_this_turn += 1
						red_needs_confirmation = true
						red_pocketed_this_turn = true
						add(pocketed_in_turn, p_red)
					end
				elseif p.name == 'white' then
					del(all_pieces, p)
					del(p_white, p)
					add(p_white_pocketed, p)
					p.inhole=true
					h.c = 7
					if p_turn.piece == 'white' then
						add(pocketed_in_turn, p)
						p_turn.score += 1
						pieces_pocketed_this_turn += 1
					end
				else
					del(all_pieces, p)
					del(p_black, p)
					add(p_black_pocketed, p)
					p.inhole=true
					h.c = 6
					if p_turn.piece == 'black' then
						add(pocketed_in_turn, p)
						p_turn.score += 1
						pieces_pocketed_this_turn += 1
					end
				end
			end
		end
	end

	local sub_steps = 8 
	
	for s=1, sub_steps do
		for p in all(all_pieces) do
			p.x += p.dx / sub_steps
			p.y += p.dy / sub_steps
		end

		for i=1, #all_pieces do
			local p1 = all_pieces[i]
			handle_wall_collision(p1)
			for j=i+1, #all_pieces do
				check_collision(p1, all_pieces[j])
			end
		end
	end

	local all_stopped = true
	
	for p in all(all_pieces) do
		p.dx *= (1 - p.friction)
		p.dy *= (1 - p.friction)

		local speed_sq = p.dx*p.dx + p.dy*p.dy
		if speed_sq > 0.005 then
			all_stopped = false
		else
			p.dx = 0
			p.dy = 0
		end
	end

	return all_stopped
end

function handle_wall_collision(p)
	if p.x < p.r or p.x > 127 - p.r then
		sfx(5)
		p.dx = -p.dx
		p.x = mid(p.r, p.x, 127 - p.r)
	end
	if p.y < p.r or p.y > 127 - p.r then
		sfx(5)
		p.dy = -p.dy
		p.y = mid(p.r, p.y, 127 - p.r)
	end
end

function check_collision(p1, p2)
    local dx = p2.x - p1.x
    local dy = p2.y - p1.y
    local dist_sq = dx*dx + dy*dy
    local total_radius = p1.r + p2.r

    if dist_sq < total_radius*total_radius and dist_sq > 0 then
		sfx(1+flr(rnd(3)))
        local dist = sqrt(dist_sq)
        
        -- resolve overlap
        local overlap = (total_radius - dist) * 0.5
        local nx = dx / dist
        local ny = dy / dist
        p1.x -= overlap * nx
        p1.y -= overlap * ny
        p2.x += overlap * nx
        p2.y += overlap * ny

        -- elastic collision response
        local kx = p1.dx - p2.dx
        local ky = p1.dy - p2.dy
        local p = (kx * nx + ky * ny)
        p1.dx -= p * nx
        p1.dy -= p * ny
        p2.dx += p * nx
        p2.dy += p * ny
    end
end

function check_hole_collision(p, h)
	local dx = h.x - p.x
	local dy = h.y - p.y
	local dist_sq = dx*dx + dy*dy
	if dist_sq < (h.r * h.r) then
		sfx(4)
		return true
	end
	return false
end

-->8
--control functions
function move_con()
	if btnp(🅾️) then
		stri.state = "aiming"
		return
	end
	
	if btn(⬅️) and not btn(➡️) then
		stri.dx-=stri.accel
		arrow_pause=time()+3
	elseif btn(➡️) and not btn(⬅️) then
		stri.dx+=stri.accel
		arrow_pause=time()+3
	else 
		stri.dx*= stri.friction 
	end
	
	stri.x+=stri.dx
	if stri.x < stri.r+16 then stri.x = stri.r+16; stri.dx=0 end
	if stri.x > 128-stri.r-17 then stri.x = 128-stri.r-17; stri.dx=0 end
end

function aim_con()
	if btn(⬅️) and not btn(➡️) then
		aim.speed+=aim.accel
	elseif btn(➡️) and not btn(⬅️) then
		aim.speed-=aim.accel
	else 
		aim.speed*=aim.friction 
	end
	aim.ang+=aim.speed
	
	if btn(⬆️) then
		aim.r+=1
	elseif btn(⬇️) then
		aim.r-=1
	end
	aim.r=mid(3,aim.r,80)

	if aim.r >= 55 then aim.c= 8
	elseif aim.r >= 25 then aim.c= 12
	else aim.c= 3 end
end
    
function shoot_con()
	if btnp(🅾️) then
		red_pocketed_this_turn = false
		pieces_pocketed_this_turn = 0
		pocketed_in_turn = {}
		local power = aim.r / 2.5
		power *= stri.speed
		local angle = aim.ang / 360
		stri.dx = cos(angle) * power
		stri.dy = sin(angle) * power
		
		stri.state = "simulating"
		sfx(0)
	elseif btnp(❎) then
		stri.state = "positioning"
	end
end

function all_ani_stopped()
	if stri.ani then return false end
	for p in all(p_white) do
		if p.ani then return false end
	end
	for p in all(p_black) do
		if p.ani then return false end
	end
	return true
end

-->8
--rendering functions
function draw_piece(p,h)
	h = h or 0
	local render_x = flr(p.x + 0.5)
	local render_y = flr(p.y + 0.5)
	local render_r = flr(p.r + 0.5)
	circfill(render_x,render_y+h,render_r,4)
	sspr(p.sx,p.sy,11,11,render_x-p.r,render_y-render_r-h,11,11)
end

function draw_hole(h)
	circfill(h.x,h.y,h.r,13)
	fillp(0b1010101001010101)
	circfill(h.x,h.y,h.r-1,1)
	fillp()
end
function hole_fall_effect(h,c)
	c=c or 7
	if h.effect_f>0 then
		h.effect_f-=1
		local max_r=8
		local effect_r = max_r - (h.effect_f / 30) * max_r
		circ(h.x,h.y,flr(effect_r+0.5),c)
		circ(h.x,h.y,flr(effect_r*0.75+0.5),c)
		circ(h.x,h.y,flr(effect_r*0.5+0.5),c)
		circ(h.x,h.y,flr(effect_r*0.25+0.5),c)
	end
end
function draw_movement_arrows()
	rectfill(stri.x-17,stri.y-2,stri.x-13,stri.y+3,4)
	rectfill(stri.x+12,stri.y-1,stri.x+18,stri.y+2,4)
	for i=-2,-1 do
		print("⬅️",stri.x-18,stri.y+i,4)
		print("➡️",stri.x+12,stri.y+i,4)
	end
	yo=(flr(time()*3)%2==0) and -3 or -2
	print("⬅️",stri.x-18,stri.y+yo,12)
	print("➡️",stri.x+12,stri.y+yo,12)
end

function draw_aimline(px,py,r,deg,c)
	local ang= deg/360
	local newx= px+r*cos(ang)
	local newy= py+r*sin(ang)
	drawarrow(px, py, newx, newy, c, ang)
end

function drawarrow(x1,y1,x2,y2,col,angle)
 if not(x1==x2 and y1==y2) then
  local dx,dy=x2-x1,y2-y1
  local ang,dist=atan2(y2-y1, x2-x1),sqrt(dx*dx + dy*dy)
  local ang2=ang+0.25
  local newx2,newy2=x1+sin(ang)*(dist-7),y1+cos(ang)*(dist-7)
  local sang2,cang2=sin(ang2),cos(ang2)
  local stem={
   x1+sang2*2, y1+cang2*2,
   x1-sang2*2, y1-cang2*2,
   newx2-sang2*2, newy2-cang2*2,
   newx2+sang2*2, newy2+cang2*2
  }
  local tmparr={
   newx2+sang2*5, newy2+cang2*5,
   newx2-sang2*5, newy2-cang2*5,
   x2,y2
  }
  render_poly(stem,col)
  render_poly(tmparr,col)
 end
end

function render_poly(v,col)
 col=col or 5
 local x1,x2={},{}
 for y=0,127 do x1[y],x2[y]=128,-1 end
 local y1,y2=128,-1
 for i=1, #v/2 do
  local next=i+1
  if (next>#v/2) next=1
  local vx1,vy1,vx2,vy2=flr(v[i*2-1]),flr(v[i*2]),flr(v[next*2-1]),flr(v[next*2])
  if vy1>vy2 then
   local tempx,tempy=vx1,vy1
   vx1,vy1=vx2,vy2; vx2,vy2=tempx,tempy
  end
  if vy1~=vy2 and vy1<128 and vy2>=0 then
   if (vy1<0) vx1,vy1=(0-vy1)*(vx2-vx1)/(vy2-vy1)+vx1,0
   if (vy2>127) vx2,vy2=(127-vy1)*(vx2-vx1)/(vy2-vy1)+vx1,127
   for y=vy1,vy2 do
    if (y<y1) y1=y
    if (y>y2) y2=y
    local x=(y-vy1)*(vx2-vx1)/(vy2-vy1)+vx1
    if (x<x1[y]) x1[y]=x
    if (x>x2[y]) x2[y]=x
   end
  end
 end
 for y=y1,y2 do
  if x1[y] <= x2[y] then
   line(flr(x1[y]+0.5),flr(y+0.5),flr(x2[y]+0.5),flr(y+0.5),col)
  end
 end
end

-->8
--piece animation functions
function update_piece_animations()
	ani_timer += 1
	local all_game_pieces = {}
	for p in all(p_white) do add(all_game_pieces, p) end
	for p in all(p_black) do add(all_game_pieces, p) end

	for p in all(all_game_pieces) do
		if ani_timer > p.ani_delay and p.ani_progress < 1 then
			if not p.ani then
				p.start_x = p.x
				p.start_y = p.y
				p.ani = true
			end

			p.ani_progress = min(1, p.ani_progress + 0.02)
			local eased_t = ease_in_out(p.ani_progress)
			
			p.x = p.start_x + (p.ani_x - p.start_x) * eased_t
			p.y = p.start_y + (p.ani_y - p.start_y) * eased_t

			if p.ani_progress == 1 then
				p.x = p.ani_x
				p.y = p.ani_y
				p.ani = false
			end
		end
	end
	printh(ani_timer)
end

function run_active_animations()
	local all_animating_pieces = {}
	if stri.ani then add(all_animating_pieces, stri) end
	if p_red.ani then add(all_animating_pieces, p_red) end
	for p in all(p_white) do 
		if p.ani then add(all_animating_pieces, p) end
	end
	for p in all(p_black) do
		if p.ani then add(all_animating_pieces, p) end
	end

	for p in all(all_animating_pieces) do
		p.ani_progress = min(1, p.ani_progress + 0.03)
		local eased_t = ease_in_out(p.ani_progress)
		p.x = p.start_x + (p.ani_x - p.start_x) * eased_t
		p.y = p.start_y + (p.ani_y - p.start_y) * eased_t
		
		if p.ani_progress == 1 then
			p.x = p.ani_x
			p.y = p.ani_y
			p.ani = false
			
			if p == stri then
				stri.state = "positioning"
				if p_turn.is_ai then
					ai_state = "positioning"
				else
					arrow_pause=time()+3
				end
			end
		end
	end
end

function ease_in_out(t)
	t = max(0, min(1, t))
	if t < 0.5 then
		return 2 * t * t
	else
		t = t * 2 - 1
		return -0.5 * (t * (t - 2) - 1)
	end
end
function sign(n)
  return n > 0 and 1 or n < 0 and -1 or 0
end

-->8
--game logic
function switch_player()
	local is_foul = false
	local player_succeeded_this_turn = pieces_pocketed_this_turn > 0

	-- 1. Check for standard striker foul
	if pieces_pocketed_this_turn < 0 then
		is_foul = true
		handle_striker_foul()
	end

	-- 2. NEW LOGIC: Check if player cleared their pieces but left the red one
	local active_list, pocketed_list
	if p_turn.piece == 'white' then
		active_list = p_white
		pocketed_list = p_white_pocketed
	else
		active_list = p_black
		pocketed_list = p_black_pocketed
	end
	--game over logic 
	if p_red.inhole and not stri.inhole and (#p_white_pocketed >= 9 or #p_black_pocketed >= 9) then
		game_state = "game_over"
	end
	-- If all 9 of their pieces are pocketed but the red piece is still on the board, it's a foul.
	if #active_list == 0 and not p_red.inhole then
		is_foul = true
		sfx(3) -- Foul sound

		-- Return one of their pocketed pieces to the board as a penalty
		if #pocketed_list > 0 then
			local penalty_piece = deli(pocketed_list) -- remove the last piece they pocketed
			local new_x, new_y = find_open_spot_for_piece(penalty_piece)
			
			-- Set up animation to place it back on the board
			penalty_piece.start_x = penalty_piece.x
			penalty_piece.start_y = penalty_piece.y
			penalty_piece.ani_x = new_x
			penalty_piece.ani_y = new_y
			penalty_piece.ani_progress = 0
			penalty_piece.ani = true
			penalty_piece.dx = 0
			penalty_piece.dy = 0
			penalty_piece.inhole = false
			
			add(active_list, penalty_piece) -- Add it back to the active pieces list
		end
	end

	-- 3. Handle red piece confirmation (covering the queen)
	if red_pocketed_this_turn then
		local player_color_also_pocketed = false
		for p in all(pocketed_in_turn) do
			if p.name == p_turn.piece then
				player_color_also_pocketed = true
				break
			end
		end
		if player_color_also_pocketed then
			red_needs_confirmation = false
		end

	elseif red_needs_confirmation then
		if player_succeeded_this_turn then
			red_needs_confirmation = false
		else
			-- Penalty for not covering the red piece
			p_turn.score -= p_red.value 
			local new_x, new_y = find_open_spot_for_piece(p_red)
			
			p_red.dx = 0
			p_red.dy = 0
			p_red.start_x = p_red.x
			p_red.start_y = p_red.y
			p_red.ani_x = new_x
			p_red.ani_y = new_y
			p_red.ani_progress = 0
			p_red.ani = true
			p_red.inhole = false
			red_needs_confirmation = false
		end
	end
	--game over check 

	-- 4. Switch player if they didn't succeed OR if they committed any foul
	if not player_succeeded_this_turn or is_foul then
		if p_turn.name == p1.name then
			p_turn = p2
		else
			p_turn = p1
		end
	end

	-- 5. Reset striker position for the next player
	if p_turn.name == p1.name then
		-- Player 1's turn
		stri.ani_y = 115
		stri.ani_x = 64
		aim.ang = 90
	else
		-- Player 2's turn
		stri.ani_y = 11
		stri.ani_x = 64
		aim.ang = 270
	end
end
function is_position_free(x, y, r)
	local all_game_pieces = {}
	if not stri.inhole then add(all_game_pieces, stri) end
	if not p_red.inhole then add(all_game_pieces, p_red) end
	for p in all(p_white) do add(all_game_pieces, p) end
	for p in all(p_black) do add(all_game_pieces, p) end

	for p in all(all_game_pieces) do
		local check_x, check_y

		if p.ani then
			check_x = p.ani_x
			check_y = p.ani_y
		else
			check_x = p.x
			check_y = p.y
		end

		local dist_sq = (x - check_x)*(x - check_x) + (y - check_y)*(y - check_y)
		local total_r_sq = (r + p.r) * (r + p.r)
		if dist_sq < total_r_sq then
			return false
		end
	end
	return true
end

function find_open_spot_for_piece(p)
	local cx, cy = 64, 64
	if is_position_free(cx, cy, p.r) then
		return cx, cy
	end
	local radius = p.r * 2.5
	local angle = 0
	for i=1, 500 do
		local target_x = cx + radius * cos(angle/360)
		local target_y = cy + radius * sin(angle/360)

		if is_position_free(target_x, target_y, p.r) then
			return target_x, target_y
		end
		angle += 30
		if angle >= 360 then
			angle = 0
			radius += 4
		end
	end
	return 64, 20
end

function handle_striker_foul()
	for p in all(pocketed_in_turn) do
		if p.name == 'white' then
			del(p_white_pocketed, p)
		elseif p.name == 'black' then
			del(p_black_pocketed, p)
		end
	end

	local active_list, pocketed_list
	if p_turn.piece == 'white' then
		active_list = p_white
		pocketed_list = p_white_pocketed
	else
		active_list = p_black
		pocketed_list = p_black_pocketed
	end

	if #active_list < 9 and #pocketed_list > 0 then
		add(pocketed_in_turn, deli(pocketed_list, 1))
	end

	for p in all(pocketed_in_turn) do
		local new_x, new_y = find_open_spot_for_piece(p)
		p.start_x = p.x
		p.start_y = p.y
		p.ani_x = new_x
		p.ani_y = new_y
		p.ani_progress = 0
		p.ani = true
		p.dx = 0
		p.dy = 0
		p.inhole = false
		if p.name == 'white' then
			add(p_white, p)
		elseif p.name == 'black' then
			add(p_black, p)
		end
		if p == p_red then
			red_needs_confirmation = false
		end
	end
end

-->8
--ai opponent logic
function ai_opponent_turn()
    if ai_state == "positioning" then
        local best_shot = find_best_shot()
        if best_shot then
            stri.x = best_shot.striker_x
            ai_target_angle = best_shot.angle
            ai_shot_power = best_shot.power
            ai_state = "aiming"
            ai_timer = time() + 1
        else
            stri.x = 32 + rnd(64)
            ai_target_angle = 270 + rnd(20) - 10
            ai_shot_power = 30 + rnd(20)
            ai_state = "aiming"
            ai_timer = time() + 1 
        end
        stri.state = "aiming"
	elseif ai_state == "aiming" then
        local angle_diff = ai_target_angle - aim.ang
        if (abs(angle_diff) > 180) angle_diff -= sign(angle_diff) * 360

        aim.ang += angle_diff * 0.1
        aim.r = ai_shot_power
		
        local has_waited_long_enough = time() > ai_timer
        local is_aim_accurate = abs(angle_diff) < 5
        local safety_timer_expired = time() > ai_timer + 2.0
        if (has_waited_long_enough and is_aim_accurate) or safety_timer_expired then
            ai_state = "shooting"
            ai_timer = time() + 0.5
        end
    elseif ai_state == "shooting" then
        if time() > ai_timer then
            red_pocketed_this_turn = false
            pieces_pocketed_this_turn = 0
            pocketed_in_turn = {}
            local power = aim.r / 2.5
            power *= stri.speed
            local angle = aim.ang / 360
            stri.dx = cos(angle) * power
            stri.dy = sin(angle) * power
            
            stri.state = "simulating"
            sfx(0)
            
            ai_state = "waiting"
        end
    end
end
function find_best_shot()
    local best_shot = nil
    local best_score = -10000 

    for sx = 21, 107, 1 do
        local target_pieces = {}
        local player_pieces = {}

        if p_turn.piece == 'white' then
            player_pieces = p_white
        else
            player_pieces = p_black
        end
        for p in all(player_pieces) do
            add(target_pieces, p)
        end
        if not p_red.inhole then
            add(target_pieces, p_red)
        end

        for p_target in all(target_pieces) do
            for h in all(holes) do
                local score, target_pos = evaluate_shot(sx, stri.y, p_target, h)
                if score > best_score then
                    best_score = score
                    
                    local dx = target_pos.x - sx
                    local dy = target_pos.y - stri.y
                    local dist = sqrt(dx*dx + dy*dy)
					local pico_angle = atan2(dx, dy)

                    best_shot = {
                        striker_x = sx,
                        angle = pico_angle * 360,
                        power = mid(20, dist * 0.7, 70),
                        score = score
                    }
                end
            end
        end
    end
    return best_shot
end

function evaluate_shot(striker_x, striker_y, piece, hole)
    local vec_x = hole.x - piece.x
    local vec_y = hole.y - piece.y
    local len = sqrt(vec_x*vec_x + vec_y*vec_y)
    if len == 0 then return -10000, {} end

    local target_x = piece.x - (vec_x/len) * (stri.r + piece.r)
    local target_y = piece.y - (vec_y/len) * (stri.r + piece.r)

    local score = 1000

    local dist_to_target = sqrt((target_x - striker_x)^2 + (target_y - striker_y)^2)
    score -= dist_to_target * 3

    score -= len * 2
    
    local all_pieces = {}
	for p in all(p_white) do add(all_pieces, p) end
	for p in all(p_black) do add(all_pieces, p) end
    if not p_red.inhole then add(all_pieces, p_red) end

    for other_p in all(all_pieces) do
        if other_p != piece then
            if is_path_obstructed(striker_x, striker_y, target_x, target_y, other_p) 
			or is_path_obstructed(target_x, target_y, hole.x, hole.y, other_p)
			then
                score -= 1200
                break 
            end
        end
    end

	if piece == p_red then
		score += 200
	end
    
    return score, {x=target_x, y=target_y}
end

function is_path_obstructed(x1, y1, x2, y2, obs)
    local line_dx = x2 - x1
    local line_dy = y2 - y1
    local len_sq = line_dx*line_dx + line_dy*line_dy
    if len_sq == 0 then return false end
    local t = ((obs.x - x1) * line_dx + (obs.y - y1) * line_dy) / len_sq
    if t < 0 or t > 1 then return false end
    local closest_x = x1 + t * line_dx
    local closest_y = y1 + t * line_dy
    local dist_from_line_sq = (obs.x - closest_x)^2 + (obs.y - closest_y)^2
    return dist_from_line_sq < (obs.r + stri.r)^2
end

__gfx__
00000000dddddddddffffffdffffffffdfffffffdfddfffddfffddfddddddddddddddddd00000000ffffffffffffddffffddfffffffffffffffffffddfffffff
00000000ffffffffdffffffdfffffffffdfffffffdedffddddffdedffdeeeeeddeeeeedf00000000fffffffffdddedffffdedddffffffffffffffffddfffffff
00700700ffffffffdffffffdffffffffffdfffffdeeeddeddeddeeedffdeeeeddeeeedff00000000fffffffddeeeedffffdeeeeddfffffffffffffdffdffffff
00077000ffffffffdffffffdfffffffffffdffffddeeeeeddeeeeeddffdeeeeddeeeedff00000000ffffffdeeeeeedffffdeeeeeedffffffffffffdffdffffff
00077000ffffffffdffffffdffffffffffffdfffffdeeeeddeeeedffddeeeeeddeeeeedd00000000fffffdeeeeeedffffffdeeeeeedfffffffffffdffdffffff
00700700ffffffffdffffffdfffffffffffffdffffdeeeeddeeeedffdeeeddeddeddeeed00000000ffffdeeeeedddffffffdddeeeeedffffffffffdffdffffff
00000000ffffffffdffffffdffffffffffffffdffdeeeeeddeeeeedffdedffddddffdedf00000000fffdeeeeedffdffffffdffdeeeeedffffffffdffffdfffff
00000000dddddddddffffffdfffffffffffffffddddddddddddddddddfddfffddfffddfd00000000ffdeeeeddfffdffffffdfffddeeeedfffffffdffffdfffff
dffdfffdffffffffffffffffdfffdffdfffffffffffffffffffffffddffddddddffffffdffffffffffdeeeedffffdffffffdffffdeeeedffffffffff00000000
ffdffffdffffffffffffffffdffffdffffffffffffffffffffffffdfffdfffffdffffffdfffffffffdeeeedfffffdffffffdfffffdeeeedfffffffff00000000
fdfffffdffffdffffffdffffdfffffdffffffffffffffffffffffdfffdffffffdffffffdfffffffffdeeedffffffdffffffdffffffdeeedfffffffff00000000
dffffffdfffffdffffdfffffdffffffdffffffffffffffffffffdfffdfffffffdffffffdfffffffffdeeedfffffdffffffffdfffffdeeedfffffffff00000000
dffffffdffdffdffffdffdffdffffffdfffffffffffffffffffdffffffffffffdffffffdffffffffdeeedddddddfffddddfffdddddddeeedffffffff00000000
dffffffdfffdddffffdddfffdffffffdffffffffffffffffffdffffffffffffffdfffffdffffffddddddfffffffffdeeeedfffffffffddddddffffff00000000
dffffffdffffffdffdffffffdffffffdfffffffffffffffffdffffffffffffffffdffffdffddddffffffffffffffdeeeeeedffffffffffffffddddff00000000
dffffffdfffffffddfffffffdffffffdfffffffddfffffffdfffffffdddddddddffdfffdddffffffffffffffffffdeeeeeedffffffffffffffffffdd00000000
ddddddddfffffffddfffffffddddddddfffffffddfffffffdffffffddddddffd00000000ddffffffffffffffffffdeeeeeedffffffffffffffffffdd00000000
ffffffffffffffdffdffffffffffffffffffffffffffffffdffffffdfffffdff00000000ffddddffffffffffffffdeeeeeedffffffffffffffddddff00000000
fffffffffffdddffffdddfffffffffffffffffffffffffffdffffffdffffffdf00000000ffffffddddddfffffffffdeeeedffffffffdddddddffffff00000000
ffffffffffdffdffffdffdffffffffffffffffffffffffffdffffffdfffffffd00000000ffffffffdeeedddddddfffddddfffdddddddeeedffffffff00000000
fffffffdfffffdffffdfffffdfffffffffffffffffffffffdffffffdffffffff00000000fffffffffdeeedfffffdffffffffdfffffdeeedfffffffff00000000
ffffffdfffffdffffffdfffffdffffffffffffffffffffffdfffffdfffffffff00000000fffffffffdeeedffffffdffffffdffffffdeeedfffffffff00000000
fffffdffffffffffffffffffffdfffffffffffffffffffffdffffdffffffffff00000000fffffffffdeeeedfffffdffffffdfffffdeeeedfffffffff00000000
dddddffdffffffffffffffffdffdddddffffffffffffffffdfffdffddddddddd00000000ffffffffffdeeeedffffdffffffdffffdeeeedffffffffff00000000
ffddddddddddddffffddddffdfddddfd000000000000000000000000000000000000000000000000ffdeeeeddfffdffffffdfffddeeeedff0000000000000000
fdeeeedffdeeeedffdeeeedfddeeeedd000000000000000000000000000000000000000000000000fffdeeeeedffdffffffdffdeeeeedfff0000000000000000
deeeeeeddeeeeeeddeeeeeeddeeeeeed000000000000000000000000000000000000000000000000ffffdeeeeedddffffffdddeeeeedffff0000000000000000
deeeeeeddeeeeeeddeeeeeeddeeeeeed000000000000000000000000000000000000000000000000fffffdeeeeeedffffffdeeeeeedfffff0000000000000000
deeeeeeddeeeeeeddeeeeeeddeeeeeed000000000000000000000000000000000000000000000000ffffffdeeeeeedffffdeeeeeedffffff0000000000000000
deeeeeeddeeeeeeddeeeeeeddeeeeeed000000000000000000000000000000000000000000000000fffffffddeeeedffffdeeeeddfffffff0000000000000000
fdeeeedffdeeeedfddeeeeddfdeeeedf000000000000000000000000000000000000000000000000fffffffffdddedffffdedddfffffffff0000000000000000
ffddddddddddddffdfddddfdffddddff000000000000000000000000000000000000000000000000ffffffffffffddffffddffffffffffff0000000000000000
0001111100000000000111110000000000011111000000000001111100000000000000000ffffffffffffffffffffdffffdffffff00000000000000000000000
0017777710000000001ddddd100000000018888810000000001ccccc10000000000000000000000000000000fffffdffffdfffff000000000000000000000000
017777777100000001ddddddd1000000018888888100000001ccccccc1000000000000000000000000000000ffffffdffdffffff000000000000000000000000
1777ddd7771000001dd6555ddd100000188f2228881000001cc6555ccc100000000000000000000000000000ffffffdffdffffff000000000000000000000000
177ddddd771000001dd55555dd10000018822222881000001cc55555cc100000000000000000000000000000ffffffdffdffffff000000000000000000000000
177ddddd771000001dd55555dd10000018822222881000001cc55555cc100000000000000000000000000000ffffffdffdffffff000000000000000000000000
1777ddd7771000001ddd555ddd10000018882228881000001ccc555ccc100000000000000000000000000000fffffffddfffffff000000000000000000000000
1d7777777d10000015ddddddd5100000128888888210000015ccccccc5100000000000000000000000000000fffffffddfffffff000000000000000000000000
01dd777dd10000000155ddd55100000001228882210000000155ccc5510000000000000000000000000000000000000000000000000000000000000000000000
001ddddd100000000015555510000000001222221000000000155555100000000000000000000000000000000000000000000000000000000000000000000000
00011111000000000001111100000000000111110000000000011111000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1aaaaa111aa11aaaaa1111cccc111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
199999911991999999911cccccc11111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
19944999199199999991cccccccc1111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
19999999199199944991cc722ccc1111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
19999994199199911441cc2222cc1111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
19994441199199911111cc2222cc1111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
19991111199199911991ccc22ccc1111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
199911111991999999912cccccc21111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1999111119914999994112cccc211111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
14441111144114444411112222111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111000000111111111111110000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111110888888011111111111110000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111108888888801111111111110000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111108892288801111111111110000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111108822228801111111111110000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111108822228801111111111110000000000000000000000000000000000000000000000000000000000000000000000
11000000111000000110000000110000000108822228800001111000110000000000000000000000000000000000000000000000000000000000000000000000
10777777010777777007777777007777777008882288807770110777010000000000000000000000000000000000000000000000000000000000000000000000
07777777707777777707777777707777777708888888807770110777010000000000000000000000000000000000000000000000000000000000000000000000
0777dd7770777dd7770777dd7770777dd77702888888207777007777010000000000000000000000000000000000000000000000000000000000000000000000
0777ddddd0777dd7770777d77770777d777702222222207777777777010000000000000000000000000000000000000000000000000000000000000000000000
077700ddd0777007770777777dd0777777dd00222222007777777777010000000000000000000000000000000000000000000000000000000000000000000000
07770100007777777707777777d07777777d0100000010777d77d777010000000000000000000000000000000000000000000000000000000000000000000000
0777007770777777770777dd7770777dd7770111111110777dddd777010000000000000000000000000000000000000000000000000000000000000000000000
0777777770777dd7770777dd7770777dd77701111111107770dd0777010000000000000000000000000000000000000000000000000000000000000000000000
0d777777d0777dd77707770077707770077701111111107770000777010000000000000000000000000000000000000000000000000000000000000000000000
0dddddddd0ddd00ddd0ddd00ddd0ddd00ddd0111111110ddd0110ddd010000000000000000000000000000000000000000000000000000000000000000000000
10dddddd00ddd00ddd0ddd00ddd0ddd00ddd0111111110ddd0110ddd010000000000000000000000000000000000000000000000000000000000000000000000
11000000110001100010001100010001100011111111110001111000110000000000000000000000000000000000000000000000000000000000000000000000
11111111111111111111111111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000
__map__
0303030303030303030303030303030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0311300101010101010101010131120300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0332040303030303030303030316320300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0302030403030303030303031603020300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0302030305030303030303060303020300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
030203030303030e0f0303030303020300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0302030303030a0b0c0d03030303020300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0302030303191a1b1c1d1e030303020300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0302030303292a2b2c2d2e030303020300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0302030303033a3b3c3d03030303020300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
030203030303034b4c0303030303020300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0302030307030303030303080303020300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0302031603030303030303030403020300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0333160303030303030303030304330300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0321300101010101010101010131220300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0303030303030303030303030303030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00010000213501d35019350183501a3501f350042000120014200262002820016200172001a2001d2002520039200000000000000000000000000000000000000000000000000000000000000000000000000000
000100003a750277503b7503b7503b7503d750112000e2000e2000e20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100003c75020750207503a7503d7503d7500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000197503c750227503c75015750397500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100001b05015050100500b050040500d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 01424344

