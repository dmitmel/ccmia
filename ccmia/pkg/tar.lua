ng.module(
	"ccmia.pkg.tar",
	"ccmia.core.game",
	"ng.lib.util.tarhdr",
	"ng.wrap.fs"
)

-- Creates an AvailablePackage structure.
-- This is not a serializable structure, as it represents generic information from a perhaps remote repository.
-- The 'downloader' is a function of form (success, failure, progress) that begins the task of downloading the package's TAR file.
-- success(tar) is called if/when the TAR file is available.
ccmia.AvailableTARPackage = function (gen, downloader)
	local model = {
		general = gen,
		downloader = downloader
	}
	function model:install(prefix, success, failure, progress)
		self.downloader(function (data)
			local files = {}
			progress("Installing...")
			while #data > 0 do
				-- Yay! We can install now!
				local ifo = ng.tarhdr.getInfo(data)
				data = data:sub(513)
				-- Blank path == fake!
				local edp = ifo.path
				if edp ~= "" then
					ccmia.checkPath(edp)
					local main = data:sub(1, ifo.size)
					data = data:sub((ifo.sectors * 512) + 1)
					-- That's collated, now what do we do...
					if ifo.type == "directory" then
						ng.fs.mkdir(prefix .. edp)
					else
						table.insert(files, edp)
						local f = io.open(prefix .. edp, "wb")
						f:write(main)
						f:close()
					end
				end
			end
			success(ccmia.InstalledPackage({general = self.general:toLT(), files = files}))
		end, failure, progress)
	end
	return model
end

