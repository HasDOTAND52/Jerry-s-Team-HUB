--[[
	FlyToggle.lua  —  LocalScript
	Ubicación: StarterPlayer > StarterPlayerScripts

	F  = activar / desactivar el vuelo
	H  = mostrar / ocultar el panel "Jerry's Script V.1" (o el botón de
	     la lechuga girando en medio de la pantalla; se puede arrastrar,
	     pensado para móvil)
	Arrastra la BARRA VERDE de arriba para mover el panel.
	W A S D = moverse en la dirección de la cámara (mientras vuelas)
	Espacio = subir      Shift = bajar

	----------------------------------------------------------------
	INTERFAZ (estilo "Old Roblox": plana, verde y blanca, bordes negros)

	El panel ahora es pequeño (340 x 348) y está ordenado en 4 PESTAÑAS.
	Cada script tiene su propia tarjeta con su NOMBRE y una línea que
	explica qué hace:

	  MOVER   -> VUELO, NOCLIP
	  VISUAL  -> ESP, FULLBRIGHT
	  COMBATE -> AIMBOT (Wall Check, Team Check, círculo, parte)
	  EXTRA   -> FLING A JUGADOR, GMABER1090 (giro)

	Cartel rojo "Self Destruct" (arriba a la derecha) = elimina TODO,
	con una explosión de lechugas 🥬
	----------------------------------------------------------------

	Sobre el logo (la lechuga con gafas): sube tu imagen como Decal
	(Creator Hub o Studio > Asset Manager > Import) y pega el ID aquí:

		local LOGO_ASSET_ID = "rbxassetid://TU_ID_AQUI"

	Mientras tanto se muestra un 🥬 de relleno.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer

local TECLA = Enum.KeyCode.F          -- activar/desactivar vuelo
local TECLA_GUI = Enum.KeyCode.H      -- mostrar/ocultar el panel

local VEL_MIN = 10          -- vuelo: más lento
local VEL_MAX = 1000        -- vuelo: más rápido
local velocidad = 100       -- vuelo: valor inicial

local GIRO_MIN = 30         -- giro: más lento (grados/seg)
local GIRO_MAX = 1080       -- giro: más rápido (grados/seg)
local velocidadGiro = 180   -- giro: valor inicial

local FUERZA_MIN = 2000        -- fling: más suave
local FUERZA_MAX = 60000       -- fling: más fuerte
local fuerzaFling = 30000      -- fling: valor inicial
local DURACION_DIRIGIDO = 1.5  -- fling: tiempo MÁXIMO pegado al objetivo (s); corta antes si sale
local DIST_LANZADO = 50        -- fling: si el objetivo se aleja tanto (studs), se da por lanzado
local VEL_LANZADO = 250        -- fling: ...o si su velocidad supera esto (studs/s)
local ANTICIPACION = 0.12      -- fling: cuánto "adelantas" a un objetivo que se mueve (s)
local TIEMPO_REGRESO = 0.6     -- fling: máximo para volver a tu sitio y frenarte (s)
local DIST_REGRESO = 6         -- fling: a menos de esto (studs) de tu sitio se da por vuelto

-- Pega aquí el rbxassetid de tu imagen de la lechuga una vez la subas:
local LOGO_ASSET_ID = "rbxassetid://100928947883496"

local volando = false
local establecerVuelo   -- se define más abajo
local cancelarFlingDirigido   -- se define más abajo
local humanoid, root, attachment, linearVelocity, alignOrientation, angularVelocity

-- Registro de conexiones globales, para cortarlas al pulsar "Self Destruct".
local conexiones = {}
local destruido = false

local function conectar(senal, funcion)
	local c = senal:Connect(funcion)
	table.insert(conexiones, c)
	return c
end

--------------------------------------------------------------------
-- PALETA — estilo "Roblox viejo" (flat, verde/blanco, bordes negros)
--------------------------------------------------------------------

local VERDE_HEADER = Color3.fromRGB(0, 158, 61)
local VERDE_OSCURO = Color3.fromRGB(0, 120, 46)
local VERDE_SUAVE = Color3.fromRGB(235, 248, 238)
local BLANCO = Color3.fromRGB(255, 255, 255)
local GRIS_TEXTO = Color3.fromRGB(60, 60, 60)
local GRIS_TENUE = Color3.fromRGB(120, 135, 120)
local NEGRO_BORDE = Color3.fromRGB(20, 20, 20)
local VERDE_BARRA = Color3.fromRGB(0, 158, 61)
local GRIS_TRACK = Color3.fromRGB(210, 210, 210)

local FUENTE = Enum.Font.SourceSansBold

--------------------------------------------------------------------
-- INTERFAZ — piezas reutilizables
--------------------------------------------------------------------

-- Medidas del panel (pequeño, con pestañas)
local ANCHO_PANEL = 340
local ALTO_PANEL = 348
local Y_PAGINAS = 72        -- donde empiezan las páginas (bajo las pestañas)
local ALTO_PIE = 22         -- espacio del pie

-- Borde "biselado" clásico: una línea clara arriba y una sombra abajo.
local function biselar(objeto)
	local luz = Instance.new("Frame")
	luz.Name = "Luz"
	luz.Size = UDim2.new(1, 0, 0, 2)
	luz.BackgroundColor3 = BLANCO
	luz.BackgroundTransparency = 0.55
	luz.BorderSizePixel = 0
	luz.Parent = objeto

	local sombra = Instance.new("Frame")
	sombra.Name = "Sombra"
	sombra.AnchorPoint = Vector2.new(0, 1)
	sombra.Position = UDim2.new(0, 0, 1, 0)
	sombra.Size = UDim2.new(1, 0, 0, 2)
	sombra.BackgroundColor3 = Color3.new(0, 0, 0)
	sombra.BackgroundTransparency = 0.82
	sombra.BorderSizePixel = 0
	sombra.Parent = objeto
end

-- Degradado vertical suave (solo para Frames sin texto propio).
local function degradado(marco, oscuro)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(BLANCO, Color3.fromRGB(oscuro, oscuro, oscuro))
	g.Parent = marco
end

-- Botón estándar del panel (blanco, borde negro, biselado).
local function crearBoton(padre, nombre, texto, posicion, tamano, tamanoTexto)
	local b = Instance.new("TextButton")
	b.Name = nombre
	b.Position = posicion
	b.Size = tamano
	b.BackgroundColor3 = BLANCO
	b.BorderSizePixel = 2
	b.BorderColor3 = NEGRO_BORDE
	b.AutoButtonColor = false
	b.Selectable = false
	b.Font = FUENTE
	b.TextSize = tamanoTexto or 13
	b.TextColor3 = GRIS_TEXTO
	b.Text = texto
	b.Parent = padre
	biselar(b)
	return b
end

-- Pinta un botón como "encendido" (verde) o "apagado" (blanco).
local function pintarBoton(boton, activo, texto)
	boton.Text = texto
	boton.BackgroundColor3 = activo and VERDE_HEADER or BLANCO
	boton.TextColor3 = activo and BLANCO or GRIS_TEXTO
end

-- Posiciones para dos botones lado a lado dentro de una tarjeta.
local function mitadIzq(y) return UDim2.new(0, 8, 0, y) end
local function mitadDer(y) return UDim2.new(0.5, 4, 0, y) end
local function tamMitad(alto) return UDim2.new(0.5, -12, 0, alto) end
local function tamCompleto(alto) return UDim2.new(1, -16, 0, alto) end

-- Insignia "Old Roblox" para el logo y el botón flotante: marco negro grueso,
-- anillo verde con 4 remaches blancos en las esquinas y una placa blanca en
-- el centro. Es simétrica, así que se ve bien mientras gira.
-- Devuelve la placa: ahí dentro va la imagen.
local function insigniaOldRoblox(base)
	base.BackgroundColor3 = VERDE_HEADER
	base.BorderSizePixel = 3
	base.BorderColor3 = NEGRO_BORDE
	local z = base.ZIndex

	local placa = Instance.new("Frame")
	placa.Name = "Placa"
	placa.AnchorPoint = Vector2.new(0.5, 0.5)
	placa.Position = UDim2.new(0.5, 0, 0.5, 0)
	placa.Size = UDim2.new(1, -10, 1, -10)
	placa.BackgroundColor3 = BLANCO
	placa.BorderSizePixel = 2
	placa.BorderColor3 = NEGRO_BORDE
	placa.ZIndex = z + 1
	placa.Parent = base

	for _, esquina in ipairs({ Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) }) do
		local remache = Instance.new("Frame")
		remache.Name = "Remache"
		remache.AnchorPoint = Vector2.new(0.5, 0.5)
		remache.Position = UDim2.new(esquina.X, esquina.X == 0 and 3 or -3, esquina.Y, esquina.Y == 0 and 3 or -3)
		remache.Size = UDim2.fromOffset(3, 3)
		remache.BackgroundColor3 = BLANCO
		remache.BorderSizePixel = 0
		remache.ZIndex = z + 1
		remache.Parent = base
	end

	return placa
end

--------------------------------------------------------------------
-- INTERFAZ — panel, cabecera, pestañas
--------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "JerryScriptGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local contenedor = Instance.new("Frame")
contenedor.Name = "Contenedor"
contenedor.Size = UDim2.new(0, ANCHO_PANEL, 0, ALTO_PANEL)
contenedor.Position = UDim2.new(0, 16, 1, -(ALTO_PANEL + 16))   -- abajo a la izquierda
contenedor.AnchorPoint = Vector2.new(0, 0)
contenedor.BackgroundTransparency = 1
contenedor.Parent = gui

-- Panel principal, anclado a su propio centro para la animación.
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(1, 0, 1, 0)
panel.BackgroundColor3 = BLANCO
panel.BorderSizePixel = 3
panel.BorderColor3 = NEGRO_BORDE
panel.Parent = contenedor

-- UIScale en "panel", NO en "contenedor" (contenedor lleva la posición en píxeles).
local escala = Instance.new("UIScale")
escala.Scale = 1
escala.Parent = panel

-- ===== Barra de título =====
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 36)
header.Position = UDim2.new(0, 0, 0, 0)
header.BackgroundColor3 = VERDE_HEADER
header.BorderSizePixel = 0
header.Parent = panel
degradado(header, 200)

