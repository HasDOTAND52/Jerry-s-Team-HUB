--[[
	FlyToggle.lua  —  LocalScript
	Ubicación: StarterPlayer > StarterPlayerScripts

	F  = activar / desactivar el vuelo (o el botón VUELO del panel)
	H  = mostrar / ocultar el panel "Jerry's Script V.1" (o el botón de
	     la lechuga girando en medio de la pantalla; se puede arrastrar,
	     pensado para móvil)
	Botón "NOCLIP"      = atravesar paredes/suelo
	Botón "GMABER1090"  = el personaje gira sin parar (con medidor)
	Botón "FULLBRIGHT"  = quita la oscuridad del mapa (al apagarlo se
	                      restaura la iluminación original)
	Módulo "AIMBOT" (tercera columna) = al activarlo, la cámara apunta
	                      sola (sin pulsar nada) al jugador más cercano
	                      al centro del círculo verde. Opciones: WALL CHECK, TEAM CHECK,
	                      tamaño del círculo y parte a la que apuntar
	                      (cabeza, torso, brazos o piernas).
	Módulo "ESP" (tercera columna, abajo) = ves a los demás jugadores a
	                      través de las paredes: silueta resaltada con
	                      su nombre y la distancia. Modos: TODOS, o solo
	                      los del OTRO TEAM.
	Módulo "FLING A JUGADOR" = escribes el nombre (o parte del nombre /
	                      apodo) de UN jugador y pulsas LANZAR (o Enter):
	                      te teletransportas a él, lo lanzas por los
	                      aires y vuelves a tu posición original (y
	                      recuperas el vuelo si lo tenías).
	Cartel "Self Destruct" = elimina TODO, con una explosión de lechugas 🥬
	Arrastra la BARRA VERDE de arriba para mover el panel.

	W A S D = moverse en la dirección de la cámara (mientras vuelas)
	Espacio = subir      Shift = bajar

	----------------------------------------------------------------
	CAMBIOS DE ESTA VERSIÓN

	0) NUEVO: AIMBOT con Wall Check, Team Check, tamaño del círculo y
	   selector de parte (cabeza / torso / brazos / piernas). El panel
	   pasa a tres columnas (835 px de ancho).

	1) Panel más ancho, en DOS COLUMNAS, y con todo más compacto: ahora
	   cabe todo sin salirse de la pantalla.

	2) Se ha quitado el FLING antiguo (el de cercanía). Solo queda
	   "FLING A JUGADOR", que ahora incluye el medidor de fuerza.

	3) El lanzamiento sale MUCHO antes:
	   - Empieza en el mismo instante en que pulsas LANZAR (antes
	     esperaba al siguiente Heartbeat).
	   - El empujón se aplica dos veces por frame (antes de la física
	     y después), en vez de una.
	   - Termina en cuanto el objetivo sale despedido (se detecta por
	     distancia recorrida), sin esperar a que se acabe el tiempo.
	   - El tiempo máximo baja de 0.8 s a 0.6 s.
	   - Se quitó la vibración (jitter) que solo añadía retraso.
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
local DURACION_DIRIGIDO = 0.6  -- fling: tiempo MÁXIMO pegado al objetivo (s)
local DIST_LANZADO = 50        -- fling: si el objetivo se aleja tanto (studs), se da por lanzado
local GIRO_FLING_MAX = 150     -- fling: tope de velocidad angular (rad/s)

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
local GRIS_TENUE = Color3.fromRGB(140, 150, 140)
local NEGRO_BORDE = Color3.fromRGB(20, 20, 20)
local VERDE_BARRA = Color3.fromRGB(0, 158, 61)
local GRIS_TRACK = Color3.fromRGB(210, 210, 210)

local FUENTE = Enum.Font.SourceSansBold

--------------------------------------------------------------------
-- INTERFAZ
--------------------------------------------------------------------

-- Medidas del panel (tres columnas)
local ANCHO_PANEL = 835
local ALTO_PANEL = 430
local ANCHO_COL = 265
local X_COL1 = 10
local X_COL2 = 285

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
header.Size = UDim2.new(1, 0, 0, 42)
header.Position = UDim2.new(0, 0, 0, 0)
header.BackgroundColor3 = VERDE_HEADER
header.BorderSizePixel = 0
header.Parent = panel

