ng.module(
	"ccmia.core.solver",
	"ccmia.core.base"
)

-- Given a set of GeneralPackage structures, confirm that the configuration is valid.
-- If it isn't, returns a semi-set of machine-readable errors and a list of human-readable errors.
-- The keys of the machine-readable errors are arbitrary and internal.
-- The values are meant for in solveAction, and thus are treated as follows:
-- {"nuke", package-name} - remove all local & remote instances of package name
-- {"conflict", {package-names...}} - act as "nuke" for all except 1 of these
-- {"need", provide-name} - Ensures a package providing this is available somehow
--  (regarding potential versioning issues, anything providing it at all is allowed,
--   then the inevitable conflicts get rid of the failures)
ccmia.checkPackages = function (packages, bsp)
	local why = {}
	local whyMachine = {}
	local conflictsOver = {}
	local provided = {}
	local providedWho = {}
	local hasName = {}
	for pkg, _ in pairs(packages) do
		if hasName[pkg.name] and not whyMachine["nuke-" .. pkg.name] then
			whyMachine["nuke-" .. pkg.name] = {"nuke", pkg.name}
			table.insert(why, "multiple packages called " .. pkg.name .. " makes addressing impossible (to upgrade, remove the older package)")
		end
		hasName[pkg.name] = true
		for k, v in pairs(pkg.provides) do
			if provided[k] then
				whyMachine["conflict-" .. k] = whyMachine["conflict-" .. k] or {"conflict", {providedWho[k]}}
				table.insert(whyMachine["conflict-" .. k][2], pkg.name)
				table.insert(why, pkg.name .. " provides " .. k .. " but it's provided by " .. providedWho[k] .. " too")
			else
				provided[k] = v
				providedWho[k] = pkg.name
			end
		end
	end
	for pkg, _ in pairs(packages) do
		for k, v in pairs(pkg.deps) do
			if provided[k] then
				if not provided[k]:fulfills(v) then
					whyMachine["provide-error-" .. k .. "\x00" .. pkg.name] = {"conflict", {pkg.name, providedWho[k]}}
					table.insert(why, pkg.name .. " needs " .. k .. " " .. v:toString() .. ", got " .. provided[k]:toString() .. " which is not compatible")
				end
			else
				whyMachine["provide-missing-" .. k] = {"need", k}
				--we *probably* don't want to do this, could generate solutions that nuke unintended stuff
				--whyMachine["remove-incompatible-" .. pkg.name] = {"nuke", pkg.name}
				table.insert(why, pkg.name .. " needs " .. k .. " but it's not provided")
			end
		end
	end
	for k, v in pairs(bsp) do
		if not provided[k] then
			whyMachine["provide-missing-mkx-" .. k] = {"need", k}
			table.insert(why, v)
		end
	end
	if #why == 0 then
		return
	end
	return whyMachine, table.concat(why, "\n")
end

-- Since there shouldn't be two packages with the same name in the same repository,
--  this also serves as a valid table key, and is used as such
ccmia.actionText = function (sol)
	local a, b = {}, {}
	for v, _ in pairs(sol[1]) do
		table.insert(a, v.general.name)
	end
	for v, _ in pairs(sol[2]) do
		table.insert(b, v.general.name)
	end
	-- These serve to provide an exact order where possible for table-key reasons
	table.sort(a)
	table.sort(b)
	if #a == 0 and #b == 0 then
		return "Do nothing"
	end
	if #a == 0 then
		return "Install (" .. table.concat(b, ", ") .. ")"
	end
	if #b == 0 then
		return "Remove (" .. table.concat(a, ", ") .. ")"
	end
	return "Replace (" .. table.concat(a, ", ") ..  ") with (" .. table.concat(b, ", ") .. ")"
end

ccmia.actionResults = function (game, action)
	local result = {} -- set of GeneralPackages
	for _, v in ipairs(game.packages) do
		if not action[1][v] then
			result[v.general] = true
		end
	end
	for k, _ in pairs(action[2]) do
		result[k.general] = true
	end
	return result
end