local headerLineaInferior = Instance.new("Frame")
headerLineaInferior.Size = UDim2.new(1, 0, 0, 3)
headerLineaInferior.Position = UDim2.new(0, 0, 1, -3)
headerLineaInferior.BackgroundColor3 = VERDE_OSCURO
headerLineaInferior.BorderSizePixel = 0
headerLineaInferior.Parent = header

-- ===== Logo =====
local logoMarco = Instance.new("Frame")
logoMarco.Name = "LogoMarco"
logoMarco.Size = UDim2.new(0, 44, 0, 44)
logoMarco.Position = UDim2.new(0, -8, 0, -8)
logoMarco.BackgroundColor3 = BLANCO
logoMarco.BorderSizePixel = 3
logoMarco.BorderColor3 = NEGRO_BORDE
logoMarco.ZIndex = 5
logoMarco.Parent = header

if LOGO_ASSET_ID ~= "" then
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.new(1, -8, 1, -8)
	img.Position = UDim2.new(0.5, 0, 0.5, 0)
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.BackgroundTransparency = 1
	img.Image = LOGO_ASSET_ID
	img.ZIndex = 6
	img.Parent = logoMarco
else
	local emoji = Instance.new("TextLabel")
	emoji.Size = UDim2.new(1, -8, 1, -8)
	emoji.Position = UDim2.new(0.5, 0, 0.5, 0)
	emoji.AnchorPoint = Vector2.new(0.5, 0.5)
	emoji.BackgroundTransparency = 1
	emoji.Font = Enum.Font.GothamBold
	emoji.TextScaled = true
	emoji.Text = "🥬"
	emoji.ZIndex = 6
	emoji.Parent = logoMarco
end

-- Rotación continua del logo
task.spawn(function()
	while not destruido and gui.Parent do
		local giro = TweenService:Create(
			logoMarco, TweenInfo.new(3, Enum.EasingStyle.Linear), {Rotation = logoMarco.Rotation + 360}
		)
		giro:Play()
		giro.Completed:Wait()
	end
end)

-- ===== Texto de la cabecera =====
local nombreHub = Instance.new("TextLabel")
nombreHub.Size = UDim2.new(0, 150, 1, -3)
nombreHub.Position = UDim2.new(0, 44, 0, 0)
nombreHub.BackgroundTransparency = 1
nombreHub.Font = FUENTE
nombreHub.TextSize = 17
nombreHub.TextXAlignment = Enum.TextXAlignment.Left
nombreHub.TextColor3 = BLANCO
nombreHub.TextStrokeTransparency = 0.6
nombreHub.TextStrokeColor3 = VERDE_OSCURO
nombreHub.Text = "Jerry's Script V.1"
nombreHub.Parent = header

-- ===== Cartel "Self Destruct" =====
local ROJO_CARTEL = Color3.fromRGB(200, 40, 40)
local ROJO_HOVER = Color3.fromRGB(235, 70, 70)

local botonDestruir = Instance.new("TextButton")
botonDestruir.Name = "BotonSelfDestruct"
botonDestruir.Size = UDim2.new(0, 84, 0, 20)
botonDestruir.AnchorPoint = Vector2.new(1, 0.5)
botonDestruir.Position = UDim2.new(1, -8, 0.5, -1)
botonDestruir.BackgroundColor3 = ROJO_CARTEL
botonDestruir.BorderSizePixel = 2
botonDestruir.BorderColor3 = NEGRO_BORDE
botonDestruir.AutoButtonColor = false
botonDestruir.Font = FUENTE
botonDestruir.TextSize = 12
botonDestruir.TextColor3 = BLANCO
botonDestruir.Text = "Self Destruct"
botonDestruir.Parent = header
biselar(botonDestruir)

botonDestruir.MouseEnter:Connect(function()
	botonDestruir.BackgroundColor3 = ROJO_HOVER
end)
botonDestruir.MouseLeave:Connect(function()
	botonDestruir.BackgroundColor3 = ROJO_CARTEL
end)

--------------------------------------------------------------------
-- ARRASTRAR EL PANEL (desde la barra verde)
--------------------------------------------------------------------

header.Active = true

local arrastrandoPanel = false
local origenRaton = Vector2.zero
local origenPanel = Vector2.zero

local function moverPanelA(x, y)
	local pantalla = gui.AbsoluteSize
	local tam = contenedor.AbsoluteSize

	local maxX = math.max(0, pantalla.X - 60)
	local maxY = math.max(0, pantalla.Y - 42)
	x = math.clamp(x, -(tam.X - 60), maxX)
	y = math.clamp(y, 36, maxY)

	contenedor.Position = UDim2.fromOffset(x, y)
end

header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		arrastrandoPanel = true
		origenRaton = Vector2.new(input.Position.X, input.Position.Y)
		origenPanel = contenedor.AbsolutePosition
	end
end)

conectar(UserInputService.InputChanged, function(input)
	if not arrastrandoPanel then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
		local delta = Vector2.new(input.Position.X, input.Position.Y) - origenRaton
		moverPanelA(origenPanel.X + delta.X, origenPanel.Y + delta.Y)
	end
end)

conectar(UserInputService.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		arrastrandoPanel = false
	end
end)

--------------------------------------------------------------------
-- PESTAÑAS Y PÁGINAS
--------------------------------------------------------------------

local ORDEN_TABS = { "MOVER", "VISUAL", "COMBATE", "EXTRA" }
local paginas = {}
local botonesTab = {}

local barraTabs = Instance.new("Frame")
barraTabs.Name = "BarraTabs"
barraTabs.Position = UDim2.new(0, 8, 0, 42)
barraTabs.Size = UDim2.new(1, -16, 0, 24)
barraTabs.BackgroundTransparency = 1
barraTabs.Parent = panel

local listaTabs = Instance.new("UIListLayout")
listaTabs.FillDirection = Enum.FillDirection.Horizontal
listaTabs.SortOrder = Enum.SortOrder.LayoutOrder
listaTabs.Padding = UDim.new(0, 2)
listaTabs.Parent = barraTabs

local zonaPaginas = Instance.new("Frame")
zonaPaginas.Name = "ZonaPaginas"
zonaPaginas.Position = UDim2.new(0, 0, 0, Y_PAGINAS)
zonaPaginas.Size = UDim2.new(1, 0, 1, -(Y_PAGINAS + ALTO_PIE))
zonaPaginas.BackgroundTransparency = 1
zonaPaginas.Parent = panel

local function mostrarPagina(nombre)
	for n, pagina in pairs(paginas) do
		pagina.Visible = (n == nombre)
	end
	for n, boton in pairs(botonesTab) do
		local activa = (n == nombre)
		boton.BackgroundColor3 = activa and VERDE_HEADER or BLANCO
		boton.TextColor3 = activa and BLANCO or GRIS_TEXTO
	end
end

for i, nombre in ipairs(ORDEN_TABS) do
	local pagina = Instance.new("Frame")
	pagina.Name = "Pagina" .. nombre
	pagina.Size = UDim2.new(1, 0, 1, 0)
	pagina.BackgroundTransparency = 1
	pagina.Visible = false
	pagina.Parent = zonaPaginas
	paginas[nombre] = pagina

	local boton = crearBoton(barraTabs, "Tab" .. nombre, nombre, UDim2.new(), UDim2.new(0, 79, 1, 0), 13)
	boton.LayoutOrder = i
	botonesTab[nombre] = boton
	boton.MouseButton1Click:Connect(function()
		mostrarPagina(nombre)
	end)
end

--------------------------------------------------------------------
-- Tarjetas y medidores
--------------------------------------------------------------------

-- Tarjeta con su NOMBRE (barra verde) y una línea que dice qué hace.
local function crearTarjeta(pagina, nombre, descripcion, posY, alto)
	local tarjeta = Instance.new("Frame")
	tarjeta.Name = "Tarjeta" .. nombre
	tarjeta.Size = UDim2.new(1, -20, 0, alto)
	tarjeta.Position = UDim2.new(0, 10, 0, posY)
	tarjeta.BackgroundColor3 = VERDE_SUAVE
	tarjeta.BorderSizePixel = 2
	tarjeta.BorderColor3 = NEGRO_BORDE
	tarjeta.Parent = pagina

	local miniHeader = Instance.new("Frame")
	miniHeader.Name = "MiniHeader"
	miniHeader.Size = UDim2.new(1, 0, 0, 18)
	miniHeader.BackgroundColor3 = VERDE_OSCURO
	miniHeader.BorderSizePixel = 0
	miniHeader.Parent = tarjeta
	degradado(miniHeader, 190)

	local miniTexto = Instance.new("TextLabel")
	miniTexto.Size = UDim2.new(1, -10, 1, 0)
	miniTexto.Position = UDim2.new(0, 8, 0, 0)
	miniTexto.BackgroundTransparency = 1
	miniTexto.Font = FUENTE
	miniTexto.TextSize = 13
	miniTexto.TextXAlignment = Enum.TextXAlignment.Left
	miniTexto.TextColor3 = BLANCO
	miniTexto.Text = nombre
	miniTexto.Parent = miniHeader

	local textoDesc = Instance.new("TextLabel")
	textoDesc.Name = "Descripcion"
	textoDesc.Size = UDim2.new(1, -16, 0, 12)
	textoDesc.Position = UDim2.new(0, 8, 0, 20)
	textoDesc.BackgroundTransparency = 1
	textoDesc.Font = FUENTE
	textoDesc.TextSize = 11
	textoDesc.TextXAlignment = Enum.TextXAlignment.Left
	textoDesc.TextTruncate = Enum.TextTruncate.AtEnd
	textoDesc.TextColor3 = GRIS_TENUE
	textoDesc.Text = descripcion
	textoDesc.Parent = tarjeta

	return tarjeta
end

