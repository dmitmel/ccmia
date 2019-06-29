ng.module(
	"ccmia.core.serial"
)

-- KOSNEO SERIALIZE
do
	local function doSerialize(s)
 		if type(s) == "table" then
			local str = "{\n"
			local p = 1
			for k, v in pairs(s) do
				if k == p then
					str = str .. doSerialize(v) .. ",\n"
					p = p + 1
				else
					str = str .. "[" .. doSerialize(k) .. "]=" .. doSerialize(v) .. ",\n"
				end
			end
			return str .. "}"
	 	end
		if type(s) == "string" then
			return string.format("%q", s)
		end
	 	if type(s) == "number" or type(s) == "boolean" then
			return tostring(s)
		end
		if s == nil then
			return "nil"
	 	end
		error("Cannot serialize " .. type(s))
	end
	ccmia.serialize = function (x) return "return " .. doSerialize(x) end
	ccmia.deserialize = function (s)
	local r1, r2 = pcall(function()
	return load(s, "=serial", "t", {})()
 	end)
	if r1 then
	return r2
	else
	return nil, tostring(r2)
	end
	end
end
