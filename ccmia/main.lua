ng.module(
	"ccmia.main",
	"ccmia.cui"
)

if ng.args[1] ~= nil then
	ccmia.cui(ng.args)
else
	error("no GUI yet")
end