local headerLineaInferior = Instance.new("Frame")
headerLineaInferior.Size = UDim2.new(1, 0, 0, 3)
headerLineaInferior.Position = UDim2.new(0, 0, 1, -3)
headerLineaInferior.BackgroundColor3 = VERDE_OSCURO
headerLineaInferior.BorderSizePixel = 0
headerLineaInferior.Parent = header

-- ===== Logo =====
local logoMarco = Instance.new("Frame")
logoMarco.Name = "LogoMarco"
logoMarco.Size = UDim2.new(0, 48, 0, 48)
logoMarco.Position = UDim2.new(0, -9, 0, -9)
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
nombreHub.Size = UDim2.new(0, 160, 1, 0)
nombreHub.Position = UDim2.new(0, 44, 0, 0)
nombreHub.BackgroundTransparency = 1
nombreHub.Font = FUENTE
nombreHub.TextSize = 17
nombreHub.TextXAlignment = Enum.TextXAlignment.Left
nombreHub.TextColor3 = BLANCO
nombreHub.Text = "Jerry's Script V.1"
nombreHub.Parent = header

-- ===== Cartel "Self Destruct" =====
local ROJO_CARTEL = Color3.fromRGB(200, 40, 40)
local ROJO_HOVER = Color3.fromRGB(235, 70, 70)

local botonDestruir = Instance.new("TextButton")
botonDestruir.Name = "BotonSelfDestruct"
botonDestruir.Size = UDim2.new(0, 78, 0, 22)
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
-- Tarjetas y medidores
--------------------------------------------------------------------

local function crearTarjeta(nombre, posX, posY, alto)
	local tarjeta = Instance.new("Frame")
	tarjeta.Name = "Tarjeta" .. nombre
	tarjeta.Size = UDim2.new(0, ANCHO_COL, 0, alto)
	tarjeta.Position = UDim2.new(0, posX, 0, posY)
	tarjeta.BackgroundColor3 = VERDE_SUAVE
	tarjeta.BorderSizePixel = 2
	tarjeta.BorderColor3 = NEGRO_BORDE
	tarjeta.Parent = panel

	local miniHeader = Instance.new("Frame")
	miniHeader.Name = "MiniHeader"
	miniHeader.Size = UDim2.new(1, 0, 0, 20)
	miniHeader.BackgroundColor3 = VERDE_OSCURO
	miniHeader.BorderSizePixel = 0
	miniHeader.Parent = tarjeta

	local miniTexto = Instance.new("TextLabel")
	miniTexto.Size = UDim2.new(1, -10, 1, 0)
	miniTexto.Position = UDim2.new(0, 8, 0, 0)
	miniTexto.BackgroundTransparency = 1
	miniTexto.Font = FUENTE
	miniTexto.TextSize = 12
	miniTexto.TextXAlignment = Enum.TextXAlignment.Left
	miniTexto.TextColor3 = BLANCO
	miniTexto.Text = nombre
	miniTexto.Parent = miniHeader

	return tarjeta
end

local function crearMedidor(tarjeta, posY, minimo, maximo, inicial, alCambiar, textos)
	local etiquetaVel = Instance.new("TextLabel")
	etiquetaVel.Size = UDim2.new(1, -80, 0, 16)
	etiquetaVel.Position = UDim2.new(0, 8, 0, posY)
	etiquetaVel.BackgroundTransparency = 1
	etiquetaVel.Font = FUENTE
	etiquetaVel.TextSize = 12
	etiquetaVel.TextXAlignment = Enum.TextXAlignment.Left
	etiquetaVel.TextColor3 = GRIS_TEXTO
	etiquetaVel.Text = (textos and textos.titulo) or "Velocidad"
	etiquetaVel.Parent = tarjeta

	local valor = Instance.new("TextLabel")
	valor.Size = UDim2.new(0, 60, 0, 16)
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
	track.Position = UDim2.new(0, 8, 0, posY + 20)
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
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(0, 0, 0.5, 0)
	knob.BackgroundColor3 = BLANCO
	knob.BorderSizePixel = 2
	knob.BorderColor3 = NEGRO_BORDE
	knob.ZIndex = 3
	knob.Parent = track

	local labelIzq = Instance.new("TextLabel")
	labelIzq.Size = UDim2.new(0, 90, 0, 14)
	labelIzq.Position = UDim2.new(0, 8, 0, posY + 34)
	labelIzq.BackgroundTransparency = 1
	labelIzq.Font = FUENTE
	labelIzq.TextSize = 10
	labelIzq.TextColor3 = GRIS_TENUE
	labelIzq.TextXAlignment = Enum.TextXAlignment.Left
	labelIzq.Text = (textos and textos.izq) or "Más lento"
	labelIzq.Parent = tarjeta

	local labelDer = Instance.new("TextLabel")
	labelDer.Size = UDim2.new(0, 90, 0, 14)
	labelDer.AnchorPoint = Vector2.new(1, 0)
	labelDer.Position = UDim2.new(1, -8, 0, posY + 34)
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
-- COLUMNA IZQUIERDA: VUELO, NOCLIP, FULLBRIGHT
--------------------------------------------------------------------

