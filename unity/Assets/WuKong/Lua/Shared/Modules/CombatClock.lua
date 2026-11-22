-- Pure montage time and geometry; shared by DS, rendering and fixed-input tests.
local M = {}
local C = require "CombatConfig"
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
M.clamp = clamp
local function curve(points, value, fallback)
    if not points or #points==0 then return fallback end
    if value<=points[1][1] then return points[1][2] end
    for i=2,#points do
        if value<=points[i][1] then
            local p,q=points[i-1],points[i]
            return p[2]+(q[2]-p[2])*(value-p[1])/(q[1]-p[1])
        end
    end
    return points[#points][2]
end
function M.velocity(x,z,tx,tz,locked,gait,dt)
    local curves=locked and C.gait.lock or C.gait.free
    local rate=tx*tx+tz*tz>=x*x+z*z and curve(curves.accel,math.max(gait,1),20)
        or curve(curves.decel,gait,40)
    local dx,dz=tx-x,tz-z;local diff=math.sqrt(dx*dx+dz*dz)
    if diff<0.000001 then return tx,tz end
    local step=math.min(diff,rate*dt)
    return x+dx/diff*step,z+dz/diff*step
end
function M.active(meta, t, kind)
    for i, e in ipairs(meta and meta.events or {}) do
        if e.type == kind and e.start and t >= e.start and t < e["end"] then return e, i end
    end
end
function M.allowed(e, skill)
    if e.whitelist and #e.whitelist > 0 then
        for _, id in ipairs(e.whitelist) do if id == skill then return true end end
        return false
    end
    for _, id in ipairs(e.blacklist or {}) do if id == skill then return false end end
    return true
end
function M.sample(rm, t)
    if not rm or not rm.samples or #rm.samples == 0 then return {0,0,0,0} end
    local f = math.max(0, t * rm.fps)
    local i = math.min(math.floor(f) + 1, #rm.samples)
    local j = math.min(i + 1, #rm.samples)
    local a, p, q, out = math.min(f - i + 1, 1), rm.samples[i], rm.samples[j], {}
    for k = 1, 4 do out[k] = p[k] + (q[k] - p[k]) * a end
    return out
end
function M.rate(meta, t)
    local r = meta.rateScale or 1
    for _, e in ipairs(meta.events or {}) do
        if (e.type == "playRate" or e.type == "speedRate") and e.rate and e.rate>0 and t >= e.start and t < e["end"] then
            r = r * e.rate
        end
    end
    return r
end
function M.advance(a, dt, meta)
    meta = meta or C.clips[a.clip]
    local old = a.t
    local nextTime = old + dt * M.rate(meta, old)
    local section = not meta.loop and meta.sections and meta.sections[a.section or 1]
    local limit = section and math.min(section["end"], meta.duration) or meta.duration
    local finished, wrapped = false, false
    if nextTime >= limit then
        local target
        if section and section.next then
            for i, s in ipairs(meta.sections) do if s.name == section.next then target = i end end
        end
        if target then
            a.section = target; nextTime = meta.sections[target].start + nextTime - limit
            wrapped = math.abs(meta.sections[target].start - limit) > 0.001
        elseif meta.loop then nextTime = nextTime % meta.duration; wrapped = true
        else nextTime = limit; finished = true end
    end
    a.prev = old; a.t = nextTime
    return finished, wrapped
end
function M.rootDelta(a, old, new, surface, meta)
    meta = meta or C.clips[a.clip]
    local p, q = M.sample(meta.rootMotion, old), M.sample(meta.rootMotion, new)
    -- Source forward is +X; handedness conversion maps native +X to Unity -X.
    local forward, side = q[1] - p[1], q[3] - p[3]
    a.moveRates = a.moveRates or {}
    for i, e in ipairs(meta.events or {}) do
        if e.type == "rootMotionScale" and old >= e.start and old < e["end"]
            and (not e.axis or string.sub(e.axis, -5) == "AxisX") then
            if not a.moveRates[i] then
                local x, y = M.sample(meta.rootMotion, e.start), M.sample(meta.rootMotion, e["end"])
                local span = y[1] - x[1]
                a.moveRates[i] = surface and math.abs(span) > 0.001
                    and clamp(math.max(0, surface + (e.offset or 0)) / span, e.min or 0, e.max or 10000) or 1
            end
            forward = forward * (e.pureScale or a.moveRates[i]); break
        end
    end
    return forward, side, q[4] - p[4]
end
function M.damage(A, V, e, isPlayer, maxHp, rng)
    local p = C.damageParams
    rng = rng or math.random
    local pre = (A.attack * (e.damageMult or 0) + (e.flatDamage or 0))
        * math.max(p.minPreMultiplier, (1 - (V.dmgDef or 0) / 10000) * (1 + (A.dmgAddition or 0) / 10000))
    local T, def = A.trueDamageRatio or 0, V.defense or 0
    local trueD = pre * T * maxHp / (isPlayer and p.playerDesiredHp or maxHp)
    local crit = 1 + math.floor(rng() * 10000) <= (A.critRate or 0)
    local critMul = crit and math.max(1, p.critBase + (A.critMultiplier or 0) / 10000) or 1
    local noise = p.noiseMin + rng() * (p.noiseMax - p.noiseMin)
    return math.floor(trueD + pre * (1-T) * (1-p.defA*def/(p.defB+p.defC*math.abs(def))) * critMul * noise), crit
end
local function sub(a,b) return {x=a.x-b.x,y=a.y-b.y,z=a.z-b.z} end
local function dot(a,b) return a.x*b.x+a.y*b.y+a.z*b.z end
function M.segmentDistance2(p1,q1,p2,q2)
    local d1,d2,r = sub(q1,p1),sub(q2,p2),sub(p1,p2)
    local a,e,f = dot(d1,d1),dot(d2,d2),dot(d2,r)
    local s,t = 0,0
    if a <= 1e-9 and e <= 1e-9 then
    elseif a <= 1e-9 then t=clamp(f/e,0,1)
    else
        local c=dot(d1,r)
        if e <= 1e-9 then s=clamp(-c/a,0,1)
        else
            local b=dot(d1,d2);local den=a*e-b*b
            s=den>1e-9 and clamp((b*f-c*e)/den,0,1) or 0
            t=(b*s+f)/e
            if t<0 then t=0;s=clamp(-c/a,0,1) elseif t>1 then t=1;s=clamp((b-c)/a,0,1) end
        end
    end
    local x,y,z=p1.x+d1.x*s-p2.x-d2.x*t,p1.y+d1.y*s-p2.y-d2.y*t,p1.z+d1.z*s-p2.z-d2.z*t
    return x*x+y*y+z*z
end
return M