-- Medidor (barra deslizante). Ocupa 44 px de alto desde posY.
local function crearMedidor(tarjeta, posY, minimo, maximo, inicial, alCambiar, textos)
	local etiquetaVel = Instance.new("TextLabel")
	etiquetaVel.Size = UDim2.new(1, -80, 0, 14)
	etiquetaVel.Position = UDim2.new(0, 8, 0, posY)
	etiquetaVel.BackgroundTransparency = 1
	etiquetaVel.Font = FUENTE
	etiquetaVel.TextSize = 12
	etiquetaVel.TextXAlignment = Enum.TextXAlignment.Left
	etiquetaVel.TextColor3 = GRIS_TEXTO
	etiquetaVel.Text = (textos and textos.titulo) or "Velocidad"
	etiquetaVel.Parent = tarjeta

	local valor = Instance.new("TextLabel")
	valor.Size = UDim2.new(0, 60, 0, 14)
	valor.Position = UDim2.new(1, -68, 0, posY)
	valor.BackgroundTransparency = 1
	valor.Font = FUENTE
	valor.TextSize = 13
	valor.TextXAlignment = Enum.TextXAlignment.Right
	valor.TextColor3 = VERDE_HEADER
	valor.Text = tostring(inicial)
	valor.Parent = tarjeta

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -16, 0, 10)
	track.Position = UDim2.new(0, 8, 0, posY + 18)
	track.BackgroundColor3 = GRIS_TRACK
	track.BorderSizePixel = 2
	track.BorderColor3 = NEGRO_BORDE
	track.Parent = tarjeta

	local relleno = Instance.new("Frame")
	relleno.Size = UDim2.new(0, 0, 1, 0)
	relleno.BackgroundColor3 = VERDE_BARRA
	relleno.BorderSizePixel = 0
	relleno.Parent = track

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 14, 0, 16)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(0, 0, 0.5, 0)
	knob.BackgroundColor3 = BLANCO
	knob.BorderSizePixel = 2
	knob.BorderColor3 = NEGRO_BORDE
	knob.ZIndex = 3
	knob.Parent = track

	local labelIzq = Instance.new("TextLabel")
	labelIzq.Size = UDim2.new(0, 90, 0, 12)
	labelIzq.Position = UDim2.new(0, 8, 0, posY + 31)
	labelIzq.BackgroundTransparency = 1
	labelIzq.Font = FUENTE
	labelIzq.TextSize = 10
	labelIzq.TextColor3 = GRIS_TENUE
	labelIzq.TextXAlignment = Enum.TextXAlignment.Left
	labelIzq.Text = (textos and textos.izq) or "Más lento"
	labelIzq.Parent = tarjeta

	local labelDer = Instance.new("TextLabel")
	labelDer.Size = UDim2.new(0, 90, 0, 12)
	labelDer.AnchorPoint = Vector2.new(1, 0)
	labelDer.Position = UDim2.new(1, -8, 0, posY + 31)
	labelDer.BackgroundTransparency = 1
	labelDer.Font = FUENTE
	labelDer.TextSize = 10
	labelDer.TextColor3 = GRIS_TENUE
	labelDer.TextXAlignment = Enum.TextXAlignment.Right
	labelDer.Text = (textos and textos.der) or "Más rápido"
	labelDer.Parent = tarjeta

	local valorActual = inicial

	local function refrescar()
		local alfa = (valorActual - minimo) / (maximo - minimo)
		relleno.Size = UDim2.new(alfa, 0, 1, 0)
		knob.Position = UDim2.new(alfa, 0, 0.5, 0)
		valor.Text = tostring(math.floor(valorActual + 0.5))
	end

	refrescar()

	local arrastrando = false

	local function fijarDesdeX(x)
		local ancho = track.AbsoluteSize.X
		if ancho <= 0 then return end

		local alfa = math.clamp((x - track.AbsolutePosition.X) / ancho, 0, 1)
		valorActual = minimo + alfa * (maximo - minimo)
		refrescar()
		if alCambiar then
			alCambiar(valorActual)
		end
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			arrastrando = true
			fijarDesdeX(input.Position.X)
		end
	end)

	conectar(UserInputService.InputChanged, function(input)
		if arrastrando and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			fijarDesdeX(input.Position.X)
		end
	end)

	conectar(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			arrastrando = false
		end
	end)

	return {
		obtener = function() return valorActual end,
	}
end

--------------------------------------------------------------------
-- PESTAÑA MOVER: VUELO y NOCLIP
--------------------------------------------------------------------

-- Tarjeta VUELO
local tarjetaVuelo = crearTarjeta(paginas.MOVER, "VUELO", "Vuela por el mapa  ·  tecla F", 0, 108)

-- Botón de vuelo: hace lo mismo que la tecla F y muestra el estado
local subEstado = crearBoton(tarjetaVuelo, "BotonVuelo", "DESACTIVADO  (F)",
	UDim2.new(0, 8, 0, 34), tamCompleto(22), 13)

local function actualizarBotonVuelo()
	if volando then
		pintarBoton(subEstado, true, "ACTIVADO  (F)")
	else
		pintarBoton(subEstado, false, "DESACTIVADO  (F)")
	end
end

subEstado.MouseButton1Click:Connect(function()
	establecerVuelo(not volando)
end)

local medidorVuelo = crearMedidor(tarjetaVuelo, 60, VEL_MIN, VEL_MAX, velocidad, function(nuevoValor)
	velocidad = nuevoValor
end)

-- Tarjeta NOCLIP
local tarjetaNoclip = crearTarjeta(paginas.MOVER, "NOCLIP", "Atraviesa paredes y suelo", 114, 62)

local botonNoclip = crearBoton(tarjetaNoclip, "BotonNoclip", "DESACTIVADO",
	UDim2.new(0, 8, 0, 34), tamCompleto(22), 13)

--------------------------------------------------------------------
-- PESTAÑA VISUAL: FULLBRIGHT (el ESP se crea más abajo, en su bloque)
--------------------------------------------------------------------

-- Tarjeta FULLBRIGHT
local tarjetaFullbright = crearTarjeta(paginas.VISUAL, "FULLBRIGHT", "Quita la oscuridad del mapa", 94, 62)

local botonFullbright = crearBoton(tarjetaFullbright, "BotonFullbright", "DESACTIVADO",
	UDim2.new(0, 8, 0, 34), tamCompleto(22), 13)

--------------------------------------------------------------------
-- PESTAÑA EXTRA: FLING A JUGADOR y GMABER1090
--------------------------------------------------------------------

-- Tarjeta FLING A JUGADOR (nombre + botón + medidor de fuerza)
local tarjetaDirigido = crearTarjeta(paginas.EXTRA, "FLING A JUGADOR",
	"Escribe un nombre y lánzalo por los aires", 0, 126)

local cajaNombre = Instance.new("TextBox")
cajaNombre.Name = "CajaNombreFling"
cajaNombre.Size = UDim2.new(1, -114, 0, 24)
cajaNombre.Position = UDim2.new(0, 8, 0, 34)
cajaNombre.BackgroundColor3 = BLANCO
cajaNombre.BorderSizePixel = 2
cajaNombre.BorderColor3 = NEGRO_BORDE
cajaNombre.Font = FUENTE
cajaNombre.TextSize = 13
cajaNombre.TextColor3 = GRIS_TEXTO
cajaNombre.TextXAlignment = Enum.TextXAlignment.Left
cajaNombre.PlaceholderText = "Nombre del jugador"
cajaNombre.PlaceholderColor3 = GRIS_TENUE
cajaNombre.ClearTextOnFocus = false
cajaNombre.Text = ""
cajaNombre.Parent = tarjetaDirigido

local margenCaja = Instance.new("UIPadding")
margenCaja.PaddingLeft = UDim.new(0, 6)
margenCaja.Parent = cajaNombre

local botonDirigido = crearBoton(tarjetaDirigido, "BotonFlingDirigido", "LANZAR",
	UDim2.new(1, -8, 0, 34), UDim2.new(0, 92, 0, 24), 13)
botonDirigido.AnchorPoint = Vector2.new(1, 0)

local medidorFling = crearMedidor(tarjetaDirigido, 64, FUERZA_MIN, FUERZA_MAX, fuerzaFling, function(nuevoValor)
	fuerzaFling = nuevoValor
end, { titulo = "Fuerza", izq = "Más suave", der = "Más fuerte" })

local estadoDirigido = Instance.new("TextLabel")
estadoDirigido.Name = "EstadoDirigido"
estadoDirigido.Size = UDim2.new(1, -16, 0, 12)
estadoDirigido.Position = UDim2.new(0, 8, 0, 110)
estadoDirigido.BackgroundTransparency = 1
estadoDirigido.Font = FUENTE
estadoDirigido.TextSize = 11
estadoDirigido.TextXAlignment = Enum.TextXAlignment.Left
estadoDirigido.TextTruncate = Enum.TextTruncate.AtEnd
estadoDirigido.TextColor3 = GRIS_TENUE
estadoDirigido.Text = ""
estadoDirigido.Parent = tarjetaDirigido

-- Tarjeta GMABER1090 (giro)
local tarjetaGiro = crearTarjeta(paginas.EXTRA, "GMABER1090", "Tu personaje gira sin parar", 132, 108)

local botonGiro = crearBoton(tarjetaGiro, "BotonGiro", "DESACTIVADO",
	UDim2.new(0, 8, 0, 34), tamCompleto(22), 13)

local medidorGiro = crearMedidor(tarjetaGiro, 60, GIRO_MIN, GIRO_MAX, velocidadGiro, function(nuevoValor)
	velocidadGiro = nuevoValor
	if angularVelocity and angularVelocity.Enabled then
		angularVelocity.AngularVelocity = Vector3.new(0, math.rad(velocidadGiro), 0)
	end
end)

-- Los botones no deben poder "seleccionarse" con el teclado (Espacio
-- los re-pulsaría mientras vuelas).
for _, boton in ipairs({ botonDestruir, botonNoclip, botonGiro, botonFullbright, botonDirigido }) do
	boton.Selectable = false
end

--------------------------------------------------------------------
-- Pie
--------------------------------------------------------------------