-- Tarjeta VUELO
local tarjetaVuelo = crearTarjeta("VUELO", X_COL1, 50, 118)

-- Botón de vuelo: hace lo mismo que la tecla F y muestra el estado
local subEstado = Instance.new("TextButton")
subEstado.Name = "BotonVuelo"
subEstado.Size = UDim2.new(1, -16, 0, 20)
subEstado.Position = UDim2.new(0, 8, 0, 24)
subEstado.BackgroundColor3 = BLANCO
subEstado.BorderSizePixel = 2
subEstado.BorderColor3 = NEGRO_BORDE
subEstado.AutoButtonColor = false
subEstado.Selectable = false
subEstado.Font = FUENTE
subEstado.TextSize = 13
subEstado.TextColor3 = GRIS_TEXTO
subEstado.Text = "VUELO:  DESACTIVADO  (F)"
subEstado.Parent = tarjetaVuelo

local function actualizarBotonVuelo()
	if volando then
		subEstado.Text = "VUELO:  ACTIVADO  (F)"
		subEstado.BackgroundColor3 = VERDE_HEADER
		subEstado.TextColor3 = BLANCO
	else
		subEstado.Text = "VUELO:  DESACTIVADO  (F)"
		subEstado.BackgroundColor3 = BLANCO
		subEstado.TextColor3 = GRIS_TEXTO
	end
end

subEstado.MouseButton1Click:Connect(function()
	establecerVuelo(not volando)
end)

local medidorVuelo = crearMedidor(tarjetaVuelo, 46, VEL_MIN, VEL_MAX, velocidad, function(nuevoValor)
	velocidad = nuevoValor
end)

-- Tarjeta NOCLIP
local tarjetaNoclip = crearTarjeta("NOCLIP", X_COL1, 174, 60)

local botonNoclip = Instance.new("TextButton")
botonNoclip.Name = "BotonNoclip"
botonNoclip.Size = UDim2.new(1, -16, 0, 26)
botonNoclip.Position = UDim2.new(0, 8, 0, 26)
botonNoclip.BackgroundColor3 = BLANCO
botonNoclip.BorderSizePixel = 2
botonNoclip.BorderColor3 = NEGRO_BORDE
botonNoclip.AutoButtonColor = false
botonNoclip.Font = FUENTE
botonNoclip.TextSize = 14
botonNoclip.TextColor3 = GRIS_TEXTO
botonNoclip.Text = "NOCLIP:  DESACTIVADO"
botonNoclip.Parent = tarjetaNoclip

-- Tarjeta FULLBRIGHT
local tarjetaFullbright = crearTarjeta("FULLBRIGHT", X_COL1, 240, 60)

local botonFullbright = Instance.new("TextButton")
botonFullbright.Name = "BotonFullbright"
botonFullbright.Size = UDim2.new(1, -16, 0, 26)
botonFullbright.Position = UDim2.new(0, 8, 0, 26)
botonFullbright.BackgroundColor3 = BLANCO
botonFullbright.BorderSizePixel = 2
botonFullbright.BorderColor3 = NEGRO_BORDE
botonFullbright.AutoButtonColor = false
botonFullbright.Font = FUENTE
botonFullbright.TextSize = 14
botonFullbright.TextColor3 = GRIS_TEXTO
botonFullbright.Text = "FULLBRIGHT:  DESACTIVADO"
botonFullbright.Parent = tarjetaFullbright

