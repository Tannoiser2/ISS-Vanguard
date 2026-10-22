## Vassoio 3D dei dadi: i dadi si lanciano davvero (corpi rigidi con la fisica) e il risultato è la faccia
## che resta in alto. Dadi Reparto e Ferita: cubi con le facce dell'immagine del dado del modulo TTS
## (griglia 3×2 nella parte bassa, nello stesso ordine di data/dadi.json); dadi Pericolo: ottaedri con le
## icone di rarità del gioco.
class_name Dadi3D
extends SubViewportContainer

signal fermi

const LATO := 0.95          # spigolo del cubo
const RAGGIO_D8 := 0.74     # distanza dei vertici dell'ottaedro dal centro
const VASSOIO := Vector2(14.0, 5.6)
const COLORI := {"red": Color("b0263a"), "blue": Color("1683c8"), "green": Color("3f9a36")}

var _vp: SubViewport
var _mondo: Node3D
var _corpi: Array = []      # [{"corpo": RigidBody3D, "d": Dictionary, "normali": Array}]
var _fisica: PhysicsMaterial
static var _tex_d8 := {}    # nome icona -> ImageTexture della faccia del dado Pericolo

func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(0, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.physics_object_picking = false
	add_child(_vp)
	_mondo = Node3D.new()
	_vp.add_child(_mondo)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.05, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.55
	amb.environment = env
	_mondo.add_child(amb)
	var luce := DirectionalLight3D.new()
	luce.rotation = Vector3(deg_to_rad(-62), deg_to_rad(28), 0)
	luce.light_energy = 1.25
	luce.shadow_enabled = true
	_mondo.add_child(luce)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 12.5, 2.6)
	cam.fov = 31
	_mondo.add_child(cam)
	cam.look_at(Vector3(0, 0, 0.2), Vector3.UP)
	_fisica = PhysicsMaterial.new()
	_fisica.bounce = 0.28
	_fisica.friction = 0.75
	_vassoio()

## Il vassoio: fondo di feltro e bordi bassi.
func _vassoio() -> void:
	var fondo := StaticBody3D.new()
	fondo.physics_material_override = _fisica
	var sh := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(VASSOIO.x, 0.4, VASSOIO.y)
	sh.shape = bx
	sh.position.y = -0.2
	fondo.add_child(sh)
	var mi := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(VASSOIO.x, 0.4, VASSOIO.y)
	mi.mesh = pm
	mi.position.y = -0.2
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.06, 0.16, 0.24)
	mt.roughness = 0.95
	mi.material_override = mt
	fondo.add_child(mi)
	_mondo.add_child(fondo)
	var bordo := StandardMaterial3D.new()
	bordo.albedo_color = Color(0.1, 0.28, 0.4)
	bordo.roughness = 0.6
	for lato in [[Vector3(0, 0.6, -VASSOIO.y / 2 - 0.15), Vector3(VASSOIO.x + 0.6, 1.2, 0.3)], [Vector3(0, 0.6, VASSOIO.y / 2 + 0.15), Vector3(VASSOIO.x + 0.6, 1.2, 0.3)],
			[Vector3(-VASSOIO.x / 2 - 0.15, 0.6, 0), Vector3(0.3, 1.2, VASSOIO.y)], [Vector3(VASSOIO.x / 2 + 0.15, 0.6, 0), Vector3(0.3, 1.2, VASSOIO.y)]]:
		var w := StaticBody3D.new()
		w.physics_material_override = _fisica
		w.position = lato[0]
		var cs := CollisionShape3D.new()
		var b2 := BoxShape3D.new()
		b2.size = lato[1] + Vector3(0, 6, 0)
		cs.shape = b2
		cs.position.y = 3
		w.add_child(cs)
		var m2 := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = lato[1] * Vector3(1, 0.35, 1)
		m2.mesh = bm
		m2.position.y = -0.4
		m2.material_override = bordo
		w.add_child(m2)
		_mondo.add_child(w)

## Lancia tutti i dadi (sostituisce quelli già nel vassoio) e, quando si fermano, scrive in ogni dado la
## faccia rimasta in alto (d["faccia"]).
func lancia(dadi: Array) -> void:
	for x in _corpi:
		x["corpo"].queue_free()
	_corpi = []
	var n := dadi.size()
	for i in n:
		var d: Dictionary = dadi[i]
		var c := _nuovo_dado(d)
		_corpi.append(c)
		_mondo.add_child(c["corpo"])
		_getta(c["corpo"], i, n)
	await _attendi()

