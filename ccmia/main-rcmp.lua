ng.module(
	"ccmia.main-rcmp",
	"ccmia.remote",
	"ng.lib.util.polling-station",
	"ng.lib.compress.deflate",
	"ng.wrap.fs"
)

-- NOTE! THIS FILE WON'T BE INCLUDED IN THE BUILD.
-- Hence, it gets to use zlib to compress things.

do
	ccmia.startRemote()
	while not ccmia.remote do
		ng.poll()
		if ccmia.remoteError then
			error(ccmia.remoteError)
		end
	end
	local cr = {}
	for k, v in pairs(ccmia.remote) do
		cr[k] = v.general:toLT()
		os.execute("cd repo/content/" .. k .. " ; 7z a -ttar ../../../repo-build/" .. k .. "-pre.tar *")
		local f = io.open("repo-build/" .. k .. "-pre.tar", "rb")
		local f2 = io.open("repo-build/" .. k, "wb")
		f2:write(ng.compressDeflate(f:read("*a")))
		f2:close()
		f:close()
		ng.fs.unlink("repo-build/" .. k .. "-pre.tar")
	end
	local f = io.open("repo-build/meta", "wb")
	f:write(ng.compressDeflate(ccmia.serialize(cr)))
	f:close()
end