--------------------------------------------------------------------
-- COLUMNA DERECHA: GMABER1090 y FLING A JUGADOR
--------------------------------------------------------------------

-- Tarjeta GMABER1090
local tarjetaGiro = crearTarjeta("GMABER1090", X_COL2, 50, 110)

local botonGiro = Instance.new("TextButton")
botonGiro.Name = "BotonGiro"
botonGiro.Size = UDim2.new(1, -16, 0, 28)
botonGiro.Position = UDim2.new(0, 8, 0, 26)
botonGiro.BackgroundColor3 = BLANCO
botonGiro.BorderSizePixel = 2
botonGiro.BorderColor3 = NEGRO_BORDE
botonGiro.AutoButtonColor = false
botonGiro.Font = FUENTE
botonGiro.TextSize = 13
botonGiro.TextColor3 = GRIS_TEXTO
botonGiro.Text = "GIRO:  DESACTIVADO"
botonGiro.Parent = tarjetaGiro

local medidorGiro = crearMedidor(tarjetaGiro, 58, GIRO_MIN, GIRO_MAX, velocidadGiro, function(nuevoValor)
	velocidadGiro = nuevoValor
	if angularVelocity and angularVelocity.Enabled then
		angularVelocity.AngularVelocity = Vector3.new(0, math.rad(velocidadGiro), 0)
	end
end)

-- Tarjeta FLING A JUGADOR (nombre + botón + medidor de fuerza)
local tarjetaDirigido = crearTarjeta("FLING A JUGADOR", X_COL2, 166, 134)

local cajaNombre = Instance.new("TextBox")
cajaNombre.Name = "CajaNombreFling"
cajaNombre.Size = UDim2.new(1, -110, 0, 26)
cajaNombre.Position = UDim2.new(0, 8, 0, 26)
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

local botonDirigido = Instance.new("TextButton")
botonDirigido.Name = "BotonFlingDirigido"
botonDirigido.Size = UDim2.new(0, 90, 0, 26)
botonDirigido.AnchorPoint = Vector2.new(1, 0)
botonDirigido.Position = UDim2.new(1, -8, 0, 26)
botonDirigido.BackgroundColor3 = BLANCO
botonDirigido.BorderSizePixel = 2
botonDirigido.BorderColor3 = NEGRO_BORDE
botonDirigido.AutoButtonColor = false
botonDirigido.Font = FUENTE
botonDirigido.TextSize = 13
botonDirigido.TextColor3 = GRIS_TEXTO
botonDirigido.Text = "LANZAR"
botonDirigido.Parent = tarjetaDirigido

local medidorFling = crearMedidor(tarjetaDirigido, 58, FUERZA_MIN, FUERZA_MAX, fuerzaFling, function(nuevoValor)
	fuerzaFling = nuevoValor
end, { titulo = "Fuerza", izq = "Más suave", der = "Más fuerte" })