local pie = Instance.new("TextLabel")
pie.Size = UDim2.new(1, -90, 0, 16)
pie.Position = UDim2.new(0, 10, 1, -20)
pie.BackgroundTransparency = 1
pie.Font = FUENTE
pie.TextSize = 10
pie.TextColor3 = GRIS_TENUE
pie.TextXAlignment = Enum.TextXAlignment.Left
pie.Text = "F: volar  •  H: panel  •  arrastra la barra verde"
pie.Parent = panel

local firma = Instance.new("TextLabel")
firma.Name = "Firma"
firma.Size = UDim2.new(0, 60, 0, 14)
firma.AnchorPoint = Vector2.new(1, 1)
firma.Position = UDim2.new(1, -8, 1, -3)
firma.BackgroundTransparency = 1
firma.Font = FUENTE
firma.TextSize = 9
firma.TextXAlignment = Enum.TextXAlignment.Right
firma.TextColor3 = GRIS_TENUE
firma.TextTransparency = 0.15
firma.Text = "By: Has.&52"
firma.Parent = panel

-- Pestaña que se ve al abrir
mostrarPagina("MOVER")

--------------------------------------------------------------------
-- ANIMACIÓN DE ABRIR / CERRAR
--------------------------------------------------------------------

local guiAbierto = true
local tweenPanelActual = nil
local versionAnim = 0
local ESCALA_CERRADO = 0.01      -- nunca 0 exacto
local DUR_CERRAR = 0.22

local function abrirPanel()
	versionAnim += 1
	if tweenPanelActual then
		tweenPanelActual:Cancel()
	end
	contenedor.Visible = true
	tweenPanelActual = TweenService:Create(
		escala,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Scale = 1}
	)
	tweenPanelActual:Play()
end

local function cerrarPanel()
	versionAnim += 1
	local miVersion = versionAnim

	if tweenPanelActual then
		tweenPanelActual:Cancel()
	end
	tweenPanelActual = TweenService:Create(
		escala,
		TweenInfo.new(DUR_CERRAR, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Scale = ESCALA_CERRADO}
	)
	tweenPanelActual:Play()

	task.delay(DUR_CERRAR + 0.03, function()
		if destruido or versionAnim ~= miVersion then return end
		if contenedor and contenedor.Parent then
			contenedor.Visible = false
		end
	end)
end

local function alternarPanel()
	guiAbierto = not guiAbierto
	if guiAbierto then
		abrirPanel()
	else
		cerrarPanel()
	end
end

--------------------------------------------------------------------
-- BOTÓN FLOTANTE DE LECHUGA (abre / cierra el panel, sobre todo para móvil)
--------------------------------------------------------------------
--[[
	Un botón cuadrado siempre visible, en medio de la pantalla, con la
	lechuga girando dentro. Un toque corto (o clic) hace lo mismo que
	la tecla H; si lo arrastras, se mueve por la pantalla. Vive en el ScreenGui, no dentro del panel, así que sigue
	ahí aunque el panel esté cerrado. Gira el botón
	entero (cuadrado, borde e imagen a la vez).
]]
do
	local botonLechuga = Instance.new("TextButton")
	botonLechuga.Name = "BotonLechuga"
	botonLechuga.Size = UDim2.new(0, 52, 0, 52)
	botonLechuga.AnchorPoint = Vector2.new(0.5, 0.5)
	botonLechuga.Position = UDim2.new(0.5, 0, 0.5, 0)   -- en medio de la pantalla
	botonLechuga.BackgroundColor3 = BLANCO
	botonLechuga.BorderSizePixel = 3
	botonLechuga.BorderColor3 = NEGRO_BORDE
	botonLechuga.AutoButtonColor = false
	botonLechuga.Selectable = false
	botonLechuga.Text = ""
	botonLechuga.ZIndex = 20
	botonLechuga.Parent = gui

	local giratorio
	if LOGO_ASSET_ID ~= "" then
		giratorio = Instance.new("ImageLabel")
		giratorio.Image = LOGO_ASSET_ID
	else
		giratorio = Instance.new("TextLabel")
		giratorio.Font = Enum.Font.GothamBold
		giratorio.TextScaled = true
		giratorio.Text = "🥬"
	end
	giratorio.Size = UDim2.new(1, -10, 1, -10)
	giratorio.Position = UDim2.new(0.5, 0, 0.5, 0)
	giratorio.AnchorPoint = Vector2.new(0.5, 0.5)
	giratorio.BackgroundTransparency = 1
	giratorio.ZIndex = 21
	giratorio.Parent = botonLechuga

	-- Giro continuo: gira el BOTÓN entero (cuadrado + borde), y la imagen
	-- que lleva dentro gira con él.
	task.spawn(function()
		while not destruido and gui.Parent do
			local giro = TweenService:Create(
				botonLechuga, TweenInfo.new(3, Enum.EasingStyle.Linear), {Rotation = botonLechuga.Rotation + 360}
			)
			giro:Play()
			giro.Completed:Wait()
		end
	end)

	-- Un toque corto abre/cierra el panel; si arrastras (más de UMBRAL
	-- píxeles) el botón se mueve y NO se abre/cierra al soltar.
	local UMBRAL_ARRASTRE = 8
	local arrastrando = false
	local movido = false
	local inputActual = nil
	local inicioPuntero = Vector2.zero
	local centroInicio = Vector2.zero

	botonLechuga.InputBegan:Connect(function(input)
		if arrastrando then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			arrastrando = true
			movido = false
			inputActual = input
			inicioPuntero = Vector2.new(input.Position.X, input.Position.Y)
			centroInicio = botonLechuga.AbsolutePosition + botonLechuga.AbsoluteSize / 2
		end
	end)

	conectar(UserInputService.InputChanged, function(input)
		if not arrastrando then return end
		local esRaton = input.UserInputType == Enum.UserInputType.MouseMovement
		local esDedo = input.UserInputType == Enum.UserInputType.Touch and input == inputActual
		if not (esRaton or esDedo) then return end

		local delta = Vector2.new(input.Position.X, input.Position.Y) - inicioPuntero
		if not movido and delta.Magnitude < UMBRAL_ARRASTRE then return end
		movido = true

		-- Se mueve en offsets puros y sin salirse de la pantalla
		local pantalla = gui.AbsoluteSize
		local mitad = botonLechuga.AbsoluteSize / 2
		local x = math.clamp(centroInicio.X + delta.X, mitad.X, math.max(mitad.X, pantalla.X - mitad.X))
		local y = math.clamp(centroInicio.Y + delta.Y, mitad.Y, math.max(mitad.Y, pantalla.Y - mitad.Y))
		botonLechuga.Position = UDim2.fromOffset(x, y)
	end)

	conectar(UserInputService.InputEnded, function(input)
		if not arrastrando then return end
		local esClic = input.UserInputType == Enum.UserInputType.MouseButton1
		local esDedo = input.UserInputType == Enum.UserInputType.Touch and input == inputActual
		if not (esClic or esDedo) then return end

		arrastrando = false
		inputActual = nil
		if not movido then
			alternarPanel()
		end
	end)
end

--------------------------------------------------------------------
-- NOCLIP
--------------------------------------------------------------------

local noclipActivo = false
local personajeActual = nil

local function aplicarColisiones(character, sinColision)
	for _, parte in ipairs(character:GetDescendants()) do
		if parte:IsA("BasePart") then
			parte.CanCollide = not sinColision
		end
	end
end

local function actualizarBotonNoclip()
	pintarBoton(botonNoclip, noclipActivo, noclipActivo and "ACTIVADO" or "DESACTIVADO")
end

local function establecerNoclip(estado)
	noclipActivo = estado
	actualizarBotonNoclip()

	if not estado and personajeActual and root then
		task.defer(function()
			if root and root.Parent then
				root.AssemblyLinearVelocity = Vector3.zero
			end
		end)
	end

	if not estado and personajeActual then
		aplicarColisiones(personajeActual, false)
	end
end

conectar(RunService.Heartbeat, function()
	if noclipActivo and personajeActual and personajeActual.Parent then
		aplicarColisiones(personajeActual, true)
	end
end)

botonNoclip.MouseButton1Click:Connect(function()
	local nuevo = not noclipActivo
	if nuevo and cancelarFlingDirigido then
		cancelarFlingDirigido()  -- sin colisiones no hay lanzamiento
	end
	establecerNoclip(nuevo)
end)

--------------------------------------------------------------------
-- GMABER1090 — giro continuo del personaje
--------------------------------------------------------------------

local giroActivo = false

local function actualizarBotonGiro()
	pintarBoton(botonGiro, giroActivo, giroActivo and "ACTIVADO" or "DESACTIVADO")
end

local function establecerGiro(estado)
	giroActivo = estado
	actualizarBotonGiro()

	if not humanoid or not angularVelocity then return end

	humanoid.AutoRotate = not estado
	angularVelocity.Enabled = estado

	if alignOrientation then
		alignOrientation.Enabled = volando and not estado
	end

	if estado then
		angularVelocity.AngularVelocity = Vector3.new(0, math.rad(velocidadGiro), 0)
	else
		angularVelocity.AngularVelocity = Vector3.zero
	end
end

botonGiro.MouseButton1Click:Connect(function()
	establecerGiro(not giroActivo)
end)

--------------------------------------------------------------------
-- FULLBRIGHT — quita la oscuridad del mapa (solo en tu cliente)
--------------------------------------------------------------------

local fullbrightActivo = false
local luzOriginal = nil
local efectosApagados = {}

local function actualizarBotonFullbright()
	pintarBoton(botonFullbright, fullbrightActivo, fullbrightActivo and "ACTIVADO" or "DESACTIVADO")
end