## Rilancia solo questi dadi (gli altri restano dove sono).
func rilancia(dadi: Array) -> void:
	var k := 0
	var mossi := []
	for c in _corpi:
		if c["d"] in dadi:
			_getta(c["corpo"], k, dadi.size())
			mossi.append(c)
			k += 1
		else:
			c["corpo"].freeze = true   # gli altri restano fermi: il loro risultato non cambia
	if k > 0:
		await _attendi(mossi)
	for c in _corpi:
		c["corpo"].freeze = false

## Toglie dal vassoio un dado uscito dalla Riserva del Tiro.
func togli(d: Dictionary) -> void:
	for c in _corpi.duplicate():
		if c["d"] == d:
			c["corpo"].queue_free()
			_corpi.erase(c)

## Allinea il dado alla faccia scritta in d["faccia"] (dopo una correzione a mano o un effetto).
func allinea(d: Dictionary) -> void:
	for c in _corpi:
		if c["d"] == d:
			var b: RigidBody3D = c["corpo"]
			var nrm: Vector3 = c["normali"][int(d.get("faccia", 0))]
			b.basis = Basis(Quaternion(nrm.normalized(), Vector3.UP))
			b.position.y = 0.8
			b.linear_velocity = Vector3.ZERO
			b.angular_velocity = Vector3.ZERO
			b.sleeping = false

func _getta(b: RigidBody3D, i: int, n: int) -> void:
	var riga := i % 2
	var colonna := float(i / 2)
	var colonne := ceilf(n / 2.0)
	b.position = Vector3(-VASSOIO.x / 2 + 0.9 + randf() * 0.4, 2.2 + randf() * 1.4 + colonna * 0.25, (riga - 0.5) * 2.0 + randf_range(-0.5, 0.5))
	b.basis = Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
	b.linear_velocity = Vector3(randf_range(5.0, 8.5) + colonne * 0.1, randf_range(-1, 1.0), randf_range(-1.6, 1.6))
	b.angular_velocity = Vector3(randf_range(-22, 22), randf_range(-14, 14), randf_range(-22, 22))
	b.sleeping = false

## Aspetta che tutti i dadi siano fermi (al massimo 5 secondi), poi legge le facce.
func _attendi(quali: Array = []) -> void:
	if quali.is_empty():
		quali = _corpi
	var t := 0.0
	var quieti := 0.0
	while t < 4.5:
		await get_tree().physics_frame
		var dt := 1.0 / float(Engine.physics_ticks_per_second)
		t += dt
		if t > 0.6 and quali.all(func(c): return c["corpo"].sleeping or (c["corpo"].linear_velocity.length() < 0.12 and c["corpo"].angular_velocity.length() < 0.25)):
			quieti += dt
			if quieti > 0.25:
				break
		else:
			quieti = 0.0
	for c in quali:
		var b: RigidBody3D = c["corpo"]
		var meglio := 0
		var alto := -2.0
		for k in (c["normali"] as Array).size():
			var y: float = (b.global_basis * (c["normali"][k] as Vector3)).normalized().y
			if y > alto:
				alto = y
				meglio = k
		c["d"]["faccia"] = meglio
	fermi.emit()

func _nuovo_dado(d: Dictionary) -> Dictionary:
	var b := RigidBody3D.new()
	b.physics_material_override = _fisica
	b.mass = 0.5
	b.can_sleep = true
	b.linear_damp = 0.35
	b.angular_damp = 0.9
	b.continuous_cd = true
	var cs := CollisionShape3D.new()
	var mi := MeshInstance3D.new()
	var normali := []
	if str(d.get("tipo", "")) == "pericolo":
		var r := _ottaedro()
		mi.mesh = r[0]
		normali = r[1]
		var conv := ConvexPolygonShape3D.new()
		conv.points = PackedVector3Array([Vector3(RAGGIO_D8, 0, 0), Vector3(-RAGGIO_D8, 0, 0), Vector3(0, RAGGIO_D8, 0), Vector3(0, -RAGGIO_D8, 0), Vector3(0, 0, RAGGIO_D8), Vector3(0, 0, -RAGGIO_D8)])
		cs.shape = conv
		var facce: Array = Prova.defs()["pericolo"]["facce"]
		for k in 8:
			var mt := StandardMaterial3D.new()
			mt.albedo_color = Color.WHITE
			mt.albedo_texture = _faccia_d8(facce[k][0] if not (facce[k] as Array).is_empty() else "")
			mt.roughness = 0.45
			mi.mesh.surface_set_material(k, mt)
	else:
		mi.mesh = _cubo()
		normali = [Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]
		var bx := BoxShape3D.new()
		bx.size = Vector3.ONE * LATO
		cs.shape = bx
		var mt2 := StandardMaterial3D.new()
		var D := Prova.defs()
		var img := str(D["ferita"].get("img", "")) if str(d.get("tipo", "")) == "ferita" else str(D["reparto"].get(str(d.get("tipo", "")), {}).get("img", ""))
		mt2.albedo_color = COLORI.get(Prova.colore(d), Color("e8c21a"))
		mt2.roughness = 0.4
		mi.material_override = mt2
		if img != "":
			Immagini.carica(img, func(tex):
				if is_instance_valid(mi):
					mt2.albedo_color = Color.WHITE
					mt2.albedo_texture = tex)
	b.add_child(cs)
	b.add_child(mi)
	return {"corpo": b, "d": d, "normali": normali}

