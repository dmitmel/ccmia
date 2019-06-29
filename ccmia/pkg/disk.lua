ng.module(
	"ccmia.pkg.disk",
	"ccmia.core.game",
	"ccmia.core.serial",
	"ng.wrap.fs"
)

-- Creates an AvailablePackage structure from a place on disk the package is stored at.
ccmia.AvailableDiskPackage = function (gen, pkgPrefix)
	local model = {
		general = gen,
		files = {},
		directories = {}
	}
	local function recursion(base)
		local lst = ng.fs.list(pkgPrefix .. base)
		if not lst then error("unable to list: " .. pkgPrefix .. base) end
		for _, v in ipairs(lst) do
			if ng.fs.info(pkgPrefix .. base .. v) == "directory" then
				table.insert(model.directories, base .. v)
				recursion(base .. v .. "/")
			else
				if base ~= "" or v ~= ".ccmia-pkg" then
					table.insert(model.files, base .. v)
				end
			end
		end
	end
	recursion("")
	function model:install(gamePrefix, success, failure, progress)
		for _, v in ipairs(self.directories) do
			ng.fs.mkdir(gamePrefix .. v)
		end
		local fc = {}
		for _, v in ipairs(self.files) do
			table.insert(fc, v)
			local f2 = io.open(pkgPrefix .. v, "rb")
			local b = f2:read("*a")
			f2:close()
			local f = io.open(gamePrefix .. v, "wb")
			f:write(b)
			f:close()
		end
		success(ccmia.InstalledPackage({general = self.general:toLT(), files = fc}))
	end
	return model
end

