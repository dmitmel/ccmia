ng.module(
	"ccmia.remote",
	"ccmia.core.base",
	"ccmia.core.serial",
	"ccmia.pkg.disk",
	"ccmia.pkg.tar",
	"ng.lib.net.http-client",
	"ng.lib.decompress.deflate",
	"ng.lib.util.polling-station",
	"ng.wrap.fs"
)

function ccmia.startRemote()
	local localPath = os.getenv("CCMIA_LOCAL")
	local remoteHost = os.getenv("CCMIA_REMOTE_HOST") or "20kdc.duckdns.org"
	local remotePort = tonumber(os.getenv("CCMIA_REMOTE_PORT"))
	local remotePath = os.getenv("CCMIA_REMOTE_PATH") or "/ccmia/"
	local function createSimpleDownloader(target)
		return function (success, failure, progress)
			local data = ""
			ng.httpClient({
				host = remoteHost,
				port = remotePort,
				path = remotePath .. target,
				data = function (chk)
					data = data .. chk
				end,
				success = function (hdr)
					local ok, gd = pcall(ng.decompressDeflate, data)
					if not ok then failure(tostring(gd)) return end
					success(gd)
				end,
				failure = failure,
				progress = progress
			})
		end
	end
	if not localPath then
		-- Remote (download meta)
		createSimpleDownloader("meta")(function (data)
			data, ccmia.remoteError = ccmia.deserialize(data)
			if data then
				ccmia.remote = {}
				for k, v in pairs(data) do
					local p = ccmia.GeneralPackage(v)
					ccmia.remote[k] = ccmia.AvailableTARPackage(p, createSimpleDownloader(k))
					assert(k == p.name)
				end
			else
				ccmia.remoteError = ccmia.remoteError or "what'd deserialize do now, the rascal..."
			end
		end, function (details)
			ccmia.remoteError = details or "ooo, didn't provide an error, what a public menace!"
		end, function (detail, amount)
			io.stderr:write("remote: " .. detail .. "\n")
		end)
	else
		-- Local
		ccmia.remote = {}
		local lst = ng.fs.list(localPath)
		if not lst then error("unable to list " .. localPath) end
		for _, v in ipairs(lst) do
			if v:sub(-10) == ".ccmia-pkg" then
				local iname = v:sub(1, -11)
				local hf = io.open(localPath .. "/" .. v, "rb")
				local gen = hf:read("*a")
				hf:close()
				gen = ccmia.deserialize(gen)
				gen = ccmia.GeneralPackage(gen)
				local p = ccmia.AvailableDiskPackage(gen, localPath .. "/content/" .. iname .. "/")
				assert(iname == p.general.name)
				ccmia.remote[p.general.name] = p
			end
		end
	end
end

