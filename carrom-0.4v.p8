pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

function _init()
	stri = {sx=48,sy=32,x=64,y=115,dx=0,dy= 0,r=5, c=7,speed=0.5,accel=0.3,friction=0.015,s_ready=false,p_ready=false,ani=false,ani_x=0,ani_y=0,inhole=false}
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
	-- Control the starting rotation of the pieces (in degrees)
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
	-- Aiming controls
	aim={r=20.5,c=8,ang=90,speed=0,accel=0.3,friction=0.1}
	arrow_pause=3
	--players data
	p1 = {name="Player 1",score=0,piece='white'}
	p2 = {name="Player 2",score=0,piece='black', is_ai=true}
	p_turn = p2
	pieces_pocketed_this_turn = 0
	pocketed_in_turn = {}
	red_pocketed_by = nil
	red_needs_confirmation = false
	red_pocketed_this_turn = false
	
	-- AI specific variables
	ai_state = "positioning" -- "positioning", "aiming", "shooting"
	ai_target_pos = {}
	ai_target_angle = 0
	ai_shot_power = 0
	ai_timer = 0
end

function _update60()
	if ani_timer <= 150 then
		update_piece_animations()
	elseif not all_ani_stopped() then
		run_active_animations()
	elseif stri.p_ready then -- Turn setup phase (for both Player and AI)
		if p_turn.is_ai then
			ai_opponent_turn()
		else
			-- Player controls
			if stri.s_ready then
				aim_con()
				shoot_con()
			else
				move_con()
			end
		end
	else -- Physics simulation phase (after a shot is taken)
		if all_ani_stopped() then
			local is_finished = universal_physics()
			if is_finished then
				-- Turn is over, reset striker and switch players
				stri.p_ready = false
				aim.speed = 0
				aim.r = 20.5
				stri.start_x = stri.x
				stri.start_y = stri.y
				stri.ani_progress = 0
				stri.ani = true
				stri.inhole=false
				switch_player()
			end
		end
	end
end

function _draw()
	cls(13)
	map(0,0,0,0,16,16)
	for h in all(holes) do draw_hole(h) end
	for h in all(holes) do hole_fall_effect(h,h.c) end
	if stri.p_ready and stri.s_ready and (not p_turn.is_ai or ai_state == "aiming") then
		draw_aimline(stri.x,stri.y,aim.r+8,aim.ang,aim.c) --8 is offset
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
		if stri.p_ready and not stri.s_ready then
			draw_piece(stri, 1)
			if time()>arrow_pause then
				draw_movement_arrows()
			end
		else
			draw_piece(stri)
		end
	end
	-- print(stri.p_ready,0,0)
	-- print(stri.s_ready,0,8)
	-- print(p_turn.name,0,0)
	-- print(p_red.inhole,0,8)
	-- print(pieces_pocketed_this_turn,0,16)
end
  

-->8
--collision and physics

-- universal physics simulation
function universal_physics()
	-- gather all pieces into a single list for easy processing
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
		-- check if any piece is in a hole
		for i=#all_pieces,1,-1 do
			local p = all_pieces[i]
			if check_hole_collision(p, h) then
				h.effect_f=30
				-- remove piece from play
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
					-- Red piece logic
					if not red_needs_confirmation then
						p_turn.score += p_red.value
						pieces_pocketed_this_turn += 1
						red_needs_confirmation = true
						red_pocketed_this_turn = true
						add(pocketed_in_turn, p_red)
					end
				elseif p.name == 'white' then
					-- white piece
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
					-- black piece
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

	-- sub-stepping for accurate collision detection
	local sub_steps = 8 
	
	for s=1, sub_steps do
		-- move every piece by a fraction of its velocity
		for p in all(all_pieces) do
			p.x += p.dx / sub_steps
			p.y += p.dy / sub_steps
		end

		-- handle all collisions
		for i=1, #all_pieces do
			local p1 = all_pieces[i]
			handle_wall_collision(p1)
			-- check against every other piece (j=i+1 avoids double checks)
			for j=i+1, #all_pieces do
				check_collision(p1, all_pieces[j])
			end
		end
	end

	--  apply friction and check if everything has stopped
	local all_stopped = true
	
	for p in all(all_pieces) do
		p.dx *= (1 - p.friction)
		p.dy *= (1 - p.friction)

		local speed_sq = p.dx*p.dx + p.dy*p.dy
		if speed_sq > 0.005 then
			all_stopped = false
		else
			-- clamp to zero to prevent tiny drifting
			p.dx = 0
			p.dy = 0
		end
	end

	return all_stopped
