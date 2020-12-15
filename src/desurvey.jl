
"""
	drillhole(collar::Collar, survey::Survey, intervals::Intervals)

Desurvey drill hole based on collar, survey and interval table(s) information.
The intervals can be passed as a single `IntervalTable` or as an array of
`IntervalTable`. Outputs a `DrillHole` object.
"""
function drillhole(collar::Collar,survey::Survey,intervals::Intervals)
	pars = getcolnames(survey,intervals)
	warns = validations(collar, survey, intervals)
	in("Error",warns[:,:TYPE]) && (return DrillHole(nothing,nothing,pars,warns))
	
	trace = gettrace(collar, survey)
	fillxyz!(trace, pars)

	table = mergetables(intervals, pars)
	fillxyz!(table, trace, pars)

	DrillHole(table,trace,pars,warns)
end

function getcolnames(s,i)
	f = i isa IntervalTable ? i.from : i[1].from
	t = i isa IntervalTable ? i.to : i[1].to
	m = s.method == :tangential
	pars = (holeid=s.holeid, at=s.at, azm=s.azm, dip=s.dip, from=f, to=t, tang=m)
	# check duplicate names and inform (maybe also if there is a preexisting x y z length)
end

function gettrace(c, s)
	collar = c.file isa String ? CSV.read(c.file, DataFrame) : c.file
	survey = s.file isa String ? CSV.read(s.file, DataFrame) : s.file
	n1 = (c.x,c.y,c.z,c.holeid)
	n2 = (:X,:Y,:Z,s.holeid)
	namepairs = [a=>b for (a,b) in zip(Symbol.(n1),Symbol.(n2)) if a!=b]
	rename!(collar, namepairs...)
	collar[!,s.at] .= 0.0

	s.invertdip && (survey[s.dip] *= -1)

	dfh = leftjoin(survey,collar,on=[s.holeid,s.at])
	sort!(dfh, [s.holeid,s.at])
	dropmissing!(dfh, :X)
end


function mincurv(az1, dp1, az2, dp2, d12)
	dp1, dp2 = (90-dp1), (90-dp2)

    DL = acos(cosd(dp2-dp1)-sind(dp1)*sind(dp2)*(1-cosd(az2-az1)))
    RF = DL!=0.0 ? 2*tan(DL/2)/DL : 1

    dx = 0.5*d12*(sind(dp1)*sind(az1)+sind(dp2)*sind(az2))*RF
	dy = 0.5*d12*(sind(dp1)*cosd(az1)+sind(dp2)*cosd(az2))*RF
	dz = 0.5*d12*(cosd(dp1)+cosd(dp2))*RF
    dx,dy,dz
end

function tangential(az1, dp1, d12)
	dp1 = (90-dp1)
    dx = d12*sind(dp1)*sind(az1)
	dy = d12*sind(dp1)*cosd(az1)
	dz = d12*cosd(dp1)
    dx,dy,dz
end

function findbounds(A::AbstractArray,v)
    nearid = findmin(abs.(A.-v))[2]
    nearest = A[nearid]
    nearid == length(A) && nearest < v && return (nearid,nearid)
    nearest == v && return (nearid,nearid)
    nearest > v && return (nearid-1,nearid)
    nearest < v && return (nearid, nearid+1)
end

angs2vec(az,dp) = [sind(az)*cosd(-dp), cosd(az)*cosd(-dp), sind(-dp)]
vec2angs(i,j,k) = [atand(i,j), -asind(k)]

function weightedangs(angs1,angs2,d12,d1x)
    v1 = angs2vec(angs1...)
    v2 = angs2vec(angs2...)

    p2 = d1x/d12
    p1 = 1-p2
    v12 = v1*p1 + v2*p2
    v12 /= sqrt(sum(abs2,v12))

    azm, dip = vec2angs(v12...)
    azm, dip
end

# fill xyz for dh trace files
function fillxyz!(dfh, pars)
	at, az, dp, tang = pars.at, pars.azm, pars.dip, pars.tang
	for i in 1:size(dfh,1)
        dfh[i,at] == 0 && continue
        d12 = dfh[i,at]-dfh[i-1,at]
        az1, dp1 = dfh[i-1,az], dfh[i-1,dp]
        az2, dp2 = dfh[i,az], dfh[i,dp]
        dx,dy,dz = tang ? tangential(az1,dp1,d12) : mincurv(az1,dp1,az2,dp2,d12)
        dfh[i,:X] = dx + dfh[i-1,:X]
        dfh[i,:Y] = dy + dfh[i-1,:Y]
        dfh[i,:Z] = dz + dfh[i-1,:Z]
    end
end

# fill xyz for dh from-to table file
function fillxyz!(dfx, dfh, pars)
	bh, at, az, dp = pars.holeid, pars.at, pars.azm, pars.dip
	from, to = pars.from, pars.to
	dfx[!,:X] .= -9999.9999
	dfx[!,:Y] .= -9999.9999
	dfx[!,:Z] .= -9999.9999

	lastbhid = dfx[1,bh]
	dfb = dfh[(dfh[!,bh] .== lastbhid),:]

	for i in 1:size(dfx,1)

		bhid, atx = dfx[i,bh], dfx[i,from]+dfx[i,:LENGTH]/2
		bhid != lastbhid && (dfb = dfh[(dfh[!,bh] .== bhid),:])
		lastbhid = bhid

		size(dfb,1)==0 && continue # alert bhid with no survey

		b = findbounds(dfb[:,at],atx)
		d1x = atx-dfb[b[1],at]
		if d1x == 0
			dfx[i,:X] = dfb[b[1],:X]
			dfx[i,:Y] = dfb[b[1],:Y]
			dfx[i,:Z] = dfb[b[1],:Z]
		else
			d12 = dfb[b[2],at]-dfb[b[1],at]
			az1, dp1 = dfb[b[1],az], dfb[b[1],dp]
			az2, dp2 = dfb[b[2],az], dfb[b[2],dp]
			azx, dpx = b[1]==b[2] ? (az2, dp2) : weightedangs([az1,dp1],[az2,dp2],d12,d1x)
			dx,dy,dz = mincurv(az1, dp1, azx, dpx, d1x)
			dfx[i,:X] = dx + dfb[b[1],:X]
			dfx[i,:Y] = dy + dfb[b[1],:Y]
			dfx[i,:Z] = dz + dfb[b[1],:Z]
		end
	end
	filter!(row -> row.X != -9999.9999, dfx) # whats excluded here return as warning
end
