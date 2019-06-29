ng.module(
	"ccmia.menu-ui",
	"ng.lib.app2d.main",
	"ng.lib.app2d.draw",
	"ng.lib.app2d.text",
	"ng.wrap.ffi",
	"ng.wrap.sdl2.events",
	"ng.wrap.sdl2.stdinc"
)

ccmiaMenuUI = {}

ccmiaMenuUI.currentScrollY = 0
ccmiaMenuUI.currentMenu = nil
ccmiaMenuUI.hover = nil
ccmiaMenuUI.allowDrop = nil

ccmiaMenuUI.margin = 8

function ccmiaMenuUI.button(text, height, onclick)
	local button = {}
	button.text = text
	button.height = height
	button.onClick = onclick
	function button:draw(x, w, y)
		local m = math.ceil(self.height / 8)
		local sz = ng.app2d.measureText(self.height, self.text)
		local col = {0.8, 0.8, 1, 1}
		if ccmiaMenuUI.hover == self then col = {0.5, 0.5, 0.8, 1} end
		ng.app2d.texRect(ng.app2d.current.pixel, {x, y, sz[1] + (m * 2), self.height}, {0, 0, 1, 1}, col)
		ng.app2d.text(x + m, y + m, self.height, self.text, {0, 0, 0, 1})
	end
	function button:click()
		self.onClick()
	end
	return button
end

function ccmiaMenuUI.label(text, height)
	local label = {}
	label.text = text
	label.height = height
	function label:draw(x, w, y)
		local m = math.ceil(self.height / 8)
		ng.app2d.text(x + m, y + m, self.height, self.text, {1, 1, 1, 1})
	end
	function label:click()
	end
	return label
end

function ccmiaMenuUI.getElementByY(ey)
	local y = ccmiaMenuUI.margin - ccmiaMenuUI.currentScrollY
	for _, v in ipairs(ccmiaMenuUI.currentMenu) do
		if ey >= y and ey < (y + v.height) then
			return v
		end
		y = y + v.height + ccmiaMenuUI.margin
	end
end

function ccmiaMenuUI.main(menu)
	ccmiaMenuUI.currentMenu = menu
	ng.app2d.main(function ()
		local mainWin = ng.app2d.Window("CCMIA Installation Assistant", 800, 600, false)
		local app = {}
		function app:event(event)
			if event.type == ng.sdl2Enums.SDL_DROPFILE then
				local str = ffi.string(event.drop.file)
				ng.sdl2.SDL_free(event.drop.file)
				if ccmiaMenuUI.allowDrop then
					ccmiaMenuUI.allowDrop(str)
				end
			elseif event.type == ng.sdl2Enums.SDL_MOUSEMOTION then
				ccmiaMenuUI.hover = ccmiaMenuUI.getElementByY(event.motion.y)
			elseif event.type == ng.sdl2Enums.SDL_MOUSEBUTTONDOWN then
				local e = ccmiaMenuUI.getElementByY(event.button.y)
				if e then e:click() end
			elseif event.type == ng.sdl2Enums.SDL_QUIT then
				ng.app2d.running = false
			end
		end
		function app:frame()
			ng.app2d.windowFrame(mainWin, function ()
				mainWin.gl.glClear(mainWin.gl.GL_COLOUR_BUFFER_BIT)
				local y = ccmiaMenuUI.margin - ccmiaMenuUI.currentScrollY
				for _, v in ipairs(ccmiaMenuUI.currentMenu) do
					v:draw(ccmiaMenuUI.margin, mainWin.width - (ccmiaMenuUI.margin * 2), y)
					y = y + v.height + ccmiaMenuUI.margin
				end
			end)
		end
		return app
	end, 10)
end