end

-- collision logic
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
		--random sound between 2 and 4
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
		-- piece is in the hole
		sfx(4)
		return true
	end
	return false
end
-->8
-- player controls

-- player controls

function move_con()
	-- Pressing the button confirms striker position and enters aiming mode
	if btnp(🅾️) then
		stri.s_ready = true
		return -- Exit to prevent movement on the same frame
	end
	
	-- Handle left/right movement
	if btn(⬅️) and not btn(➡️) then
		stri.dx-=stri.accel
		arrow_pause=time()+3
	elseif btn(➡️) and not btn(⬅️) then
		stri.dx+=stri.accel
		arrow_pause=time()+3
	else 
		stri.dx*= stri.friction 
	end
	
	-- Apply movement and check boundaries
	stri.x+=stri.dx
	if stri.x < stri.r+16 then stri.x = stri.r+16; stri.dx=0 end
	if stri.x > 128-stri.r-17 then stri.x = 128-stri.r-17; stri.dx=0 end
end

function aim_con()
	-- aim angle
	if btn(⬅️) and not btn(➡️) then
		aim.speed+=aim.accel
	elseif btn(➡️) and not btn(⬅️) then
		aim.speed-=aim.accel
	else 
		aim.speed*=aim.friction 
	end
	aim.ang+=aim.speed
	
	-- shot power (radius of indicator)
	if btn(⬆️) then
		aim.r+=1
	elseif btn(⬇️) then
		aim.r-=1
	end
	aim.r=mid(3,aim.r,80)

	-- change color based on power
	if aim.r >= 55 then aim.c= 8
	elseif aim.r >= 25 then aim.c= 12
	else aim.c= 3 end
end
    
function shoot_con()
	-- Fire the shot and hand control over to the physics engine
	if btnp(🅾️) then
		red_pocketed_this_turn = false
		pieces_pocketed_this_turn = 0
		pocketed_in_turn = {}
		local power = aim.r / 2.5 -- adjusted for better feel
		power *= stri.speed
		local angle = aim.ang / 360
		stri.dx = cos(angle) * power
		stri.dy = sin(angle) * power
		
		-- Disable all player controls to start physics simulation
		stri.p_ready = false 
		stri.s_ready = false 
		sfx(0)
	-- Cancel the shot and return to the movement phase
	elseif btnp(❎) then
		stri.s_ready = false
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
-- drawing

function draw_piece(p,h)
	h = h or 0
	--solving sub-pixel jitter by rounding position to nearest pixel
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
-- Add this function to your drawing section
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
-- animation

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

-- This function handles all animations that occur after the initial setup,
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
				-- Animation finished, give control to the player for movement
				stri.p_ready = true
				stri.s_ready = false
				if p_turn.is_ai then
					ai_state = "positioning"
				else
					arrow_pause=time()+3
				end
			end
		end
	end
end

-- Smoother easing function (Quadratic Ease In-Out)
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
--player logic

function switch_player()
	if pieces_pocketed_this_turn < 0 then
		handle_striker_foul()
	end
	local player_succeeded_this_turn = pieces_pocketed_this_turn > 0
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
			p_turn.score -= p_red.value 
			local new_x, new_y = find_open_spot_for_piece(p_red)
			
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

	if not player_succeeded_this_turn then
		if p_turn.name == p1.name then
			p_turn = p2
			stri.ani_y = 11
			stri.ani_x = 64
			aim.ang = 270
		else
			p_turn = p1
			stri.ani_y = 115
			stri.ani_x = 64
			aim.ang = 90
		end
	end