local estadoDirigido = Instance.new("TextLabel")
estadoDirigido.Name = "EstadoDirigido"
estadoDirigido.Size = UDim2.new(1, -16, 0, 14)
estadoDirigido.Position = UDim2.new(0, 8, 0, 112)
estadoDirigido.BackgroundTransparency = 1
estadoDirigido.Font = FUENTE
estadoDirigido.TextSize = 11
estadoDirigido.TextXAlignment = Enum.TextXAlignment.Left
estadoDirigido.TextTruncate = Enum.TextTruncate.AtEnd
estadoDirigido.TextColor3 = GRIS_TENUE
estadoDirigido.Text = ""
estadoDirigido.Parent = tarjetaDirigido

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
pie.Position = UDim2.new(0, 10, 1, -22)
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
firma.Position = UDim2.new(1, -8, 1, -4)
firma.BackgroundTransparency = 1
firma.Font = FUENTE
firma.TextSize = 9
firma.TextXAlignment = Enum.TextXAlignment.Right
firma.TextColor3 = GRIS_TENUE
firma.TextTransparency = 0.15
firma.Text = "By: Has.&52"
firma.Parent = panel

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
	botonLechuga.Size = UDim2.new(0, 56, 0, 56)
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
	if noclipActivo then
		botonNoclip.Text = "NOCLIP:  ACTIVADO"
		botonNoclip.BackgroundColor3 = VERDE_HEADER
		botonNoclip.TextColor3 = BLANCO
	else
		botonNoclip.Text = "NOCLIP:  DESACTIVADO"
		botonNoclip.BackgroundColor3 = BLANCO
		botonNoclip.TextColor3 = GRIS_TEXTO
	end
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
	if giroActivo then
		botonGiro.Text = "GIRO:  ACTIVADO"
		botonGiro.BackgroundColor3 = VERDE_HEADER
		botonGiro.TextColor3 = BLANCO
	else
		botonGiro.Text = "GIRO:  DESACTIVADO"
		botonGiro.BackgroundColor3 = BLANCO
		botonGiro.TextColor3 = GRIS_TEXTO
	end
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
	if fullbrightActivo then
		botonFullbright.Text = "FULLBRIGHT:  ACTIVADO"
		botonFullbright.BackgroundColor3 = VERDE_HEADER
		botonFullbright.TextColor3 = BLANCO
	else
		botonFullbright.Text = "FULLBRIGHT:  DESACTIVADO"
		botonFullbright.BackgroundColor3 = BLANCO
		botonFullbright.TextColor3 = GRIS_TEXTO
	end
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
	Flujo (todo pensado para que salga lo antes posible):

	  1) Pulsas LANZAR (o Enter en la caja): el enganche ocurre en ESE
	     mismo instante, sin esperar al siguiente frame.
	  2) Cada frame te pegas al objetivo y le aplicas el empujón dos
	     veces: en Stepped (antes de la física) y en Heartbeat
	     (después). En RenderStepped se restaura tu velocidad real
	     para que nunca quede un pico colgado.
	  3) En cuanto el objetivo se ha alejado DIST_LANZADO studs, o se
	     acaba DURACION_DIRIGIDO, termina: vuelves a tu posición y
	     recuperas el vuelo si lo tenías.

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
local inicioRafaga = 0
local finRafaga = 0
local posInicioObjetivo = Vector3.zero
local posAntesRafaga = nil      -- dónde estabas antes de pegarte

local function mostrarEstadoDirigido(texto, esError)
	estadoDirigido.Text = texto
	estadoDirigido.TextColor3 = esError and ROJO_CARTEL or GRIS_TENUE
end

local function actualizarBotonDirigido()
	if dirigidoActivo then
		botonDirigido.Text = "LANZANDO..."
		botonDirigido.BackgroundColor3 = VERDE_HEADER
		botonDirigido.TextColor3 = BLANCO
	else
		botonDirigido.Text = "LANZAR"
		botonDirigido.BackgroundColor3 = BLANCO
		botonDirigido.TextColor3 = GRIS_TEXTO
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

-- Termina la ráfaga: te devuelve a tu sitio, restaura velocidades y
-- recupera el vuelo si lo tenías encendido antes.
local function terminarRafaga()
	if objetivoFling and posAntesRafaga and personajeActual and personajeActual.Parent then
		personajeActual:PivotTo(posAntesRafaga)
	end
	objetivoFling = nil
	posAntesRafaga = nil

	if root and root.Parent then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
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
	actualizarBotonDirigido()
	if mensaje then
		mostrarEstadoDirigido(mensaje, esError)
	end
end

cancelarFlingDirigido = function()
	if not dirigidoActivo then return end
	terminarRafaga()
	finalizarFlingDirigido("Cancelado", false)
end

-- Te pega al objetivo y guarda lo necesario para volver. Devuelve true si engancha.
local function engancharAhora()
	local raizObj = raizDeJugador(jugadorDirigido)
	if not raizObj then
		finalizarFlingDirigido("El jugador ya no está o no tiene personaje", true)
		return false
	end

	-- Guardamos tu velocidad real UNA sola vez, antes de tocar nada.
	velGuardada = root.AssemblyLinearVelocity
	angGuardada = root.AssemblyAngularVelocity
	posAntesRafaga = root.CFrame

	if volando then
		volabaAntesDeFling = true
		establecerVuelo(false)
	end

	objetivoFling = raizObj
	posInicioObjetivo = raizObj.Position
	inicioRafaga = os.clock()
	finRafaga = inicioRafaga + DURACION_DIRIGIDO
	return true