local function establecerFullbright(estado)
	if estado == fullbrightActivo then return end
	fullbrightActivo = estado
	actualizarBotonFullbright()

	if estado then
		luzOriginal = {
			Brightness = Lighting.Brightness,
			ClockTime = Lighting.ClockTime,
			FogEnd = Lighting.FogEnd,
			FogStart = Lighting.FogStart,
			GlobalShadows = Lighting.GlobalShadows,
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			ExposureCompensation = Lighting.ExposureCompensation,
		}

		Lighting.Brightness = 3
		Lighting.ClockTime = 14
		Lighting.FogEnd = 1e6
		Lighting.FogStart = 0
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(178, 178, 178)
		Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
		Lighting.ExposureCompensation = 0

		table.clear(efectosApagados)
		for _, efecto in ipairs(Lighting:GetChildren()) do
			if efecto:IsA("Atmosphere") or efecto:IsA("BlurEffect")
				or efecto:IsA("ColorCorrectionEffect") or efecto:IsA("SunRaysEffect") then
				if efecto:IsA("Atmosphere") then
					efecto.Parent = nil
					table.insert(efectosApagados, { objeto = efecto, atmosfera = true })
				elseif efecto.Enabled then
					efecto.Enabled = false
					table.insert(efectosApagados, { objeto = efecto, atmosfera = false })
				end
			end
		end
	else
		if luzOriginal then
			for propiedad, valor in pairs(luzOriginal) do
				pcall(function()
					Lighting[propiedad] = valor
				end)
			end
			luzOriginal = nil
		end

		for _, guardado in ipairs(efectosApagados) do
			local objeto = guardado.objeto
			if objeto then
				pcall(function()
					if guardado.atmosfera then
						objeto.Parent = Lighting
					else
						objeto.Enabled = true
					end
				end)
			end
		end
		table.clear(efectosApagados)
	end
end

botonFullbright.MouseButton1Click:Connect(function()
	establecerFullbright(not fullbrightActivo)
end)

--------------------------------------------------------------------
-- FLING A UN JUGADOR (por nombre)
--------------------------------------------------------------------
--[[
	POR QUÉ LA VERSIÓN ANTERIOR CASI NO FUNCIONABA, Y QUÉ SE CAMBIÓ:

	1) El empujón se aplicaba TAMBIÉN en Stepped, que es ANTES de la
	   física. Tu propio cuerpo salía disparado cientos de studs en
	   cada paso de simulación y se desenganchaba del objetivo. Ahora
	   el empujón solo se aplica en Heartbeat (DESPUÉS de la física,
	   que es lo que se replica al resto de jugadores) y en
	   RenderStepped (antes de la física) se restaura tu velocidad
	   real, así tu cuerpo se comporta con normalidad en tu pantalla.

	2) La ráfaga duraba como máximo 0,6 s. Con algo de ping, el
	   objetivo ni había recibido tu contacto todavía. Ahora dura hasta
	   DURACION_DIRIGIDO (1,5 s), pero CORTA EN CUANTO el objetivo sale
	   despedido (se aleja DIST_LANZADO studs o supera VEL_LANZADO).

	3) Te teletransportabas a donde el objetivo ESTABA. Si caminaba,
	   fallabas. Ahora te adelantas según su velocidad (ANTICIPACION).

	4) Contactaba siempre con la misma zona. Ahora cambia de pose cada
	   frame (encima, debajo y a los lados) con el cuerpo girando, para
	   que alguna parte de tu personaje siempre toque la suya.

	5) Volver era un solo teletransporte. Ahora hay una FASE DE REGRESO:
	   te devuelve a tu sitio y frena TODAS las partes de tu personaje
	   hasta que estás quieto y en tu posición original. Después
	   recupera el vuelo si lo tenías.

	6) La cámara giraba contigo. Durante la ráfaga se queda mirando al
	   objetivo, y al terminar vuelve a ti.

	Se mantiene: el pico SOLO se aplica mientras estás enganchado, tu
	velocidad real se guarda UNA vez, y el vuelo se apaga mientras dura.

	El nombre se busca sin distinguir mayúsculas: nombre de usuario o
	DisplayName, completo o parcial. Prioridad: exacto > empieza por >
	contiene.
]]

local velGuardada = Vector3.zero
local angGuardada = Vector3.zero
local picoPendiente = false     -- hay un pico aplicado sin restaurar
local volabaAntesDeFling = false

local dirigidoActivo = false    -- hay un lanzamiento en curso
local jugadorDirigido = nil     -- el Player al que apunta
local objetivoFling = nil       -- HumanoidRootPart del objetivo mientras estás pegado
local faseFling = nil           -- nil | "ataque" | "regreso"
local inicioRafaga = 0
local finRafaga = 0
local finRegreso = 0
local framesRegreso = 0
local mensajeFinal = "Listo"
local pasoFling = 0
local dirEmpuje = Vector3.zero
local posInicioObjetivo = Vector3.zero
local posAntesRafaga = nil      -- dónde estabas antes de pegarte
local camaraSobreObjetivo = false

-- Posiciones (relativas al objetivo) por las que va rotando tu cuerpo
local POSES_FLING = {
	Vector3.new(0, 1.5, 0),
	Vector3.new(0, -1.5, 0),
	Vector3.new(2.25, 1.5, -2.25),
	Vector3.new(-2.25, -1.5, 2.25),
}

local function mostrarEstadoDirigido(texto, esError)
	estadoDirigido.Text = texto
	estadoDirigido.TextColor3 = esError and ROJO_CARTEL or GRIS_TENUE
end

local function actualizarBotonDirigido()
	if dirigidoActivo then
		pintarBoton(botonDirigido, true, "LANZANDO...")
	else
		pintarBoton(botonDirigido, false, "LANZAR")
	end
end

-- Si hay un pico aplicado sin restaurar, te devuelve tu velocidad real
local function restaurarPico()
	if picoPendiente and root and root.Parent then
		root.AssemblyLinearVelocity = velGuardada
		root.AssemblyAngularVelocity = angGuardada
	end
	picoPendiente = false
end

-- Deja quietas TODAS las partes de tu personaje (velocidad lineal y angular a 0)
local function frenarPersonaje()
	if not personajeActual or not personajeActual.Parent then return end
	for _, parte in ipairs(personajeActual:GetDescendants()) do
		if parte:IsA("BasePart") then
			parte.AssemblyLinearVelocity = Vector3.zero
			parte.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

-- La cámara vuelve a seguirte a ti
local function restaurarCamara()
	if not camaraSobreObjetivo then return end
	camaraSobreObjetivo = false
	local camara = workspace.CurrentCamera
	if camara and humanoid and humanoid.Parent then
		pcall(function()
			camara.CameraSubject = humanoid
		end)
	end
end

-- Termina todo: te devuelve a tu sitio, frena tu personaje, restaura la
-- cámara y recupera el vuelo si lo tenías encendido antes.
local function terminarRafaga()
	if posAntesRafaga and personajeActual and personajeActual.Parent then
		personajeActual:PivotTo(posAntesRafaga)
	end
	objetivoFling = nil
	faseFling = nil
	posAntesRafaga = nil
	restaurarCamara()
	frenarPersonaje()
	velGuardada = Vector3.zero
	angGuardada = Vector3.zero
	picoPendiente = false

	if volabaAntesDeFling then
		volabaAntesDeFling = false
		establecerVuelo(true)
	end
end