end
-- Checks if a specific coordinate is free of other pieces
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
	local radius = p.r * 2.5 -- Start search radius
	local angle = 0
	for i=1, 500 do -- Limit search to prevent infinite loops
		local target_x = cx + radius * cos(angle/360)
		local target_y = cy + radius * sin(angle/360)

		if is_position_free(target_x, target_y, p.r) then
			return target_x, target_y
		end
		angle += 30 -- Check every 30 degrees
		if angle >= 360 then
			angle = 0
			radius += 4 -- Increase radius for the next circle
		end
	end
	return 64, 20 -- Failsafe position if no spot is found
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
-- AI Logic
function ai_opponent_turn()
    if ai_state == "positioning" then
        -- Find the best position for the striker and the best shot
        local best_shot = find_best_shot()
        if best_shot then
            stri.x = best_shot.striker_x
            ai_target_angle = best_shot.angle
            ai_shot_power = best_shot.power
            ai_state = "aiming"
            ai_timer = time() + 1 -- 1 second to aim
        else
            -- No good shot found, position randomly and shoot
            stri.x = 32 + rnd(64)
            ai_target_angle = 270 + rnd(20) - 10
            ai_shot_power = 30 + rnd(20)
            ai_state = "aiming"
            ai_timer = time() + 1 
        end
        stri.s_ready = true
	elseif ai_state == "aiming" then
        local angle_diff = ai_target_angle - aim.ang
        if (abs(angle_diff) > 180) angle_diff -= sign(angle_diff) * 360

        aim.ang += angle_diff * 0.1
        aim.r = ai_shot_power
		
        local has_waited_long_enough = time() > ai_timer
        local is_aim_accurate = abs(angle_diff) < 5
        local safety_timer_expired = time() > ai_timer + 2.0 -- 2 seconds after aiming started
        if (has_waited_long_enough and is_aim_accurate) or safety_timer_expired then
            ai_state = "shooting"
            ai_timer = time() + 0.5
        end
    elseif ai_state == "shooting" then
        if time() > ai_timer then
            -- Fire the shot
            red_pocketed_this_turn = false
            pieces_pocketed_this_turn = 0
            pocketed_in_turn = {}
            local power = aim.r / 2.5
            power *= stri.speed
            local angle = aim.ang / 360
            stri.dx = cos(angle) * power
            stri.dy = sin(angle) * power
            
            stri.p_ready = false 
            stri.s_ready = false 
            sfx(0)
            
            ai_state = "waiting" -- Wait for physics to resolve
        end
    end
end
function find_best_shot()
    local best_shot = nil
    local best_score = -10000 

    -- Iterate through all possible striker positions
    for sx = 21, 107, 1 do
        local target_pieces = {}
        local player_pieces = {}

        if p_turn.piece == 'white' then
            player_pieces = p_white
            player_pieces = p_black
        end
        for p in all(player_pieces) do
            add(target_pieces, p)
        end
        if not p_red.inhole then
            add(target_pieces, p_red)
        end


        -- The rest of the function continues as before, but now with the correct targets.
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
    if len == 0 then return -10000, {} end -- Prevent division by zero

    local target_x = piece.x - (vec_x/len) * (stri.r + piece.r)
    local target_y = piece.y - (vec_y/len) * (stri.r + piece.r)

    local score = 1000

    -- 1. Penalize distance from striker to target spot
    local dist_to_target = sqrt((target_x - striker_x)^2 + (target_y - striker_y)^2)
    score -= dist_to_target * 3

    -- 2. Penalize distance of piece from the hole
    score -= len * 2
    
    -- 3. Heavily penalize any obstructions
    local all_pieces = {}
	for p in all(p_white) do add(all_pieces, p) end
	for p in all(p_black) do add(all_pieces, p) end
    if not p_red.inhole then add(all_pieces, p_red) end

    -- Check path from striker to the target spot
    for other_p in all(all_pieces) do
        if other_p != piece then
            if is_path_obstructed(striker_x, striker_y, target_x, target_y, other_p) then
                score -= 1200
                break 
            end
        end
    end

    -- Check path from piece to hole
    for other_p in all(all_pieces) do
        if other_p != piece then
            if is_path_obstructed(piece.x, piece.y, hole.x, hole.y, other_p) then
                score -= 1200 
                break 
            end
        end
    end

	-- Bonus for targeting the red piece
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
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000
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
00000000000000000022222222222222222222222222222200000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000222222222222222222222222220000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000222222222222222222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000022222222222200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

