ng.module(
	"ccmia.core.base"
)

ccmia = {}

-- A Version, not to be confused with a build number.
-- Versions are part of the deps/provides system and define forward and backward API compatibility.
ccmia.Version = function (src)
	local p = src:find("%.")
	local model = {
		major = tonumber(src:sub(1, p - 1)),
		minor = tonumber(src:sub(p + 1))
	}
	assert(model.major)
	assert(model.minor)
	function model:toString()
		return self.major .. "." .. self.minor
	end
	function model:fulfills(required)
		if required.major ~= self.major or self.minor < required.minor then
			return false
		end
		return true
	end
	return model
end

-- Creates a GeneralPackage structure, containing the general data regarding a package.
-- This is split into 5 fields:
-- name : The unique name of the package. This, along with commit, is used for determining update paths.
-- commit : The commit ID of the package. This, along with name, is used for determining update paths.
--          Can be something other than a commit ID if it's, say, a meta-package.
--          Thus, must be considered an arbitrary *comparable* human-readable string.
-- source : Arbitrary metadata, DO NOT PARSE, but DO PROVIDE
-- deps : map from depID to version
-- provides : map from depID to version

ccmia.GeneralPackage = function (src)
	local model = {
		name = src.name,
		commit = src.commit,
		source = src.source,
		deps = {},
		provides = {}
	}
	for k, v in pairs(src.deps) do
		model.deps[k] = ccmia.Version(v)
	end
	for k, v in pairs(src.provides) do
		model.provides[k] = ccmia.Version(v)
	end
	function model:toLT()
		local deps = {}
		for k, v in pairs(self.deps) do
			deps[k] = v:toString()
		end
		local prov = {}
		for k, v in pairs(self.provides) do
			prov[k] = v:toString()
		end
		return {
			name = self.name,
			commit = self.commit,
			source = self.source,
			deps = deps,
			provides = prov
		}
	end
	return model
end

-- Performs a shallow copy of a list or set
ccmia.scopy = function (n)
	local t = {}
	for k, v in pairs(n) do
		t[k] = v
	end
	return t
end

ccmia.checkPath = function (path)
	if path:find(":") then error(": IS NOT A VALID FILE THINGY, SO YOU'RE TRYING TO ANNOY WINDOWS USERS. NICE TRY.") end
	local component = ""
	for i = 1, #path do
		if path:sub(i, i) == "\\" or path:sub(i, i) == "/" then
			if component == "" then error("EMPTY PATH COMPONENT, ABORTING.") end
			if component == ".." then error("DODGY PATH COMPONENT (..), ABORTING.") end
			component = ""
		else
			component = component .. path:sub(i, i)
		end
	end
end