-- Devuelve (jugador) o (nil, "motivo del fallo")
local function buscarJugadorPorNombre(texto)
	local limpio = string.lower((string.gsub(texto or "", "^%s*(.-)%s*$", "%1")))
	if limpio == "" then
		return nil, "Escribe el nombre de un jugador"
	end

	local exacto, prefijo, contiene
	for _, j in ipairs(Players:GetPlayers()) do
		local nombre = string.lower(j.Name)
		local visible = string.lower(j.DisplayName)
		if nombre == limpio or visible == limpio then
			exacto = exacto or j
		elseif string.sub(nombre, 1, #limpio) == limpio or string.sub(visible, 1, #limpio) == limpio then
			prefijo = prefijo or j
		elseif string.find(nombre, limpio, 1, true) or string.find(visible, limpio, 1, true) then
			contiene = contiene or j
		end
	end

	local encontrado = exacto or prefijo or contiene
	if not encontrado then
		return nil, "No hay ningún jugador con ese nombre"
	end
	if encontrado == player then
		return nil, "Ese eres tú"
	end
	return encontrado
end

local function raizDeJugador(j)
	local personaje = j and j.Character
	return personaje and personaje:FindFirstChild("HumanoidRootPart")
end

local function finalizarFlingDirigido(mensaje, esError)
	dirigidoActivo = false
	jugadorDirigido = nil
	faseFling = nil
	actualizarBotonDirigido()
	if mensaje then
		mostrarEstadoDirigido(mensaje, esError)
	end
end

cancelarFlingDirigido = function()
	if not dirigidoActivo then return end
	dirigidoActivo = false      -- primero: así el vuelo restaurado no vuelve a llamar aquí
	terminarRafaga()            -- te devuelve a tu sitio y recupera vuelo/cámara
	finalizarFlingDirigido("Cancelado", false)
end

-- Te pega al objetivo y guarda lo necesario para volver. Devuelve true si engancha.
local function engancharAhora()
	local raizObj = raizDeJugador(jugadorDirigido)
	if not raizObj then
		finalizarFlingDirigido("El jugador ya no está o no tiene personaje", true)
		return false
	end

	-- Tu velocidad y posición reales se guardan UNA sola vez, antes de tocar nada.
	velGuardada = root.AssemblyLinearVelocity
	angGuardada = root.AssemblyAngularVelocity
	posAntesRafaga = root.CFrame

	if volando then
		volabaAntesDeFling = true
		establecerVuelo(false)
	end

	-- Dirección del empujón: desde donde estabas hacia el objetivo (en plano).
	local hacia = Vector3.new(
		raizObj.Position.X - posAntesRafaga.Position.X, 0,
		raizObj.Position.Z - posAntesRafaga.Position.Z
	)
	if hacia.Magnitude > 0.5 then
		dirEmpuje = hacia.Unit
	else
		local mira = root.CFrame.LookVector
		local plano = Vector3.new(mira.X, 0, mira.Z)
		dirEmpuje = plano.Magnitude > 0.01 and plano.Unit or Vector3.new(0, 0, -1)
	end

	-- La cámara se queda mirando al objetivo mientras dura la ráfaga
	local humObjetivo = raizObj.Parent and raizObj.Parent:FindFirstChildOfClass("Humanoid")
	local camara = workspace.CurrentCamera
	if humObjetivo and camara then
		camaraSobreObjetivo = pcall(function()
			camara.CameraSubject = humObjetivo
		end)
	end

	objetivoFling = raizObj
	faseFling = "ataque"
	posInicioObjetivo = raizObj.Position
	pasoFling = 0
	inicioRafaga = os.clock()
	finRafaga = inicioRafaga + DURACION_DIRIGIDO
	return true
end

-- Te pega al objetivo (adelantándote a su movimiento) y aplica el empujón.
local function aplicarPico()
	if not objetivoFling or not objetivoFling.Parent or not root or not root.Parent or not personajeActual then
		return
	end

	pasoFling += 1
	local pose = POSES_FLING[(pasoFling - 1) % #POSES_FLING + 1]

	local vel = objetivoFling.AssemblyLinearVelocity
	local adelante = Vector3.new(vel.X, 0, vel.Z) * ANTICIPACION

	personajeActual:PivotTo(
		CFrame.new(objetivoFling.Position + adelante + pose) * CFrame.Angles(math.rad(pasoFling * 100), 0, 0)
	)

	local giro = fuerzaFling / 20
	root.AssemblyLinearVelocity = dirEmpuje * fuerzaFling + Vector3.new(0, fuerzaFling, 0)
	root.AssemblyAngularVelocity = Vector3.new(giro, giro, giro)
	picoPendiente = true
end

local function iniciarFlingDirigido()
	if dirigidoActivo then return end
	if not root or not root.Parent or not personajeActual then return end

	local objetivo, motivo = buscarJugadorPorNombre(cajaNombre.Text)
	if not objetivo then
		mostrarEstadoDirigido(motivo, true)
		return
	end
	if not raizDeJugador(objetivo) then
		mostrarEstadoDirigido(objetivo.Name .. " no tiene personaje ahora mismo", true)
		return
	end

	-- Siempre con colisiones
	if noclipActivo then
		establecerNoclip(false)
	end

	jugadorDirigido = objetivo
	dirigidoActivo = true
	actualizarBotonDirigido()
	mostrarEstadoDirigido("Lanzando a " .. objetivo.Name .. "...", false)

	-- Enganche INMEDIATO (sin esperar al siguiente frame)
	if engancharAhora() then
		aplicarPico()
	end
end

botonDirigido.MouseButton1Click:Connect(iniciarFlingDirigido)

-- Al salir de la caja: si pulsaste Enter, lanza; si no, confirma a quién ha encontrado.
cajaNombre.FocusLost:Connect(function(enterPresionado)
	if dirigidoActivo then return end
	if cajaNombre.Text == "" then
		mostrarEstadoDirigido("", false)
		return
	end
	if enterPresionado then
		iniciarFlingDirigido()
		return
	end
	local j, motivo = buscarJugadorPorNombre(cajaNombre.Text)
	if j then
		mostrarEstadoDirigido("Objetivo: " .. j.DisplayName .. " (@" .. j.Name .. ")", false)
	else
		mostrarEstadoDirigido(motivo, true)
	end
end)

-- Heartbeat (DESPUÉS de la física): aquí se aplica el empujón y se controla el final.
conectar(RunService.Heartbeat, function()
	if not dirigidoActivo or not root or not root.Parent or not personajeActual then return end

	local ahora = os.clock()

	-- ===== Fase de regreso: volver a tu sitio y quedarte quieto =====
	if faseFling == "regreso" then
		if posAntesRafaga then
			personajeActual:PivotTo(posAntesRafaga)
			frenarPersonaje()
			if (root.Position - posAntesRafaga.Position).Magnitude < DIST_REGRESO then
				framesRegreso += 1
			end
		end
		if framesRegreso >= 3 or ahora >= finRegreso or not posAntesRafaga then
			terminarRafaga()
			finalizarFlingDirigido(mensajeFinal, false)
		end
		return
	end

	-- ===== Fase de ataque =====
	if not objetivoFling then
		-- Por si el enganche inmediato no llegó a producirse
		if not engancharAhora() then return end
	end

	local objetivoVivo = objetivoFling.Parent ~= nil
	local lanzado = false
	if objetivoVivo and (ahora - inicioRafaga) > 0.08 then
		lanzado = (objetivoFling.Position - posInicioObjetivo).Magnitude >= DIST_LANZADO
			or objetivoFling.AssemblyLinearVelocity.Magnitude >= VEL_LANZADO
	end

	if lanzado or not objetivoVivo or ahora >= finRafaga then
		if lanzado then
			mensajeFinal = "Listo: lanzado"
		elseif objetivoVivo then
			mensajeFinal = "No salió: repite o sube la fuerza"
		else
			mensajeFinal = "Listo"
		end

		-- Pasamos a la fase de regreso YA, en este mismo frame: así no se
		-- replica ni un frame más de empujón.
		objetivoFling = nil
		picoPendiente = false
		faseFling = "regreso"
		framesRegreso = 0
		finRegreso = ahora + TIEMPO_REGRESO
		restaurarCamara()
		if posAntesRafaga then
			personajeActual:PivotTo(posAntesRafaga)
		end
		frenarPersonaje()
		return
	end

	aplicarPico()
end)

-- RenderStepped (ANTES de simular): se restaura tu velocidad real, para que
-- tu cuerpo no salga disparado en tu propia pantalla. (Ya no hay ningún
-- empujón en Stepped: ese era el fallo principal.)
conectar(RunService.RenderStepped, function()
	restaurarPico()
end)

--------------------------------------------------------------------
-- AIMBOT — tarjeta en la pestaña COMBATE + lógica de apuntado
--------------------------------------------------------------------
--[[
	Se activa con el botón AIMBOT del panel y desde ese momento APUNTA
	SOLO, sin pulsar ningún botón. Solo se fija en jugadores cuya parte elegida caiga
	DENTRO del círculo verde que sigue a tu ratón (el tamaño lo ajustas
	con la barra). Si hay varios, elige el más cercano al centro.

	  * WALL CHECK: si hay una pared (o cualquier objeto) entre tu
	    cámara y esa parte, ese jugador se ignora.
	  * TEAM CHECK: ignora a los jugadores de tu mismo equipo. Si el
	    juego no usa equipos, no filtra a nadie.
	  * Parte a la que apuntar: CABEZA, TORSO, BRAZOS o PIERNAS. Con
	    BRAZOS y PIERNAS elige la que esté más cerca del centro del
	    círculo. Funciona con personajes R6 y R15.

	La cámara se mueve en un paso de render con prioridad justo por
	encima de la cámara del juego, para que este no la pise.
	SUAVIZADO_AIM: 1 = apunta al instante; valores menores (0.2, 0.1...)
	lo hacen más gradual.
]]
do
	local RADIO_AIM_MIN = 40
	local RADIO_AIM_MAX = 400
	local SUAVIZADO_AIM = 1

	local radioAimbot = 150
	local aimbotActivo = false
	local wallCheck = true
	local teamCheck = true
	local parteAim = "CABEZA"

	local ORDEN_PARTES = { "CABEZA", "TORSO", "BRAZOS", "PIERNAS" }
	local PARTES_AIM = {
		CABEZA = { "Head" },
		TORSO = { "UpperTorso", "LowerTorso", "Torso" },
		BRAZOS = { "RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm", "Right Arm", "Left Arm" },
		PIERNAS = { "RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg", "Right Leg", "Left Leg" },
	}

	-- ===== Interfaz =====
	local tarjetaAimbot = crearTarjeta(paginas.COMBATE, "AIMBOT",
		"La cámara apunta sola al jugador del círculo", 0, 204)

	local botonAimbot = crearBoton(tarjetaAimbot, "BotonAimbot", "DESACTIVADO",
		UDim2.new(0, 8, 0, 34), tamCompleto(22), 13)
	local botonWallCheck = crearBoton(tarjetaAimbot, "BotonWallCheck", "WALL CHECK: SÍ",
		mitadIzq(60), tamMitad(22), 12)
	local botonTeamCheck = crearBoton(tarjetaAimbot, "BotonTeamCheck", "TEAM CHECK: SÍ",
		mitadDer(60), tamMitad(22), 12)

	crearMedidor(tarjetaAimbot, 88, RADIO_AIM_MIN, RADIO_AIM_MAX, radioAimbot, function(nuevoValor)
		radioAimbot = nuevoValor
	end, { titulo = "Tamaño del círculo", izq = "Pequeño", der = "Grande" })

	local etiquetaParte = Instance.new("TextLabel")
	etiquetaParte.Size = UDim2.new(1, -16, 0, 12)
	etiquetaParte.Position = UDim2.new(0, 8, 0, 136)
	etiquetaParte.BackgroundTransparency = 1
	etiquetaParte.Font = FUENTE
	etiquetaParte.TextSize = 12
	etiquetaParte.TextXAlignment = Enum.TextXAlignment.Left
	etiquetaParte.TextColor3 = GRIS_TEXTO
	etiquetaParte.Text = "Apuntar a:"
	etiquetaParte.Parent = tarjetaAimbot

	local botonesParte = {}
	for i, nombre in ipairs(ORDEN_PARTES) do
		local y = (i <= 2) and 150 or 176
		local pos = (i % 2 == 1) and mitadIzq(y) or mitadDer(y)
		botonesParte[nombre] = crearBoton(tarjetaAimbot, "BotonParte" .. nombre, nombre, pos, tamMitad(22), 12)
	end

	-- Círculo del aimbot: vive en el ScreenGui (no dentro del panel), así
	-- sigue visible aunque cierres el panel con H.
	local circuloAim = Instance.new("Frame")
	circuloAim.Name = "CirculoAimbot"
	circuloAim.AnchorPoint = Vector2.new(0.5, 0.5)
	circuloAim.BackgroundTransparency = 1
	circuloAim.BorderSizePixel = 0
	circuloAim.Visible = false
	circuloAim.Size = UDim2.fromOffset(radioAimbot * 2, radioAimbot * 2)

	local esquinaCirculo = Instance.new("UICorner")
	esquinaCirculo.CornerRadius = UDim.new(1, 0)
	esquinaCirculo.Parent = circuloAim

	local bordeCirculo = Instance.new("UIStroke")
	bordeCirculo.Color = VERDE_HEADER
	bordeCirculo.Thickness = 2
	bordeCirculo.Parent = circuloAim

	circuloAim.Parent = gui

	local function actualizarBotonesAim()
		pintarBoton(botonAimbot, aimbotActivo, aimbotActivo and "ACTIVADO" or "DESACTIVADO")
		pintarBoton(botonWallCheck, wallCheck, wallCheck and "WALL CHECK: SÍ" or "WALL CHECK: NO")
		pintarBoton(botonTeamCheck, teamCheck, teamCheck and "TEAM CHECK: SÍ" or "TEAM CHECK: NO")
		for nombre, boton in pairs(botonesParte) do
			pintarBoton(boton, nombre == parteAim, nombre)
		end
		circuloAim.Visible = aimbotActivo
	end

	botonAimbot.MouseButton1Click:Connect(function()
		aimbotActivo = not aimbotActivo
		actualizarBotonesAim()
	end)
	botonWallCheck.MouseButton1Click:Connect(function()
		wallCheck = not wallCheck
		actualizarBotonesAim()
	end)
	botonTeamCheck.MouseButton1Click:Connect(function()
		teamCheck = not teamCheck
		actualizarBotonesAim()
	end)
	for nombre, boton in pairs(botonesParte) do
		boton.MouseButton1Click:Connect(function()
			parteAim = nombre
			actualizarBotonesAim()
		end)
	end

	actualizarBotonesAim()

	-- ===== Lógica =====

	local function esMismoEquipo(j)
		-- Sin equipos (neutrales) no se filtra a nadie.
		if player.Team == nil or j.Team == nil then return false end
		return j.Team == player.Team
	end

	-- true si no hay nada sólido entre tu cámara y la parte
	local function esVisible(camara, parte, personajeObjetivo)
		local excluir = { personajeObjetivo }
		if player.Character then
			table.insert(excluir, player.Character)
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = excluir
		params.IgnoreWater = true

		local origen = camara.CFrame.Position
		return workspace:Raycast(origen, parte.Position - origen, params) == nil
	end

	-- La parte válida más cercana al centro del círculo (o nil)
	local function buscarObjetivoAim(camara)
		local centro = UserInputService:GetMouseLocation()
		local nombres = PARTES_AIM[parteAim]
		local mejorParte, mejorDist = nil, radioAimbot

		for _, j in ipairs(Players:GetPlayers()) do
			local personaje = j.Character
			if j ~= player and personaje and not (teamCheck and esMismoEquipo(j)) then
				local hum = personaje:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					for _, nombre in ipairs(nombres) do
						local parte = personaje:FindFirstChild(nombre)
						if parte and parte:IsA("BasePart") then
							local pos, enPantalla = camara:WorldToViewportPoint(parte.Position)
							if enPantalla then
								local d = (Vector2.new(pos.X, pos.Y) - centro).Magnitude
								-- El raycast (más caro) solo se hace si mejora al mejor actual
								if d <= mejorDist and (not wallCheck or esVisible(camara, parte, personaje)) then
									mejorParte, mejorDist = parte, d
								end
							end
						end
					end
				end
			end
		end

		return mejorParte
	end

	RunService:BindToRenderStep("JerryAimbot", Enum.RenderPriority.Camera.Value + 1, function()
		if not aimbotActivo then return end

		local camara = workspace.CurrentCamera
		if not camara then return end

		-- El círculo sigue al ratón (o al centro si el ratón está bloqueado)
		local centro = UserInputService:GetMouseLocation()
		circuloAim.Size = UDim2.fromOffset(radioAimbot * 2, radioAimbot * 2)
		circuloAim.Position = UDim2.fromOffset(centro.X, centro.Y)

		if UserInputService:GetFocusedTextBox() then return end

		local objetivo = buscarObjetivoAim(camara)
		if not objetivo then return end

		local cf = camara.CFrame
		local destino = CFrame.lookAt(cf.Position, objetivo.Position)
		camara.CFrame = cf:Lerp(destino, SUAVIZADO_AIM)
	end)
end

--------------------------------------------------------------------
-- ESP — ver a los demás jugadores a través de las paredes
--------------------------------------------------------------------
--[[
	Con el ESP activado, los jugadores elegidos se ven resaltados aunque
	estén detrás de una pared: silueta con relleno translúcido
	(Highlight, siempre encima de todo) y, sobre la cabeza, su nombre
	y la distancia en studs. El color es el de su equipo; si no tiene
	equipo, rojo.

	Dos modos (botones de la tarjeta):
	  * TODOS       = todos los jugadores menos tú.
	  * OTRO TEAM   = solo los que NO son de tu equipo. Si el juego no
	                  usa equipos (o alguno de los dos no tiene), se
	                  considera que son de otro equipo y se ve a todos.
	Si alguien cambia de equipo mientras el ESP está activo, se
	actualiza solo (se revisa cada medio segundo).

	Todo se crea en TU cliente y cuelga del personaje de cada jugador,
	así que desaparece solo cuando ese jugador muere o se va. Los
	objetos se llaman "JerryESP" para que Self Destruct pueda borrarlos.
	Es independiente de tu personaje: sigue activo aunque mueras.
]]
do
	local COLOR_SIN_EQUIPO = Color3.fromRGB(255, 70, 70)
	local INTERVALO_REVISION = 0.5

	local espActivo = false
	local modoEsp = "TODOS"      -- "TODOS" o "OTRO TEAM"
	local esp = {}               -- [Player] = { resaltado, cartel, etiqueta }
	local creando = {}           -- [Player] = true mientras se está creando su ESP

	-- ===== Interfaz: tarjeta en la pestaña VISUAL =====
	local tarjetaEsp = crearTarjeta(paginas.VISUAL, "ESP", "Ve a los jugadores a través de las paredes", 0, 88)

	local botonEsp = crearBoton(tarjetaEsp, "BotonEsp", "DESACTIVADO",
		UDim2.new(0, 8, 0, 34), tamCompleto(22), 13)
	local botonEspTodos = crearBoton(tarjetaEsp, "BotonEspTodos", "TODOS",
		mitadIzq(60), tamMitad(22), 12)
	local botonEspEquipo = crearBoton(tarjetaEsp, "BotonEspOtroTeam", "OTRO TEAM",
		mitadDer(60), tamMitad(22), 12)

	local function actualizarBotonesEsp()
		pintarBoton(botonEsp, espActivo, espActivo and "ACTIVADO" or "DESACTIVADO")
		pintarBoton(botonEspTodos, modoEsp == "TODOS", "TODOS")
		pintarBoton(botonEspEquipo, modoEsp == "OTRO TEAM", "OTRO TEAM")
	end

	-- ===== Lógica =====

	-- ¿Este jugador debe verse según el modo elegido?
	local function debeMostrar(j)
		if j == player then return false end
		if modoEsp == "TODOS" then return true end
		-- OTRO TEAM: sin equipos no se puede distinguir, así que se ve a todos
		if player.Team == nil or j.Team == nil then return true end
		return j.Team ~= player.Team
	end

	local function quitarESP(j)
		local datos = esp[j]
		if not datos then return end
		if datos.resaltado then datos.resaltado:Destroy() end
		if datos.cartel then datos.cartel:Destroy() end
		esp[j] = nil
	end

	local function construirESP(j)
		quitarESP(j)
		local personaje = j.Character
		if not personaje or not personaje.Parent then return end

		-- La cabeza puede tardar un poco en existir al reaparecer
		local cabeza = personaje:WaitForChild("Head", 5)
		if not cabeza or not espActivo or j.Character ~= personaje or not debeMostrar(j) then return end

		quitarESP(j)   -- por si otra llamada creó uno mientras esperábamos

		local color = j.Team and j.TeamColor.Color or COLOR_SIN_EQUIPO

		local resaltado = Instance.new("Highlight")
		resaltado.Name = "JerryESP"
		resaltado.Adornee = personaje
		resaltado.FillColor = color
		resaltado.FillTransparency = 0.6
		resaltado.OutlineColor = BLANCO
		resaltado.OutlineTransparency = 0
		resaltado.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		resaltado.Parent = personaje

		local cartel = Instance.new("BillboardGui")
		cartel.Name = "JerryESP"
		cartel.Adornee = cabeza
		cartel.AlwaysOnTop = true
		cartel.Size = UDim2.fromOffset(140, 34)
		cartel.StudsOffset = Vector3.new(0, 2.5, 0)
		cartel.Parent = personaje

		local etiqueta = Instance.new("TextLabel")
		etiqueta.Size = UDim2.new(1, 0, 1, 0)
		etiqueta.BackgroundTransparency = 1
		etiqueta.Font = FUENTE
		etiqueta.TextSize = 14
		etiqueta.TextColor3 = color
		etiqueta.TextStrokeTransparency = 0.3
		etiqueta.TextStrokeColor3 = NEGRO_BORDE
		etiqueta.Text = j.DisplayName
		etiqueta.Parent = cartel

		esp[j] = { resaltado = resaltado, cartel = cartel, etiqueta = etiqueta }
	end

	-- Envoltorio: evita crear dos a la vez para el mismo jugador
	local function crearESP(j)
		if creando[j] then return end
		creando[j] = true
		local ok = pcall(construirESP, j)
		creando[j] = nil
		if not ok then
			quitarESP(j)
		end
	end

	-- Deja el ESP tal como pide el modo actual: crea los que faltan y
	-- quita los que ya no deben verse.
	local function sincronizarESP()
		for _, j in ipairs(Players:GetPlayers()) do
			if j ~= player then
				if debeMostrar(j) then
					if not esp[j] and j.Character then
						task.spawn(crearESP, j)
					end
				else
					quitarESP(j)
				end
			end
		end
	end

	local function establecerESP(estado)
		espActivo = estado
		actualizarBotonesEsp()

		if estado then
			sincronizarESP()
		else
			for j in pairs(esp) do
				quitarESP(j)
			end
		end
	end

	local function establecerModoEsp(modo)
		if modo == modoEsp then return end
		modoEsp = modo
		actualizarBotonesEsp()
		if espActivo then
			sincronizarESP()
		end
	end

	botonEsp.MouseButton1Click:Connect(function()
		establecerESP(not espActivo)
	end)
	botonEspTodos.MouseButton1Click:Connect(function()
		establecerModoEsp("TODOS")
	end)
	botonEspEquipo.MouseButton1Click:Connect(function()
		establecerModoEsp("OTRO TEAM")
	end)

	actualizarBotonesEsp()

	-- Jugadores que entran, reaparecen o se van mientras el ESP está activo
	local function vigilarJugador(j)
		if j == player then return end
		conectar(j.CharacterAdded, function()
			if espActivo and debeMostrar(j) then
				task.spawn(crearESP, j)
			end
		end)
	end

	for _, j in ipairs(Players:GetPlayers()) do
		vigilarJugador(j)
	end
	conectar(Players.PlayerAdded, vigilarJugador)
	conectar(Players.PlayerRemoving, function(j)
		quitarESP(j)
		creando[j] = nil
	end)

	-- Nombre + distancia cada frame; y cada medio segundo se revisa si
	-- alguien cambió de equipo (o tú) para ajustar quién se ve.
	local ultimaRevision = 0
	conectar(RunService.RenderStepped, function()
		if not espActivo then return end

		local ahora = os.clock()
		if ahora - ultimaRevision >= INTERVALO_REVISION then
			ultimaRevision = ahora
			sincronizarESP()
		end

		local miRaiz = root
		for j, datos in pairs(esp) do
			local personaje = j.Character
			local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
			if raiz and miRaiz and miRaiz.Parent then
				local dist = (raiz.Position - miRaiz.Position).Magnitude
				datos.etiqueta.Text = j.DisplayName .. "\n" .. math.floor(dist + 0.5) .. " studs"
			end
		end
	end)
end

--------------------------------------------------------------------
-- VUELO  (y preparación general del personaje)
--------------------------------------------------------------------

local function prepararPersonaje(character)
	volando = false
	humanoid = character:WaitForChild("Humanoid")
	root = character:WaitForChild("HumanoidRootPart")
	if destruido then return end

	-- Noclip, giro y fling no se mantienen entre respawns.
	personajeActual = character
	noclipActivo = false
	actualizarBotonNoclip()
	giroActivo = false
	actualizarBotonGiro()
	objetivoFling = nil
	faseFling = nil
	camaraSobreObjetivo = false
	posAntesRafaga = nil
	picoPendiente = false
	volabaAntesDeFling = false
	dirigidoActivo = false
	jugadorDirigido = nil
	actualizarBotonDirigido()
	humanoid.AutoRotate = true

	attachment = Instance.new("Attachment")
	attachment.Name = "FlyAttachment"
	attachment.Parent = root

	linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Attachment0 = attachment
	linearVelocity.MaxForce = math.huge
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VectorVelocity = Vector3.zero
	linearVelocity.Enabled = false
	linearVelocity.Parent = root

	alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Attachment0 = attachment
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.RigidityEnabled = true
	alignOrientation.Enabled = false
	alignOrientation.Parent = root

	angularVelocity = Instance.new("AngularVelocity")
	angularVelocity.Attachment0 = attachment
	angularVelocity.MaxTorque = math.huge
	angularVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	angularVelocity.AngularVelocity = Vector3.zero
	angularVelocity.Enabled = false
	angularVelocity.Parent = root

	actualizarBotonVuelo()
end

establecerVuelo = function(estado)
	if not root or not humanoid then return end

	-- Si se enciende el vuelo en mitad de un lanzamiento, se cancela
	-- (te devuelve a tu sitio) para que no peleen por tu personaje.
	if estado and faseFling and cancelarFlingDirigido then
		cancelarFlingDirigido()
	end

	volando = estado

	humanoid.PlatformStand = estado
	linearVelocity.Enabled = estado
	alignOrientation.Enabled = estado and not giroActivo

	actualizarBotonVuelo()

	if not estado then
		linearVelocity.VectorVelocity = Vector3.zero
	end
end

--------------------------------------------------------------------
-- SELF DESTRUCT — elimina todo lo que creó el script
--------------------------------------------------------------------

local EMOJI_PARTICULA = "🥬"
local NUM_PARTICULAS = 40
local DURACION_PARTICULAS = 1.6

local function lanzarLechugas(x, y, ancho, alto)
	local aleatorio = Random.new()

	local capa = Instance.new("ScreenGui")
	capa.Name = "JerryScriptParticulas"
	capa.ResetOnSpawn = false
	capa.DisplayOrder = 1000
	capa.Parent = player:WaitForChild("PlayerGui")
	Debris:AddItem(capa, DURACION_PARTICULAS + 1)

	local cx, cy = x + ancho / 2, y + alto / 2

	for _ = 1, NUM_PARTICULAS do
		local px = x + aleatorio:NextNumber(0, ancho)
		local py = y + aleatorio:NextNumber(0, alto)
		local tamano = aleatorio:NextInteger(20, 38)

		local p = Instance.new("TextLabel")
		p.Size = UDim2.fromOffset(tamano + 12, tamano + 12)
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Position = UDim2.fromOffset(px, py)
		p.Rotation = aleatorio:NextNumber(-180, 180)
		p.BackgroundTransparency = 1
		p.Font = Enum.Font.GothamBold
		p.TextSize = tamano
		p.Text = EMOJI_PARTICULA
		p.Parent = capa

		local angulo = math.atan2(py - cy, px - cx) + aleatorio:NextNumber(-0.6, 0.6)
		local distancia = aleatorio:NextNumber(120, 340)
		local caida = aleatorio:NextNumber(60, 200)
		local duracion = aleatorio:NextNumber(0.9, DURACION_PARTICULAS)

		TweenService:Create(
			p,
			TweenInfo.new(duracion, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = UDim2.fromOffset(
					px + math.cos(angulo) * distancia,
					py + math.sin(angulo) * distancia + caida
				),
				Rotation = p.Rotation + aleatorio:NextNumber(-540, 540),
			}
		):Play()

		TweenService:Create(
			p,
			TweenInfo.new(duracion * 0.6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, duracion * 0.4),
			{ TextTransparency = 1 }
		):Play()
	end

	return capa
end

local function autodestruir()
	if destruido then return end
	destruido = true

	-- 0) Quitar el paso de render del aimbot
	pcall(function()
		RunService:UnbindFromRenderStep("JerryAimbot")
	end)

	-- 0b) Borrar los resaltados / carteles del ESP de los demás personajes
	for _, j in ipairs(Players:GetPlayers()) do
		if j.Character then
			for _, d in ipairs(j.Character:GetChildren()) do
				if d.Name == "JerryESP" then
					d:Destroy()
				end
			end
		end
	end

	-- 0c) Si hay un lanzamiento en curso, se cancela (te devuelve a tu sitio
	--     y la cámara vuelve a ti) ANTES de cortar las conexiones.
	if cancelarFlingDirigido then
		pcall(cancelarFlingDirigido)
	end

	-- 1) Cortar todas las conexiones
	for _, c in ipairs(conexiones) do
		c:Disconnect()
	end
	table.clear(conexiones)

	-- 2) Restaurar iluminación y personaje
	establecerFullbright(false)

	if noclipActivo and personajeActual and personajeActual.Parent then
		aplicarColisiones(personajeActual, false)
	end
	noclipActivo = false
	volando = false
	giroActivo = false
	dirigidoActivo = false
	jugadorDirigido = nil
	objetivoFling = nil
	faseFling = nil
	posAntesRafaga = nil
	picoPendiente = false

	if humanoid and humanoid.Parent then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
	end
	if root and root.Parent then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end

	-- 3) Borrar los objetos puestos en el personaje
	if linearVelocity then linearVelocity:Destroy() end
	if alignOrientation then alignOrientation:Destroy() end
	if angularVelocity then angularVelocity:Destroy() end
	if attachment then attachment:Destroy() end

	-- 4) Borrar la interfaz (medimos "contenedor", que no cambia con la animación)
	local pos, tam = contenedor.AbsolutePosition, contenedor.AbsoluteSize
	gui:Destroy()

	-- 5) Explosión de lechugas
	local capa = lanzarLechugas(pos.X, pos.Y, tam.X, tam.Y)
	task.wait(DURACION_PARTICULAS + 0.2)
	capa:Destroy()

	-- 6) Borrar el propio script
	pcall(function()
		script:Destroy()
	end)
