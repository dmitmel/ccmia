ng.module(
	"ccmia.core.game",
	"ccmia.core.base",
	"ccmia.core.serial",
	"ng.lib.util.tarhdr",
	"ng.wrap.fs"
)

-- The Game is the installation target.

-- AvailablePackage structures must have:
-- .general = GeneralPackage
-- :install(prefix, success, failure, progress) -> InstalledPackage

-- Creates a InstalledPackage structure.
-- This is a serialized structure used to represent local files that might need to be removed in the event of an update.
-- It also stores the package's metadata to identify it.
ccmia.InstalledPackage = function (src)
	local model = {
		general = ccmia.GeneralPackage(src.general),
		files = src.files
	}
	function model:toLT()
		local lt = {}
		lt.general = self.general:toLT()
		lt.files = self.files
		return lt
	end
	return model
end

-- Represents the user's game data & metadata.
-- NOTE: Only use InstalledPackage instances from this Game with it.
-- Also note that install/remove don't do checking.
-- Also also note that gamePrefix is assumed to end in "/" or similar.
ccmia.Game = function (gamePrefix)
	local model = {
		gamePrefix = gamePrefix,
		-- This isn't serialized, it's just for convenience with checkPackages
		basePackages = {
			["loader"] = "the game is unplayable without the root package.json file (try loader-vanilla)",
			["runtime"] = "the game is unplayable without a runtime"
		},
		-- List of packages in the system.
		packages = {
			ccmia.InstalledPackage({
				general = {
					name = "loader-base",
					build = 0,
					deps = {},
					provides = {loader = "0.0"},
				},
				files = {
					"package.json"
				}
			}),
			ccmia.InstalledPackage({
				general = {
					name = "runtime-base",
					build = 0,
					deps = {},
					provides = {runtime = "0.0"},
				},
				files = {
				}
			})
		}
	}
	local dok, derr = pcall(function ()
		local f = io.open(gamePrefix .. ".ccmia", "rb")
		local s = ccmia.deserialize(f:read("*a"))
		f:close()
		model.packages = {}
		for k, v in pairs(s.packages) do
			table.insert(model.packages, ccmia.InstalledPackage(v))
		end
	end)
	if not dok then
		io.stderr:write("error/non-existent database: " .. tostring(derr) .. "\n")
	end
	function model:lookup(name)
		for k, v in ipairs(self.packages) do
			if v.general.name == name then
				return v
			end
		end
	end
	-- Installs an available package.
	function model:install(availablePackage, success, failure, progress)
		availablePackage:install(self.gamePrefix, function (inst)
			table.insert(self.packages, inst)
			self:save()
			success()
		end, failure, progress)
	end
	-- Removes a local package.
	function model:remove(localPackage)
		local idx
		for k, v in ipairs(self.packages) do
			if v == localPackage then
				idx = k
				break
			end
		end
		assert(idx)
		table.remove(self.packages, idx)
		self:save()
		-- Begin actual removal
		for _, v in ipairs(localPackage.files) do
			ccmia.checkPath(v)
			ng.fs.unlink(self.gamePrefix .. v)
		end
	end
	-- Serializes the innards.
	function model:toLT()
		local result = {
			packages = {}
		}
		for k, v in ipairs(self.packages) do
			table.insert(result.packages, v:toLT())
		end
		return result
	end
	function model:save()
		local f = io.open(self.gamePrefix .. ".ccmia", "wb")
		if f then
			f:write(ccmia.serialize(self:toLT()))
			f:close()
		else
			io.stderr:write("warning: .ccmia file did not save\n")
		end
	end
	return model
end