end

-- Te pega al objetivo y aplica el empujón (se llama en Stepped y en Heartbeat)
local function aplicarPico()
	if not objetivoFling or not objetivoFling.Parent or not root or not root.Parent or not personajeActual then
		return
	end

	personajeActual:PivotTo(CFrame.new(objetivoFling.Position) * (root.CFrame - root.CFrame.Position))

	local mira = root.CFrame.LookVector
	local plano = Vector3.new(mira.X, 0, mira.Z)
	local dir = plano.Magnitude > 0.01 and plano.Unit or Vector3.new(0, 0, -1)

	root.AssemblyLinearVelocity = dir * fuerzaFling + Vector3.new(0, fuerzaFling, 0)
	root.AssemblyAngularVelocity = Vector3.new(GIRO_FLING_MAX, GIRO_FLING_MAX, GIRO_FLING_MAX)
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

	-- Enganche y primer empujón INMEDIATOS (sin esperar al siguiente frame)
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

-- Heartbeat (después de la física): segundo empujón del frame y control del final.
conectar(RunService.Heartbeat, function()
	if not dirigidoActivo or not root or not root.Parent or not personajeActual then return end

	if not objetivoFling then
		-- Por si el enganche inmediato no llegó a producirse
		if not engancharAhora() then return end
	end

	local ahora = os.clock()
	local lanzado = (ahora - inicioRafaga) > 0.08
		and objetivoFling.Parent
		and (objetivoFling.Position - posInicioObjetivo).Magnitude >= DIST_LANZADO

	if ahora >= finRafaga or not objetivoFling.Parent or lanzado then
		terminarRafaga()
		finalizarFlingDirigido(lanzado and "Listo: lanzado" or "Listo", false)
		return
	end

	aplicarPico()
end)

-- RenderStepped (antes de simular): se restaura tu velocidad real.
conectar(RunService.RenderStepped, function()
	restaurarPico()
end)

-- Stepped (justo antes de la física): primer empujón del frame, para
-- que la simulación ya arranque con el contacto y la velocidad puestos.
conectar(RunService.Stepped, function()
	if dirigidoActivo and objetivoFling then
		aplicarPico()
	end
end)

