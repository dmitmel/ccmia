ng.module(
	"ccmia.cui",
	"ccmia.remote",
	"ccmia.core.base",
	"ccmia.core.solver",
	"ccmia.core.game",
	"ccmia.core.serial",
	"ng.lib.util.polling-station",
	"ng.lib.util.table"
)

-- MAIN --
function ccmia.cui(args)
	math.randomseed(os.time())
	-- This interface is relatively self-contained.
	local function nicePoll()
		ng.poll()
	end
	local function prepRemote()
		ccmia.startRemote()
		while not ccmia.remote do
			nicePoll()
			if ccmia.remoteError then
				error("remote failure: " .. tostring(ccmia.remoteError))
			end
		end
	end

	local game = ccmia.Game("./")
	-- a: remove, b: install, basePackages: optional override
	local function actCore(a, b, basePackages)
		basePackages = basePackages or game.basePackages
		local remove = {} -- set of InstalledPackages
		for _, v in ipairs(a) do
			local xv = game:lookup(v)
			if not xv then
				print("No such local package " .. v)
				os.exit(1)
			end
			remove[xv] = true
		end
		--
		local install = {} -- set of AvailablePackages
		for _, v in ipairs(b) do
			if not ccmia.remote[v] then
				print("No such remote package " .. v)
				os.exit(1)
			end
			install[ccmia.remote[v]] = true
		end
		--
		local rvm, rv = ccmia.checkPackages(ccmia.actionResults(game, {remove, install}), basePackages)
		if rv then
			local solutions = ccmia.solveAction(game, {remove, install}, basePackages)
			table.shuffle(solutions)
			if #solutions == 0 then
				print("The resulting configuration would be invalid:")
				print("")
				print(rv)
				print("")
				print("Please note that:")
				for _, v in pairs(rvm) do
					if v[1] == "need" then
						print(v[2] .. " can be provided by:")
						for _, px in pairs(ccmia.remote) do
							if px.general.provides[v[2]] then
								print("", px.general.name)
							end
						end
					end
				end
				print("")
				print("If you require further insight, prefix the command with 'detail-'.")
				print("Alternatively, manually resolving issues may clarify the issue.")
				print("Alternatively, it may allow the automatic system to handle the rest.")
				print("You may need to use swap to specify the specific action to take.")
				os.exit(1)
			elseif #solutions > 1 and not os.getenv("CCMIA_AUTOMATIC") then
				print("There are multiple ways to achieve that:")
				for k, v in ipairs(solutions) do
					print("Solution " .. k .. ":")
					print("", ccmia.actionText(v))
				end
				print("Enter the number of the solution you wish to use.")
				print("Alternatively, type '0' or quit to cancel.")
				remove, install = unpack(solutions[tonumber(io.read())])
			else
				if not os.getenv("CCMIA_AUTOMATIC") then
					print("Unable to perform as asked, but can:")
					print("", ccmia.actionText(solutions[1]))
					print("Type 'yes' and press enter to continue. Anything except 'yes' will cancel.")
					assert(io.read() == "yes")
				end
				remove, install = unpack(solutions[1])
			end
		end
		for k, _ in pairs(remove) do
			print("Removing " .. k.general.name .. "...")
			game:remove(k)
		end
		for k, _ in pairs(install) do
			print("Installing " .. k.general.name .. "...")
			local done = false
			game:install(k, function ()
				done = true
			end, error, function (text)
				io.stderr:write(text .. "\n")
			end)
			while not done do
				nicePoll()
			end
		end
		print("Done!")
	end

	if args[1]:sub(1, 7) == "detail-" then
		args[1] = args[1]:sub(8)
		ccmia.debugFlagActivateInsight = true
	end

	if args[1] == "help" then
		print("ccmia mod installation assistant")
		print("if given no sub-command, will start UI")
		print("if given a sub-command, assumes the current directory is CrossCode (did you really want this?)")
		print("defaults to remote repository, but can use a local file tree given CCMIA_LOCAL environment variable")
		print("in this case, each sub-directory in the given directory is a package, and expects a GeneralPackage struct as a 'meta.lua' file")
		print("sub-commands:")
		print(" list-local")
		print("  lists local packages (those that are installed)")
		print(" list-remote")
		print("  lists remote packages (those that can be installed)")
		print(" install <TO INSTALL...>")
		print("  installs some packages")
		print(" remove <TO REMOVE...>")
		print("  removes some packages")
		print(" swap <TO REMOVE...> / <TO INSTALL...>")
		print("  packages with names before the '/' are removed, packages with names after the '/' are installed")
		print(" update")
		print("  updates packages where possible")
		print(" reset")
		print("  nukes everything except the nw.js runtime & installs loader-vanilla")
		print(" check")
		print("  checks for dependency issues")
		print(" provide <...>")
		print("  given a dependency ID such as 'standardized-mods', provides that")
	elseif args[1] == "list-local" then
		for _, v in ipairs(game.packages) do
			print("", v.general.name, v.general.commit)
			print("", "", v.general.source)
		end
	elseif args[1] == "list-remote" then
		prepRemote()
		for _, v in pairs(ccmia.remote) do
			print("", v.general.name, v.general.commit)
			print("", "", v.general.source)
		end
	elseif args[1] == "install" then
		-- <TO INSTALL...>
		local buf = {}
		while #args > 1 do
			local st = table.remove(args, 2)
			table.insert(buf, st)
		end
		if #buf > 0 then
			prepRemote()
			actCore({}, buf)
		end
	elseif args[1] == "remove" then
		-- <TO REMOVE...>
		local buf = {}
		while #args > 1 do
			local st = table.remove(args, 2)
			table.insert(buf, st)
		end
		ccmia.remote = {}
		actCore(buf, {})
	elseif args[1] == "swap" then
		-- <TO REMOVE...> / <TO INSTALL...>
		local buf = {}
		local hitDot = nil
		while #args > 1 do
			local st = table.remove(args, 2)
			if st == "." or st == "/" then
				hitDot = buf
				buf = {}
			else
				table.insert(buf, st)
			end
		end
		assert(hitDot)
		prepRemote()
		actCore(hitDot, buf)
	elseif args[1] == "update" then
		prepRemote()
		local victims = {}
		for _, v in pairs(ccmia.remote) do
			local v2 = game:lookup(v.general.name)
			if v2 then
				if v.general.commit ~= v2.general.commit then
					-- needs update
					table.insert(victims, v2)
				end
			end
		end
		actCore(victims, victims)
	elseif args[1] == "reset" then
		local a = {}
		for _, v in ipairs(game.packages) do
			if not v.general.provides["runtime"] then
				table.insert(a, v.general.name)
			end
		end
		prepRemote()
		actCore(a, {"loader-vanilla"})
	elseif args[1] == "check" then
		local lcl = {}
		for _, v in ipairs(game.packages) do
			lcl[v.general] = true
		end
		local _, rv = ccmia.checkPackages(lcl, game.basePackages)
		if rv then
			print(rv)
			os.exit(1)
		end
	elseif args[1] == "provide" then
		prepRemote()
		local bsp = ccmia.scopy(game.basePackages)
		for i = 2, #args do
			bsp[args[i]] = "The game requires " .. args[i] .. " because the user asked it to be provided."
		end
		actCore({}, {}, bsp)
	else
		print("Unknown operation " .. args[1] .. " - use 'help'?")
		os.exit(1)
	end
end
