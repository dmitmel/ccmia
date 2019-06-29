ng.module(
	"ccmia.main",
	"ccmia.menu-ui",
	"ng.resource",
	"ng.lib.util.tarhdr",
	"ng.lib.util.polling-station",
	"ng.wrap.fs"
)
ng.resource(
	"ccmia.target",
	".tar"
)

-- Look, it's 1:17AM and I had to do this on short notice.
-- I'll fix it! Really!

function runInstallation(data, prefix, str)
	local data = ng.resources["ccmia.target"]
	local spinner = ccmiaMenuUI.label("Starting", 32)
	ccmiaMenuUI.currentMenu = {
		ccmiaMenuUI.label("Running installation...", 32),
		spinner
	}
	local function fn()
		if #data == 0 then
			ng.polls[fn] = nil
			ccmiaMenuUI.currentMenu = {
				ccmiaMenuUI.label("Done!", 32),
				ccmiaMenuUI.label("Now simply run the game.", 32)
			}
			return
		end
		local ifo = ng.tarhdr.getInfo(data)
		data = data:sub(513)
		-- Blank path == fake!
		local edp = ifo.path:sub(#prefix + 1)
		if edp ~= "" then
			local main = data:sub(1, ifo.size)
			data = data:sub((ifo.sectors * 512) + 1)
			-- That's collated, now what do we do...
			if ifo.type == "directory" then
				ng.fs.mkdir(str .. "/" .. edp)
			else
				local f = io.open(str .. "/" .. edp, "wb")
				f:write(main)
				f:close()
			end
			print(edp, ifo.size, ifo.sectors)
			spinner.text = tostring(edp)
		end
	end
	ng.polls[fn] = true
end

ccmiaMenuUI.main({
	ccmiaMenuUI.label("Welcome to CCMIA!", 32),
	ccmiaMenuUI.button("wow, the UI is kinda unfinished", 16, function ()
		ccmiaMenuUI.currentMenu = {
			ccmiaMenuUI.label("I know, right?", 16),
			ccmiaMenuUI.label("But it could be made better! Anyway.", 16),
			ccmiaMenuUI.label("Please drag the 'resources.pak' file from CrossCode onto this window.", 16)
		}
		ccmiaMenuUI.allowDrop = function (str)
			if str:sub(-13) ~= "resources.pak" then
				ccmiaMenuUI.currentMenu = {
					ccmiaMenuUI.label("Wrong file?", 32),
					ccmiaMenuUI.label("The file you dragged was:", 16),
					ccmiaMenuUI.label(str, 16),
					ccmiaMenuUI.label("This doesn't seem to be 'resources.pak'.", 16),
					ccmiaMenuUI.label("Please drag that file onto this window.", 16)
				}
			else
				ccmiaMenuUI.allowDrop = nil
				runInstallation(ng.resources["ccmia.target"], "CCLoader/", str:sub(1, -14))
			end
		end
	end)
})