--------------------------------------------------------------------
-- AIMBOT — tarjeta en la tercera columna + lógica de apuntado
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
	local X_COL3 = 560

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
	local tarjetaAimbot = crearTarjeta("AIMBOT", X_COL3, 50, 250)

	local function crearBotonAim(nombre, texto, ancho, x, y, alto)
		local b = Instance.new("TextButton")
		b.Name = nombre
		b.Size = UDim2.new(0, ancho, 0, alto)
		b.Position = UDim2.new(0, x, 0, y)
		b.BackgroundColor3 = BLANCO
		b.BorderSizePixel = 2
		b.BorderColor3 = NEGRO_BORDE
		b.AutoButtonColor = false
		b.Font = FUENTE
		b.TextSize = 13
		b.TextColor3 = GRIS_TEXTO
		b.Text = texto
		b.Selectable = false
		b.Parent = tarjetaAimbot
		return b
	end

	local botonAimbot = crearBotonAim("BotonAimbot", "AIMBOT:  DESACTIVADO", 249, 8, 26, 26)
	local botonWallCheck = crearBotonAim("BotonWallCheck", "WALL CHECK: SÍ", 121, 8, 58, 24)
	local botonTeamCheck = crearBotonAim("BotonTeamCheck", "TEAM CHECK: SÍ", 121, 136, 58, 24)

	crearMedidor(tarjetaAimbot, 88, RADIO_AIM_MIN, RADIO_AIM_MAX, radioAimbot, function(nuevoValor)
		radioAimbot = nuevoValor
	end, { titulo = "Tamaño del círculo", izq = "Pequeño", der = "Grande" })

	local etiquetaParte = Instance.new("TextLabel")
	etiquetaParte.Size = UDim2.new(1, -16, 0, 14)
	etiquetaParte.Position = UDim2.new(0, 8, 0, 144)
	etiquetaParte.BackgroundTransparency = 1
	etiquetaParte.Font = FUENTE
	etiquetaParte.TextSize = 12
	etiquetaParte.TextXAlignment = Enum.TextXAlignment.Left
	etiquetaParte.TextColor3 = GRIS_TEXTO
	etiquetaParte.Text = "Apuntar a:"
	etiquetaParte.Parent = tarjetaAimbot

	local botonesParte = {}
	for i, nombre in ipairs(ORDEN_PARTES) do
		local x = (i % 2 == 1) and 8 or 136
		local y = (i <= 2) and 160 or 188
		botonesParte[nombre] = crearBotonAim("BotonParte" .. nombre, nombre, 121, x, y, 24)
	end

	local pista = Instance.new("TextLabel")
	pista.Size = UDim2.new(1, -16, 0, 28)
	pista.Position = UDim2.new(0, 8, 0, 220)
	pista.BackgroundTransparency = 1
	pista.Font = FUENTE
	pista.TextSize = 11
	pista.TextWrapped = true
	pista.TextXAlignment = Enum.TextXAlignment.Left
	pista.TextYAlignment = Enum.TextYAlignment.Top
	pista.TextColor3 = GRIS_TENUE
	pista.Text = "Al activarlo apunta solo, sin pulsar nada."
	pista.Parent = tarjetaAimbot

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

	local function estiloBoton(boton, activo, texto)
		boton.Text = texto
		boton.BackgroundColor3 = activo and VERDE_HEADER or BLANCO
		boton.TextColor3 = activo and BLANCO or GRIS_TEXTO
	end

	local function actualizarBotonesAim()
		estiloBoton(botonAimbot, aimbotActivo, aimbotActivo and "AIMBOT:  ACTIVADO" or "AIMBOT:  DESACTIVADO")
		estiloBoton(botonWallCheck, wallCheck, wallCheck and "WALL CHECK: SÍ" or "WALL CHECK: NO")
		estiloBoton(botonTeamCheck, teamCheck, teamCheck and "TEAM CHECK: SÍ" or "TEAM CHECK: NO")
		for nombre, boton in pairs(botonesParte) do
			estiloBoton(boton, nombre == parteAim, nombre)
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

	-- ===== Interfaz: tarjeta debajo del aimbot (tercera columna) =====
	local tarjetaEsp = crearTarjeta("ESP", 560, 306, 92)

	local function crearBotonEsp(nombre, texto, ancho, x, y, alto, tamanoTexto)
		local b = Instance.new("TextButton")
		b.Name = nombre
		b.Size = UDim2.new(0, ancho, 0, alto)
		b.Position = UDim2.new(0, x, 0, y)
		b.BackgroundColor3 = BLANCO
		b.BorderSizePixel = 2
		b.BorderColor3 = NEGRO_BORDE
		b.AutoButtonColor = false
		b.Selectable = false
		b.Font = FUENTE
		b.TextSize = tamanoTexto
		b.TextColor3 = GRIS_TEXTO
		b.Text = texto
		b.Parent = tarjetaEsp
		return b
	end

	local botonEsp = crearBotonEsp("BotonEsp", "ESP:  DESACTIVADO", 249, 8, 26, 26, 14)
	local botonEspTodos = crearBotonEsp("BotonEspTodos", "TODOS", 121, 8, 58, 24, 13)
	local botonEspEquipo = crearBotonEsp("BotonEspOtroTeam", "OTRO TEAM", 121, 136, 58, 24, 13)

	local function estiloBoton(boton, activo, texto)
		boton.Text = texto
		boton.BackgroundColor3 = activo and VERDE_HEADER or BLANCO
		boton.TextColor3 = activo and BLANCO or GRIS_TEXTO
	end

	local function actualizarBotonesEsp()
		estiloBoton(botonEsp, espActivo, espActivo and "ESP:  ACTIVADO" or "ESP:  DESACTIVADO")
		estiloBoton(botonEspTodos, modoEsp == "TODOS", "TODOS")
		estiloBoton(botonEspEquipo, modoEsp == "OTRO TEAM", "OTRO TEAM")
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

	-- Si se enciende el vuelo en mitad de un lanzamiento, se corta la ráfaga.
	if estado and objetivoFling then
		terminarRafaga()
		if dirigidoActivo then
			finalizarFlingDirigido("Cancelado", false)
		end
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
