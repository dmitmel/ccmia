ng.module(
	"ccmia.cui",
	"ccmia.remote",
	"ccmia.core.base",
	"ccmia.core.game",
	"ccmia.core.serial",
	"ng.lib.util.polling-station"
)

-- MAIN --
function ccmia.cui(args)
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
	local function actCore(a, b, noPointlessInstall)
		local removeVers = {} -- maps names to 'commit'
		local installVers = {} -- maps names to 'commit'
		for _, v in ipairs(a) do
			local xv = game:lookup(v)
			if not xv then
				print("No such local package " .. v)
				os.exit(1)
			end
			removeVers[v] = xv.general.commit
		end
		for _, v in ipairs(b) do
			if not ccmia.remote[v] then
				print("No such remote package " .. v)
				os.exit(1)
			end
			installVers[v] = ccmia.remote[v].general.commit
		end
		--
		local remove = {} -- list of InstalledPackages
		for _, v in ipairs(a) do
			local xv = game:lookup(v)
			-- if version being installed ~= to current version, then it's ok
			if (not noPointlessInstall) or (installVers[v] ~= xv.general.commit) then
				table.insert(remove, xv)
			end
		end
		--
		local install = {} -- list of AvailablePackages
		for _, v in ipairs(b) do
			-- if version being removed ~= to current version, then it's ok
			if (not noPointlessInstall) or (removeVers[v] ~= ccmia.remote[v].general.commit) then
				table.insert(install, ccmia.remote[v])
			end
		end
		--
		local removeByInstance = {} -- keys are InstalledPackages
		for _, v in ipairs(remove) do
			removeByInstance[v] = true
		end
		--
		local result = {} -- list of GeneralPackages
		for _, v in ipairs(game.packages) do
			if not removeByInstance[v] then
				table.insert(result, v.general)
			end
		end
		for _, v in ipairs(install) do
			table.insert(result, v.general)
		end
		--
		local rv = ccmia.checkPackages(result, game.basePackages)
		if rv then
			print("The resulting configuration would be invalid:")
			print(rv)
			os.exit(1)
		end
		for _, v in ipairs(remove) do
			game:remove(v)
		end
		for _, v in ipairs(install) do
			local done = false
			game:install(v, function ()
				done = true
			end, error, print)
			while not done do
				nicePoll()
			end
		end
	end
	if args[1] == "help" then
		print("ccmia mod installation assistant")
		print("if given no sub-command, will start UI")
		print("if given a sub-command, assumes the current directory is CrossCode (did you really want this?)")
		print("defaults to remote repository, but can use a local file tree given CCMIA_LOCAL environment variable")
		print("in this case, each sub-directory in the given directory is a package, and expects a GeneralPackage struct as a 'meta.lua' file")
		print("sub-commands:")
		print(" list-local")
		print("  lists local packages")
		print(" list-remote")
		print("  lists remote packages")
		print(" update")
		print("  tries to update packages where possible to remote copies (can overwrite local versions!!!)")
		print(" reset <TO INSTALL...>")
		print("  removes all local packages and installs different packages (will not uninstall whatever provides \"runtime\" as this isn't usually wanted outside of SDK usage - use act if you really want this)")
		print("  won't remove a local package if it's just going to reinstall it anyway with the same version though")
		print(" act <TO REMOVE...> . <TO INSTALL...>")
		print("  packages with names before the '.' are removed, packages with names after the '.' are installed")
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
	elseif args[1] == "update" then
		prepRemote()
		local victims = {}
		for _, v in pairs(ccmia.remote) do
			local v2 = game:lookup(v.general.name)
			if v2 then
				table.insert(victims, v2)
			end
		end
		-- noPointlessInstall ensures this only updates what's needed
		actCore(victims, victims, true)
	elseif args[1] == "reset" then
		-- <TO INSTALL...>
		local a = {}
		for _, v in ipairs(game.packages) do
			if not v.general.provides["runtime"] then
				table.insert(a, v.general.name)
			end
		end
		table.remove(args, 1)
		if #args > 0 then
			prepRemote()
		end
		actCore(a, args, true)
	elseif args[1] == "act" then
		-- <TO REMOVE...> . <TO INSTALL...>
		local buf = {}
		local hitDot = nil
		while #args > 1 do
			local st = table.remove(args, 2)
			if st == "." then
				hitDot = buf
				buf = {}
			else
				table.insert(buf, st)
			end
		end
		assert(hitDot)
		if #buf > 0 then
			prepRemote()
		end
		actCore(hitDot, buf, true)
	elseif args[1] == "check" then
		local lcl = {}
		for _, v in ipairs(game.packages) do
			table.insert(lcl, v.general)
		end
		local rv = ccmia.checkPackages(lcl, game.basePackages)
		if rv then
			print(rv)
			os.exit(1)
		end
	else
		print("Unknown operation " .. args[1] .. " - use 'help'?")
		os.exit(1)
	end
end