ccmia.actionCopy = function (action)
	return {ccmia.scopy(action[1]), ccmia.scopy(action[2])}
end

-- Given an action, checks it.
-- Returns nil if the action is finished, otherwise returns a list.
-- The list contains {debug, action} pairs.
-- Usually just the action is used, but debug is useful for debugging
ccmia.solveActionStep = function (game, action, original, basePackages)
	local wm = ccmia.checkPackages(ccmia.actionResults(game, action), basePackages)
	if not wm then return end
	-- Generate solutions
	local solutions = {}
	for ik, issue in pairs(wm) do
		local function nukeHelper(sol, name)
			-- Remove installed instances of package
			for _, v in ipairs(game.packages) do
				if v.general.name == name then
					sol[1][v] = true
				end
			end
			for k, _ in pairs(sol[2]) do
				if k.general.name == name then
					sol[2][k] = nil
				end
			end
		end
		if issue[1] == "nuke" then
			-- get rid of that package ID
			local sol = ccmia.actionCopy(action)
			nukeHelper(sol, issue[2])
			table.insert(solutions, {ik, sol})
		elseif issue[1] == "conflict" then
			-- get rid of all except 1 package ID
			for i = 1, #issue[2] do
				local sol = ccmia.actionCopy(action)
				for j = 1, #issue[2] do
					if j ~= i then
						nukeHelper(sol, issue[2][j])
					end
				end
				table.insert(solutions, {i .. "#" .. ik, sol})
			end
		elseif issue[1] == "need" then
			-- find implementations
			for _, pkg in pairs(ccmia.remote) do
				if pkg.general.provides[issue[2]] then
					local sol = ccmia.actionCopy(action)
					sol[2][pkg] = true
					-- this part isn't really necessary but prevents a lot of seemingly stupid output
					--  that will never resolve anyway
					local function nukeOnProvideConflict(og)
						for k, _ in pairs(pkg.general.provides) do
							if og.name ~= pkg.general.name then
								if og.provides[k] then
									nukeHelper(sol, og.name)
									return
								end
							end
						end
					end
					for vic, _ in pairs(sol[2]) do
						nukeOnProvideConflict(vic.general)
					end
					for _, vic in ipairs(game.packages) do
						nukeOnProvideConflict(vic.general)
					end
					--
					table.insert(solutions, {ik, sol})
				end
			end
		end
	end
	-- Ensure all solutions still meet the original constraints.
	-- Notably, doing things this way ensures nuke can turn 'install package' into 'update package'
	for _, sol in ipairs(solutions) do
		for k, _ in pairs(original[1]) do
			sol[2][1][k] = true
		end
		for k, _ in pairs(original[2]) do
			sol[2][2][k] = true
		end
	end
	return solutions
end

ccmia.debugFlagActivateInsight = false

-- remove & install are sets of InstalledPackages and AvailablePackages respectively.
-- Returns solved actions of the form {remove, install}.
ccmia.solveAction = function (game, action, basePackages)
	local debugIntuition = ccmia.debugFlagActivateInsight
	if debugIntuition then
		print("Was unable to handle your request as specified. Solving.")
	end
	local seen = {}
	local unfinished = {action}
	local finished = {}
	while #unfinished > 0 do
		local u2 = unfinished
		unfinished = {}
		for _, v in ipairs(u2) do
			local at = ccmia.actionText(v)
			if not seen[at] then
				seen[at] = true
				if debugIntuition then
					print("Solution " .. at)
				end
				local sols = ccmia.solveActionStep(game, v, action, basePackages)
				if not sols then
					if debugIntuition then
						print("", "Success")
					end
					table.insert(finished, v)
				else
					for _, v2 in ipairs(sols) do
						if debugIntuition then
							local at2 = ccmia.actionText(v2[2])
							-- another bit of stupidity management: hide seen solutions
							if not seen[at2] then
								print("", v2[1] .. " -> " .. at2)
							end
						end
						table.insert(unfinished, v2[2])
					end
				end
			end
		end
	end
	if debugIntuition then
		print("Solver End...")
	end
	return finished
end