## Cubo con le facce prese dalla griglia 3×2 dell'immagine del dado (faccia i = cella i).
static func _cubo() -> ArrayMesh:
	var h := LATO * 0.5
	var facce := [
		[Vector3.UP, Vector3(-h, h, -h), Vector3(h, h, -h), Vector3(h, h, h), Vector3(-h, h, h)],
		[Vector3.DOWN, Vector3(-h, -h, h), Vector3(h, -h, h), Vector3(h, -h, -h), Vector3(-h, -h, -h)],
		[Vector3.BACK, Vector3(-h, h, h), Vector3(h, h, h), Vector3(h, -h, h), Vector3(-h, -h, h)],
		[Vector3.FORWARD, Vector3(h, h, -h), Vector3(-h, h, -h), Vector3(-h, -h, -h), Vector3(h, -h, -h)],
		[Vector3.RIGHT, Vector3(h, h, h), Vector3(h, h, -h), Vector3(h, -h, -h), Vector3(h, -h, h)],
		[Vector3.LEFT, Vector3(-h, h, -h), Vector3(-h, h, h), Vector3(-h, -h, h), Vector3(-h, -h, -h)],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var f: Array = facce[i]
		var cx := float(i % 3) / 3.0
		var cy := (1.0 + float(i / 3)) / 3.0
		var m := 0.004
		var uv := [Vector2(cx + m, cy + m), Vector2(cx + 1.0 / 3.0 - m, cy + m), Vector2(cx + 1.0 / 3.0 - m, cy + 1.0 / 3.0 - m), Vector2(cx + m, cy + 1.0 / 3.0 - m)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(f[0])
			st.set_uv(uv[k])
			st.add_vertex(f[k + 1])
	return st.commit()

## Ottaedro con una superficie per faccia (per il materiale con l'icona); restituisce [mesh, normali].
static func _ottaedro() -> Array:
	var r := RAGGIO_D8
	var mesh := ArrayMesh.new()
	var normali := []
	for sx in [1, -1]:
		for sy in [1, -1]:
			for sz in [1, -1]:
				var a := Vector3(r * sx, 0, 0)
				var b := Vector3(0, r * sy, 0)
				var c := Vector3(0, 0, r * sz)
				var n := Vector3(sx, sy, sz).normalized()
				# la punta "in alto" della faccia è il vertice sull'asse y: lì va la cima dell'icona
				var verts := [b, a, c]
				if (a - b).cross(c - b).dot(n) > 0:
					verts = [b, c, a]
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				var uvs := [Vector2(0.5, 0.06), Vector2(0.96, 0.9), Vector2(0.04, 0.9)]
				for k in 3:
					st.set_normal(n)
					st.set_uv(uvs[k])
					st.add_vertex(verts[k])
				st.commit(mesh)
				normali.append(n)
	return [mesh, normali]

## Faccia del dado Pericolo: arancio con l'icona di rarità al centro del triangolo.
static func _faccia_d8(icona: String) -> Texture2D:
	if _tex_d8.has(icona):
		return _tex_d8[icona]
	var im := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	im.fill(Color("f0901a"))
	var p := Dati.icona(icona) if icona != "" else ""
	if p != "":
		var t: Texture2D = load(p)
		if t:
			var ic := t.get_image()
			ic.convert(Image.FORMAT_RGBA8)
			ic.resize(104, 104, Image.INTERPOLATE_LANCZOS)
			im.blend_rect(ic, Rect2i(0, 0, 104, 104), Vector2i(76, 118))
	var tx := ImageTexture.create_from_image(im)
	_tex_d8[icona] = tx
	return tx