end

botonDestruir.MouseButton1Click:Connect(autodestruir)

prepararPersonaje(player.Character or player.CharacterAdded:Wait())
conectar(player.CharacterAdded, prepararPersonaje)

conectar(UserInputService.InputBegan, function(input, procesado)
	-- Solo se ignora si de verdad estás escribiendo en una caja de texto.
	if UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == TECLA then
		establecerVuelo(not volando)
	elseif input.KeyCode == TECLA_GUI then
		alternarPanel()
	end
end)

conectar(RunService.RenderStepped, function()
	if not volando or not root or not linearVelocity or not alignOrientation then return end

	-- La cámara se lee en cada frame (el juego puede sustituirla al reaparecer).
	local camara = workspace.CurrentCamera
	if not camara then return end

	local camCF = camara.CFrame
	local direccion = Vector3.zero

	-- Si estás escribiendo el nombre del jugador (o en el chat), las teclas son letras.
	if not UserInputService:GetFocusedTextBox() then
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then direccion += camCF.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then direccion -= camCF.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then direccion += camCF.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then direccion -= camCF.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then direccion += Vector3.new(0, 1, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then direccion -= Vector3.new(0, 1, 0) end
	end

	if direccion.Magnitude > 0 then
		direccion = direccion.Unit
	end

	linearVelocity.VectorVelocity = direccion * velocidad

	if not giroActivo then
		-- El personaje mira exactamente hacia donde apunta la cámara
		-- (también arriba y abajo), usando su misma rotación.
		alignOrientation.CFrame = camCF.Rotation
	end
end)
